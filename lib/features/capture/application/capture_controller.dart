import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/capture/domain/capture_models.dart';
import 'package:el_ahorrador/features/capture/domain/capture_service.dart';

/// One image of a share.
final class CaptureItem {
  CaptureItem(this.path) : fileName = p.basename(path);

  final String path;
  final String fileName;
  CaptureOutcome? outcome;

  bool get done => outcome != null;
}

/// Images shared together ("Compartir 7 imágenes"), read one after another.
final class CaptureJob {
  CaptureJob(List<String> paths)
    : items = [for (final x in paths) CaptureItem(x)];

  final List<CaptureItem> items;

  bool get single => items.length == 1;
  int get processed => items.where((i) => i.done).length;
  bool get finished => processed == items.length;

  int count(CaptureStatus status) =>
      items.where((i) => i.outcome?.status == status).length;

  /// "4 registrados · 1 duplicado · 2 con error"
  String get summary {
    String part(int n, String one, String many) => '$n ${n == 1 ? one : many}';
    final registered = count(CaptureStatus.registered);
    final review = count(CaptureStatus.review);
    final duplicate = count(CaptureStatus.duplicate);
    final errors =
        count(CaptureStatus.notReceipt) + count(CaptureStatus.failed);
    return [
      part(registered, 'registrado', 'registrados'),
      if (review > 0) part(review, 'por revisar', 'por revisar'),
      if (duplicate > 0) part(duplicate, 'duplicado', 'duplicados'),
      if (errors > 0) part(errors, 'con error', 'con error'),
    ].join(' · ');
  }

  List<String> get registeredIds => [
    for (final i in items)
      if (i.outcome?.movementId case final id?) id,
  ];
}

/// Runs shared images through [CaptureService] one at a time and tells the
/// interface what to show. Shares arriving while a job runs join it.
class CaptureController extends ChangeNotifier {
  CaptureController(this._service);

  final CaptureService _service;

  CaptureService get service => _service;

  CaptureJob? _job;
  bool _visible = false;
  bool _running = false;

  /// Current or last job; null when there is nothing to show.
  CaptureJob? get job => _job;

  /// Whether the capture sheet should be on screen.
  bool get visible => _visible && _job != null;

  /// Registered movements, for the "Registrado · Deshacer" pill.
  final _registered = <String>[];
  List<String> takeRegistered() {
    final ids = [..._registered];
    _registered.clear();
    return ids;
  }

  Future<void> start(
    List<String> paths, {
    MovementOrigin origin = MovementOrigin.shared,
  }) async {
    if (paths.isEmpty) return;
    final job = _job;
    if (job != null && !job.finished) {
      job.items.addAll([for (final x in paths) CaptureItem(x)]);
    } else {
      _job = CaptureJob(paths);
    }
    _visible = true;
    notifyListeners();
    await _run(origin);
  }

  Future<void> retry(CaptureItem item) async {
    item.outcome = null;
    notifyListeners();
    await _run(MovementOrigin.shared);
  }

  /// "Seguir en segundo plano" or closing the sheet: the job keeps going.
  void hide() {
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }

  /// "Listo" once finished.
  void close() {
    _visible = false;
    if (_job?.finished ?? true) _job = null;
    notifyListeners();
  }

  Future<void> _run(MovementOrigin origin) async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        final next = _job?.items.where((i) => !i.done).firstOrNull;
        if (next == null) break;
        next.outcome = await _service.process(next.path, origin: origin);
        if (next.outcome!.movementId case final id?) _registered.add(id);
        notifyListeners();
      }
    } finally {
      _running = false;
    }
  }
}
