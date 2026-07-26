import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:el_ahorrador/core/file_store.dart';
import 'package:el_ahorrador/features/capture/application/attachment_batch_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'hashes and batch-processes large synthetic captures within a sane time budget',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'capture_load_test_',
      );
      addTearDown(() => directory.delete(recursive: true));

      // 20MB x 3 stays well inside the phone-photo range that motivated the
      // "pruebas de carga con imágenes grandes" gap while keeping CI fast.
      const fileSizeBytes = 20 * 1024 * 1024;
      const fileCount = 3;
      final paths = <String>[];
      for (var i = 0; i < fileCount; i++) {
        final path = '${directory.path}${Platform.pathSeparator}large_$i.jpg';
        await _writeSyntheticImage(path, fileSizeBytes, seed: i);
        paths.add(path);
      }

      final stopwatch = Stopwatch()..start();
      const processor = AttachmentBatchProcessor<String>();
      final digests = <String, String>{};
      final summary = await processor.process(
        attachments: paths,
        isEligible: (_) => true,
        processAttachment: (path) async {
          digests[path] = await FileStore.sha256OfFile(path);
        },
      );
      stopwatch.stop();

      expect(summary.successCount, fileCount);
      expect(summary.failureCount, 0);
      expect(digests.length, fileCount);
      // Distinct seeded content must yield distinct digests, not just "no
      // exception" — a truncated stream read could otherwise pass silently.
      expect(digests.values.toSet().length, fileCount);
      // Streaming ~60MB through File.openRead() should comfortably clear
      // this; a regression to whole-file buffering or O(n^2) I/O would not.
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 15)));
    },
  );
}

Future<void> _writeSyntheticImage(
  String path,
  int sizeBytes, {
  required int seed,
}) async {
  final random = Random(seed);
  final block = Uint8List(1024 * 1024);
  for (var i = 0; i < block.length; i++) {
    block[i] = random.nextInt(256);
  }

  final sink = File(path).openWrite();
  try {
    var written = 0;
    while (written < sizeBytes) {
      final remaining = sizeBytes - written;
      if (remaining >= block.length) {
        sink.add(block);
        written += block.length;
      } else {
        sink.add(block.sublist(0, remaining));
        written += remaining;
      }
    }
    await sink.flush();
  } finally {
    await sink.close();
  }
}
