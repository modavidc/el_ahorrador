import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/capture/domain/capture_models.dart';
import 'package:el_ahorrador/features/capture/domain/capture_ports.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';

/// [CaptureRecords] on the `captures` table. What was read lives in
/// `meta_json`: `{origin, operation, draft}`.
class DriftCaptureRecords implements CaptureRecords {
  DriftCaptureRecords(this._db);

  final AppDatabase _db;

  static const _status = {
    CaptureRecordStatus.processing: 'PROCESSING',
    CaptureRecordStatus.processed: 'PROCESSED',
    CaptureRecordStatus.review: 'REVIEW',
    CaptureRecordStatus.discarded: 'DISCARDED',
    CaptureRecordStatus.failed: 'FAILED',
  };

  @override
  Future<CaptureRecord?> findActive({
    String? hash,
    String? operation,
    String? except,
  }) async {
    final review = _status[CaptureRecordStatus.review]!;
    final query = _db.select(_db.captures)
      ..where(
        (c) => c.status.isIn([_status[CaptureRecordStatus.processed]!, review]),
      );
    if (hash != null) query.where((c) => c.hash.equals(hash));
    if (operation != null) {
      query.where((c) => c.metaJson.like('%"operation":"$operation"%'));
    }
    if (except != null) query.where((c) => c.id.equals(except).not());
    for (final row in await query.get()) {
      final movementId = await _movementOf(row.id);
      // A registered capture whose movement was deleted no longer counts.
      if (row.status == review || movementId != null) {
        return CaptureRecord(
          id: row.id,
          draft: _draftOf(row),
          movementId: movementId,
        );
      }
    }
    return null;
  }

  @override
  Future<String> create({
    required String imagePath,
    required String hash,
  }) async {
    final id = const Uuid().v4();
    await _db
        .into(_db.captures)
        .insert(
          CapturesCompanion.insert(
            id: id,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            imagePath: imagePath,
            hash: Value(hash),
            status: _status[CaptureRecordStatus.processing]!,
          ),
        );
    return id;
  }

  @override
  Future<void> saveReading(
    String id, {
    required String text,
    required MovementOrigin origin,
    int? confidence,
    String? operation,
    String? sourceApp,
    CaptureDraft? draft,
  }) => (_db.update(_db.captures)..where((c) => c.id.equals(id))).write(
    CapturesCompanion(
      ocrText: Value(text),
      ocrConfidence: Value(confidence?.toString()),
      sourceApp: Value(sourceApp),
      metaJson: Value(
        jsonEncode({
          'origin': origin.key,
          'operation': operation,
          if (draft != null) 'draft': _draftToJson(draft),
        }),
      ),
    ),
  );

  @override
  Future<void> setStatus(String id, CaptureRecordStatus status) =>
      (_db.update(_db.captures)..where((c) => c.id.equals(id))).write(
        CapturesCompanion(status: Value(_status[status]!)),
      );

  @override
  Future<String?> sourceApp(String id) async => (await (_db.select(
    _db.captures,
  )..where((c) => c.id.equals(id))).getSingleOrNull())?.sourceApp;

  @override
  Stream<List<InboxItem>> watchInbox() =>
      (_db.select(_db.captures)
            ..where(
              (c) => c.status.equals(_status[CaptureRecordStatus.review]!),
            )
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
    return d is Map<String, dynamic> ? _draftFromJson(d) : null;
  }

  static Map<String, Object?> _draftToJson(CaptureDraft d) => {
    'note': d.note,
    'type': d.type.name,
    'account': d.account,
    'at': d.at.millisecondsSinceEpoch,
    'amountCents': d.amountCents,
    'category': d.category,
    'ocrPercent': d.ocrPercent,
    'rule': d.ruleLabel,
    'why': d.why,
  };

  static CaptureDraft _draftFromJson(Map<String, dynamic> j) => CaptureDraft(
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
