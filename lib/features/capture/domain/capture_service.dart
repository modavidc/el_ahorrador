import 'package:el_ahorrador/features/capture/domain/capture_models.dart';
import 'package:el_ahorrador/features/capture/domain/capture_ports.dart';
import 'package:el_ahorrador/features/capture/domain/capture_rule.dart';
import 'package:el_ahorrador/features/capture/domain/receipt_reader.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/ledger/domain/ledger_repository.dart';

/// Turns a shared image into a movement: OCR, receipt reading, capture
/// rules, duplicate check, and Por revisar when a datum is missing.
class CaptureService {
  CaptureService({
    required OcrEngine ocr,
    required CaptureImageStore images,
    required CaptureRecords records,
    required CaptureRuleRepository rules,
    required LedgerRepository ledger,
    DateTime Function()? now,
  }) : _ocr = ocr,
       _images = images,
       _records = records,
       _rules = rules,
       _ledger = ledger,
       _now = now ?? DateTime.now;

  final OcrEngine _ocr;
  final CaptureImageStore _images;
  final CaptureRecords _records;
  final CaptureRuleRepository _rules;
  final LedgerRepository _ledger;
  final DateTime Function() _now;

  Future<CaptureOutcome> process(
    String path, {
    MovementOrigin origin = MovementOrigin.shared,
  }) async {
    final fileName = path.split(RegExp(r'[/\\]')).last;
    String? captureId;
    try {
      final hash = await _images.hash(path);
      final sameImage = await _records.findActive(hash: hash);
      if (sameImage != null) {
        return CaptureOutcome(
          status: CaptureStatus.duplicate,
          fileName: fileName,
          originalMovementId: sameImage.movementId,
          draft: sameImage.draft,
        );
      }

      final ocrFuture = _ocr.run(path);
      final stored = await _images.persist(path);
      captureId = await _records.create(imagePath: stored, hash: hash);
      final ocr = await ocrFuture;
      final reading = ReceiptReader.read(ocr.text, now: _now());

      if (!reading.isReceipt) {
        await _records.saveReading(
          captureId,
          text: ocr.text,
          origin: origin,
          confidence: ocr.confidence,
        );
        await _records.setStatus(captureId, CaptureRecordStatus.failed);
        return CaptureOutcome(
          status: CaptureStatus.notReceipt,
          fileName: fileName,
          captureId: captureId,
        );
      }

      if (reading.operation != null) {
        final sameOperation = await _records.findActive(
          operation: reading.operation,
          except: captureId,
        );
        if (sameOperation != null) {
          await _records.setStatus(captureId, CaptureRecordStatus.failed);
          return CaptureOutcome(
            status: CaptureStatus.duplicate,
            fileName: fileName,
            captureId: captureId,
            originalMovementId: sameOperation.movementId,
            draft: sameOperation.draft,
          );
        }
      }

      final draft = await _draft(reading, ocr.confidence);
      await _records.saveReading(
        captureId,
        text: ocr.text,
        origin: origin,
        confidence: ocr.confidence,
        operation: reading.operation,
        sourceApp: reading.source.label,
        draft: draft,
      );

      if (draft.why != null) {
        await _records.setStatus(captureId, CaptureRecordStatus.review);
        return CaptureOutcome(
          status: CaptureStatus.review,
          fileName: fileName,
          captureId: captureId,
          draft: draft,
        );
      }
      final movementId = await _register(captureId, draft, reading.source);
      return CaptureOutcome(
        status: CaptureStatus.registered,
        fileName: fileName,
        captureId: captureId,
        movementId: movementId,
        draft: draft,
      );
    } on Object {
      if (captureId != null) {
        await _records.setStatus(captureId, CaptureRecordStatus.failed);
      }
      return CaptureOutcome(status: CaptureStatus.failed, fileName: fileName);
    }
  }

  /// Payments waiting in Por revisar, newest first.
  Stream<List<InboxItem>> watchInbox() => _records.watchInbox();

  /// Registers an inbox payment once its missing datum is filled.
  Future<String> approve(
    InboxItem item, {
    String? category,
    int? amountCents,
  }) async {
    final d = item.draft;
    final draft = CaptureDraft(
      note: d.note,
      type: d.type,
      account: d.account,
      at: d.at,
      amountCents: amountCents ?? d.amountCents,
      category: category ?? d.category,
      ocrPercent: d.ocrPercent,
      ruleLabel: d.ruleLabel,
    );
    if ((draft.amountCents ?? 0) <= 0 || draft.category == null) {
      throw ArgumentError('Falta un dato');
    }
    final sourceApp = await _records.sourceApp(item.captureId);
    return _register(
      item.captureId,
      draft,
      ReceiptSource.values.firstWhere(
        (s) => s.label == sourceApp,
        orElse: () => ReceiptSource.other,
      ),
    );
  }

  Future<void> discard(InboxItem item) =>
      _records.setStatus(item.captureId, CaptureRecordStatus.discarded);

  /// Puts a discarded payment back in Por revisar ("Deshacer").
  Future<void> restore(InboxItem item) =>
      _records.setStatus(item.captureId, CaptureRecordStatus.review);

  // ---- internals

  Future<CaptureDraft> _draft(ReceiptReading r, int? percent) async {
    final rules = await _rules.load();
    final matched = [
      for (final rule in rules)
        if (rule.matches(r)) rule,
    ];
    final sourceRule = matched.where((x) => !x.isMerchant).firstOrNull;
    final merchantRule = matched.where((x) => x.isMerchant).firstOrNull;

    final type =
        sourceRule?.type ??
        (r.direction == ReceiptDirection.received
            ? MovementType.income
            : MovementType.expense);
    final wantedAccount =
        merchantRule?.account ?? sourceRule?.account ?? r.source.label;
    final ruleCategory = merchantRule?.category ?? sourceRule?.category;
    final category =
        ruleCategory == null || ruleCategory == CaptureRule.automatic
        ? guessCategory(r)
        : ruleCategory;
    final label = [merchantRule, sourceRule].nonNulls.firstOrNull;

    return CaptureDraft(
      note: r.note,
      type: type,
      account: await _resolveAccount(wantedAccount, r.source),
      at: r.at,
      amountCents: r.amountCents,
      category: category,
      ocrPercent: percent,
      ruleLabel: label == null
          ? null
          : 'Regla ${label.matchLabel} → '
                '${type == MovementType.income ? 'Ingreso' : 'Gasto'} · '
                '${label.account}',
      why: r.amountCents == null
          ? 'No se leyó el monto'
          : category == null
          ? 'Falta la categoría'
          : null,
    );
  }

  /// The user's account for a rule's account name: exact name, a name that
  /// contains it ("BCP" → "BCP Soles"), the source app, or the default.
  Future<String> _resolveAccount(String wanted, ReceiptSource source) async {
    final accounts = await _ledger.watchAccounts().first;
    String? find(String key) {
      final k = key.toLowerCase();
      final names = [for (final a in accounts) a.name];
      return names.where((n) => n.toLowerCase() == k).firstOrNull ??
          names.where((n) => n.toLowerCase().contains(k)).firstOrNull;
    }

    return find(wanted) ??
        find(source.label) ??
        accounts.where((a) => a.isDefault).firstOrNull?.name ??
        wanted;
  }

  Future<String> _register(
    String captureId,
    CaptureDraft draft,
    ReceiptSource source,
  ) async {
    final id = await _ledger.addEntry(
      type: draft.type,
      amountCents: draft.amountCents!,
      account: draft.account,
      category: draft.category,
      note: draft.note,
      at: draft.at,
      sourceApp: source.label,
      captureId: captureId,
    );
    await _records.setStatus(captureId, CaptureRecordStatus.processed);
    return id;
  }
}
