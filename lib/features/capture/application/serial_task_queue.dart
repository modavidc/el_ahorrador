/// Runs enqueued async tasks strictly in FIFO order, one at a time, without
/// ever letting a rejected task break the chain for tasks queued after it.
///
/// A naive `Future.then` chain (`tail = tail.then((_) => task())`) looks
/// serialized but is not resilient: once `tail` settles as an error, every
/// `.then` registered on it afterwards is skipped instead of run, so a
/// single failing task silently drops every task enqueued later. This class
/// keeps its internal chain always resolving so later tasks are unaffected.
class SerialTaskQueue {
  Future<void> _tail = Future<void>.value();

  /// Schedules [task] to run after every previously enqueued task has
  /// settled, and returns a future that completes or fails with [task]'s
  /// own outcome. The failure is never propagated to the internal chain, so
  /// it cannot block or drop tasks enqueued after this one.
  Future<void> add(Future<void> Function() task) {
    final scheduled = _tail.then((_) => task());
    _tail = scheduled.then((_) {}, onError: (_) {});
    return scheduled;
  }
}
