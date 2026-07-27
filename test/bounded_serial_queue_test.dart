import 'dart:async';

import 'package:el_ahorrador/features/capture/application/bounded_serial_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('drains concurrent work in FIFO order with one active task', () async {
    final queue = BoundedSerialQueue<int, int>(maxPending: 3);
    final gate = Completer<void>();
    final started = <int>[];
    var active = 0;
    var peakActive = 0;

    Future<int> process(int value) async {
      started.add(value);
      active++;
      peakActive = active > peakActive ? active : peakActive;
      if (value == 1) await gate.future;
      active--;
      return value * 10;
    }

    final futures = [
      queue.enqueue(1, process),
      queue.enqueue(2, process),
      queue.enqueue(3, process),
    ];
    await Future<void>.delayed(Duration.zero);
    expect(started, [1]);
    expect(queue.pendingCount, 2);
    gate.complete();

    expect(await Future.wait(futures), [10, 20, 30]);
    expect(started, [1, 2, 3]);
    expect(peakActive, 1);
    expect(queue.isProcessing, isFalse);
  });

  test('reports backpressure and continues after task failures', () async {
    final queue = BoundedSerialQueue<int, void>(maxPending: 1);
    final gate = Completer<void>();
    final attempted = <int>[];
    final first = queue.enqueue(1, (value) async {
      attempted.add(value);
      await gate.future;
    });
    final second = queue.enqueue(2, (value) async {
      attempted.add(value);
      throw StateError('isolated failure');
    });
    final rejected = queue.enqueue(3, (_) async {});

    await expectLater(rejected, throwsA(isA<QueueFullException>()));
    gate.complete();
    await first;
    await expectLater(second, throwsStateError);
    await queue.enqueue(4, (value) async => attempted.add(value));
    expect(attempted, [1, 2, 4]);
  });
}
