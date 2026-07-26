import 'package:flutter_test/flutter_test.dart';
import 'package:el_ahorrador/features/capture/application/serial_task_queue.dart';

void main() {
  test('runs tasks strictly in FIFO order under rapid concurrent enqueue', () async {
    final queue = SerialTaskQueue();
    final attempted = <int>[];
    final scheduled = <Future<void>>[];

    // Enqueue without awaiting in between, and give earlier tasks longer
    // delays than later ones: only true serialization keeps this in order.
    for (var id = 1; id <= 5; id++) {
      scheduled.add(
        queue.add(() async {
          await Future<void>.delayed(Duration(milliseconds: (6 - id) * 4));
          attempted.add(id);
        }),
      );
    }

    await Future.wait(scheduled);
    expect(attempted, [1, 2, 3, 4, 5]);
  });

  test('a task that throws does not block or drop later tasks', () async {
    final queue = SerialTaskQueue();
    final attempted = <int>[];

    final first = queue.add(() async => attempted.add(1));
    final second = queue.add(() async {
      attempted.add(2);
      throw StateError('boom');
    });
    final third = queue.add(() async => attempted.add(3));

    await first;
    await expectLater(second, throwsA(isA<StateError>()));
    await third;

    expect(attempted, [1, 2, 3]);
  });

  test('reports each task outcome to its own caller only', () async {
    final queue = SerialTaskQueue();
    final results = <String>[];

    final ok = queue.add(() async => results.add('ok'));
    final fails = queue.add(() async => throw Exception('nope'));
    final after = queue.add(() async => results.add('after'));

    await ok;
    await after;
    expect(results, ['ok', 'after']);
    await expectLater(fails, throwsException);
  });
}
