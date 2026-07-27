import 'dart:async';
import 'dart:collection';

/// Bounded FIFO queue that runs exactly one asynchronous task at a time.
class BoundedSerialQueue<T, R> {
  BoundedSerialQueue({this.maxPending = 10})
    : assert(maxPending >= 0, 'maxPending must not be negative');

  final int maxPending;
  final Queue<_QueuedTask<T, R>> _pending = Queue<_QueuedTask<T, R>>();
  bool _isDraining = false;

  bool get isProcessing => _isDraining;
  int get pendingCount => _pending.length;

  Future<R> enqueue(T item, Future<R> Function(T item) process) {
    if (_isDraining && _pending.length >= maxPending) {
      return Future<R>.error(
        QueueFullException(maxPending: maxPending),
        StackTrace.current,
      );
    }
    final task = _QueuedTask<T, R>(item, process);
    _pending.addLast(task);
    if (!_isDraining) {
      _isDraining = true;
      unawaited(_drain());
    }
    return task.completer.future;
  }

  Future<void> _drain() async {
    while (_pending.isNotEmpty) {
      final task = _pending.removeFirst();
      try {
        task.completer.complete(await task.process(task.item));
      } catch (error, stackTrace) {
        task.completer.completeError(error, stackTrace);
      }
    }
    _isDraining = false;
    if (_pending.isNotEmpty) {
      _isDraining = true;
      unawaited(_drain());
    }
  }
}

class QueueFullException implements Exception {
  const QueueFullException({required this.maxPending});
  final int maxPending;

  @override
  String toString() =>
      'QueueFullException: pending queue capacity is $maxPending';
}

class _QueuedTask<T, R> {
  _QueuedTask(this.item, this.process);
  final T item;
  final Future<R> Function(T item) process;
  final Completer<R> completer = Completer<R>();
}
