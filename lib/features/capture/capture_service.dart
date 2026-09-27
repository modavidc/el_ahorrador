import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/file_store.dart';
import '../../core/ocr_engine.dart';
import '../../data/app_database.dart';
import '../../data/daos.dart';
import '../ledger/ledger.dart';
import 'capture_rules.dart';
import 'receipt_reader.dart';

enum CaptureStatus {
  /// Saved as a movement.
  registered,

  /// Same image or same operation already captured; nothing saved.
  duplicate,

  /// Not a payment receipt.
  notReceipt,

  /// Waiting in Por revisar for a missing amount or category.
  review,

  /// OCR or storage failed.
  failed,
}

/// What a capture understood, before or after it becomes a movement.
final class CaptureDraft {
  const CaptureDraft({
    required this.note,
    required this.type,
    required this.account,
    required this.at,
    this.amountCents,
    this.category,
    this.ocrPercent,
    this.ruleLabel,
    this.why,
  });

  final String note;
  final MovementType type;
  final String account;
  final DateTime at;
  final int? amountCents;
  final String? category;
  final int? ocrPercent;

  /// 'Regla “Yapeaste” → Gasto · Yape'
  final String? ruleLabel;

  /// Why it is waiting in Por revisar ("Falta la categoría").
  final String? why;

  Map<String, Object?> toJson() => {
    'note': note,
    'type': type.name,
    'account': account,
    'at': at.millisecondsSinceEpoch,
    'amountCents': amountCents,
    'category': category,
    'ocrPercent': ocrPercent,
    'rule': ruleLabel,
    'why': why,
  };

  static CaptureDraft fromJson(Map<String, dynamic> j) => CaptureDraft(
    note: j['note'] as String,
    type: MovementType.values.byName(j['type'] as String),
    account: j['account'] as String,
    at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
    amountCents: j['amountCents'] as int?,
    category: j['category'] as String?,
    ocrPercent: j['ocrPercent'] as int?,
    ruleLabel: j['rule'] as String?,
    why: j['why'] as String?,
  );
}

final class CaptureOutcome {
  const CaptureOutcome({
    required this.status,
    required this.fileName,
    this.captureId,
    this.movementId,
    this.originalMovementId,
    this.draft,
  });

  final CaptureStatus status;

  /// Shown when nothing else identifies the image ("IMG_2291.jpg").
  final String fileName;
  final String? captureId;
  final String? movementId;

  /// For duplicates: the movement that was already registered.
  final String? originalMovementId;
  final CaptureDraft? draft;
}

/// A payment waiting in Por revisar.
final class InboxItem {
  const InboxItem({
    required this.captureId,
    required this.draft,
    required this.origin,
    required this.receivedAt,
  });

  final String captureId;
  final CaptureDraft draft;
  final MovementOrigin origin;
  final DateTime receivedAt;
}

/// Where capture images are kept: encrypted copy and content hash.
abstract interface class CaptureStorage {
  Future<String> persist(String path);
  Future<String> hash(String path);
}

class EncryptedCaptureStorage implements CaptureStorage {
  const EncryptedCaptureStorage();

  @override
  Future<String> persist(String path) => FileStore.persistIncomingFile(path);

  @override
  Future<String> hash(String path) => FileStore.sha256OfFile(path);
}

/// Turns a shared image into a movement: OCR, receipt reading, capture
/// rules, duplicate check, and Por revisar when a datum is missing.
class CaptureService {
  CaptureService({
    required AppDatabase db,
    required OcrEngine ocr,
    CaptureStorage storage = const EncryptedCaptureStorage(),
    DateTime Function()? now,
  }) : _db = db,
       _ocr = ocr,
       _storage = storage,
       _now = now ?? DateTime.now,
       _ledger = LedgerRepository(db),
       _rules = CaptureRuleStore(db);

  final AppDatabase _db;
  final OcrEngine _ocr;
  final CaptureStorage _storage;
  final DateTime Function() _now;
  final LedgerRepository _ledger;
  final CaptureRuleStore _rules;

  static const _review = 'REVIEW';
  static const _discarded = 'DISCARDED';

  Future<CaptureOutcome> process(
    String path, {
    MovementOrigin origin = MovementOrigin.shared,
  }) async {
    final fileName = p.basename(path);
    String? captureId;
    try {
      final hash = await _storage.hash(path);
      final sameImage = await _captureWith(hash: hash);
      if (sameImage != null) {
        return CaptureOutcome(
          status: CaptureStatus.duplicate,
          fileName: fileName,
          originalMovementId: await _movementOf(sameImage.id),
          draft: _draftOf(sameImage),
        );
      }

      final ocrFuture = _ocr.run(path);
      final stored = await _storage.persist(path);
      captureId = const Uuid().v4();
      await _db.insertCapture(
        id: captureId,
        imagePath: stored,
        hash: hash,
        sourceApp: null,
      );
      await _db.setProcessing(captureId);
      final ocr = await ocrFuture;
      final percent = switch (ocr.meta['confidence']) {
        final num n => n.round(),
        _ => null,
      };
      final reading = ReceiptReader.read(ocr.text, now: _now());
      final meta = <String, Object?>{
        'origin': origin.key,
        'operation': reading.operation,
      };

      if (!reading.isReceipt) {
        await _db.setOcrResult(
          id: captureId,
          text: ocr.text,
          confidence: percent?.toString(),
          metaJson: jsonEncode(meta),
        );
        await _db.setFailed(captureId);
        return CaptureOutcome(
          status: CaptureStatus.notReceipt,
          fileName: fileName,
          captureId: captureId,
        );
      }

      if (reading.operation != null) {
        final sameOperation = await _captureWith(
          operation: reading.operation,
          except: captureId,
        );
        if (sameOperation != null) {
          await _db.setFailed(captureId);
          return CaptureOutcome(
            status: CaptureStatus.duplicate,
            fileName: fileName,
            captureId: captureId,
            originalMovementId: await _movementOf(sameOperation.id),
            draft: _draftOf(sameOperation),
          );
        }
      }

      final draft = await _draft(reading, percent);
      meta['draft'] = draft.toJson();
      await _db.setOcrResult(
        id: captureId,
        text: ocr.text,
        confidence: percent?.toString(),
        metaJson: jsonEncode(meta),
      );
      await (_db.update(_db.captures)..where((c) => c.id.equals(captureId!)))
          .write(CapturesCompanion(sourceApp: Value(reading.source.label)));

      if (draft.why != null) {
        await _setStatus(captureId, _review);
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
      if (captureId != null) await _db.setFailed(captureId);
      return CaptureOutcome(status: CaptureStatus.failed, fileName: fileName);
    }
  }

  /// Payments waiting in Por revisar, newest first.
  Stream<List<InboxItem>> watchInbox() =>
      (_db.select(_db.captures)
            ..where((c) => c.status.equals(_review))
            ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
          .watch()
          .map(
            (rows) => [
              for (final row in rows)
                if (_draftOf(row) case final draft?)
                  InboxItem(
                    captureId: row.id,
                    draft: draft,
                    origin: MovementOrigin.fromKey(
                      _meta(row)['origin'] as String?,
                    ),
                    receivedAt: DateTime.fromMillisecondsSinceEpoch(
                      row.createdAt,
                    ),
                  ),
            ],
          );

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
    final row = await (_db.select(
      _db.captures,
    )..where((c) => c.id.equals(item.captureId))).getSingle();
    return _register(
      item.captureId,
      draft,
      ReceiptSource.values.firstWhere(
        (s) => s.label == row.sourceApp,
        orElse: () => ReceiptSource.other,
      ),
    );
  }

  Future<void> discard(InboxItem item) =>
      _setStatus(item.captureId, _discarded);

  /// Puts a discarded payment back in Por revisar ("Deshacer").
  Future<void> restore(InboxItem item) => _setStatus(item.captureId, _review);

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
    final names = [
      for (final a in await (_db.select(
        _db.accounts,
      )..where((a) => a.isArchived.equals(false))).get())
        a.name,
    ];
    String? find(String key) {
      final k = key.toLowerCase();
      return names.where((n) => n.toLowerCase() == k).firstOrNull ??
          names.where((n) => n.toLowerCase().contains(k)).firstOrNull;
    }

    return find(wanted) ??
        find(source.label) ??
        (await (_db.select(
          _db.accounts,
        )..where((a) => a.isDefault.equals(true))).getSingleOrNull())?.name ??
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
    await _setStatus(captureId, 'PROCESSED');
    return id;
  }

  Future<void> _setStatus(String captureId, String status) =>
      (_db.update(_db.captures)..where((c) => c.id.equals(captureId))).write(
        CapturesCompanion(status: Value(status)),
      );

  /// A capture that still counts: registered or waiting in Por revisar.
  Future<Capture?> _captureWith({
    String? hash,
    String? operation,
    String? except,
  }) async {
    final query = _db.select(_db.captures)
      ..where((c) => c.status.isIn(['PROCESSED', _review]));
    if (hash != null) query.where((c) => c.hash.equals(hash));
    if (operation != null) {
      query.where((c) => c.metaJson.like('%"operation":"$operation"%'));
    }
    if (except != null) query.where((c) => c.id.equals(except).not());
    final rows = await query.get();
    // A processed capture whose movement was deleted is not a duplicate.
    for (final row in rows) {
      if (row.status == _review || await _movementOf(row.id) != null) {
        return row;
      }
    }
    return null;
  }

  Future<String?> _movementOf(String captureId) async => (await (_db.select(
    _db.expenses,
  )..where((e) => e.captureId.equals(captureId))).get()).firstOrNull?.id;

  static Map<String, dynamic> _meta(Capture row) {
    try {
      final m = jsonDecode(row.metaJson ?? '{}');
      return m is Map<String, dynamic> ? m : const {};
    } on FormatException {
      return const {};
    }
  }

  static CaptureDraft? _draftOf(Capture row) {
    final d = _meta(row)['draft'];
    return d is Map<String, dynamic> ? CaptureDraft.fromJson(d) : null;
  }
}
