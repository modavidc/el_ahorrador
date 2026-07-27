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
}
