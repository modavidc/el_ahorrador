import 'dart:io';

import 'package:el_ahorrador/core/file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sha256OfFile returns the known digest using a file stream', () async {
    final directory = await Directory.systemTemp.createTemp('file_store_test_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}fixture.txt');
    await file.writeAsString('abc');

    expect(
      await FileStore.sha256OfFile(file.path),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test(
    'sha256OfFile handles a 16 MiB file written in bounded chunks',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'file_store_large_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}large.bin');
      final sink = file.openWrite();
      final chunk = List<int>.generate(64 * 1024, (index) => index & 0xff);
      for (var index = 0; index < 256; index++) {
        sink.add(chunk);
      }
      await sink.close();

      expect(await file.length(), 16 * 1024 * 1024);
      expect(
        await FileStore.sha256OfFile(file.path),
        '341aacac661ccb210720bedaa9ead5d668fe5ea41a73532fc147c71e34040df1',
      );
    },
  );
}
