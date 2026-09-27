import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:el_ahorrador/core/security/capture_key_store.dart';
import 'package:el_ahorrador/core/security/encrypted_file_store.dart';
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

  group('encrypted captures', () {
    late Directory root;
    late Directory documents;
    late Directory temporary;
    final keyStore = _FakeCaptureKeyStore(List<int>.generate(32, (i) => i));

    setUp(() async {
      root = await Directory.systemTemp.createTemp('encrypted_capture_test_');
      documents = Directory('${root.path}${Platform.pathSeparator}documents');
      temporary = Directory('${root.path}${Platform.pathSeparator}temporary');
      await documents.create();
      await temporary.create();
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test(
      'persists ciphertext and materializes only a temporary copy',
      () async {
        final source = File('${root.path}${Platform.pathSeparator}receipt.png');
        final cleartext = List<int>.generate(4096, (i) => i & 0xff);
        await source.writeAsBytes(cleartext);

        final stored = await FileStore.persistIncomingFile(
          source.path,
          documentsDirectory: documents,
          keyStore: keyStore,
        );

        expect(stored, endsWith('.capture'));
        expect(await File(stored).readAsBytes(), isNot(cleartext));
        expect(
          Directory('${documents.path}${Platform.pathSeparator}captures')
              .listSync()
              .whereType<File>()
              .any((file) => file.path.endsWith('.partial')),
          isFalse,
        );

        final materialized = await FileStore.materializeForRead(
          stored,
          temporaryDirectory: temporary,
          keyStore: keyStore,
        );
        expect(materialized, endsWith('.png'));
        expect(await File(materialized).readAsBytes(), cleartext);

        await FileStore.releaseMaterializedFile(materialized);
        expect(await File(materialized).exists(), isFalse);
        expect(await File(stored).exists(), isTrue);
      },
    );

    test('authenticated encryption rejects a modified capture', () async {
      final source = File('${root.path}${Platform.pathSeparator}receipt.jpg');
      await source.writeAsBytes(List<int>.generate(128, (i) => i));
      final stored = await FileStore.persistIncomingFile(
        source.path,
        documentsDirectory: documents,
        keyStore: keyStore,
      );
      final bytes = await File(stored).readAsBytes();
      bytes[bytes.length - 17] ^= 1;
      await File(stored).writeAsBytes(bytes);

      await expectLater(
        FileStore.materializeForRead(
          stored,
          temporaryDirectory: temporary,
          keyStore: keyStore,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      expect(temporary.listSync(recursive: true).whereType<File>(), isEmpty);
    });

    test('a different key cannot decrypt the capture', () async {
      final source = File('${root.path}${Platform.pathSeparator}receipt.webp');
      await source.writeAsBytes(<int>[1, 2, 3, 4]);
      final stored = await FileStore.persistIncomingFile(
        source.path,
        documentsDirectory: documents,
        keyStore: keyStore,
      );

      await expectLater(
        FileStore.materializeForRead(
          stored,
          temporaryDirectory: temporary,
          keyStore: _FakeCaptureKeyStore(List<int>.filled(32, 99)),
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('failed encryption removes the partial file', () async {
      final source = File('${root.path}${Platform.pathSeparator}receipt.png');
      await source.writeAsBytes(<int>[1, 2, 3]);

      await expectLater(
        FileStore.persistIncomingFile(
          source.path,
          documentsDirectory: documents,
          keyStore: _ThrowingCaptureKeyStore(),
        ),
        throwsStateError,
      );

      final captures = Directory(
        '${documents.path}${Platform.pathSeparator}captures',
      );
      expect(captures.listSync(), isEmpty);
    });

    test('release refuses to delete a path it did not materialize', () async {
      final unrelated = File(
        '${temporary.path}${Platform.pathSeparator}keep.txt',
      );
      await unrelated.writeAsString('keep');

      await FileStore.releaseMaterializedFile(unrelated.path);

      expect(await unrelated.readAsString(), 'keep');
    });
  });
}

class _FakeCaptureKeyStore implements CaptureKeyStore {
  _FakeCaptureKeyStore(this.key);

  final List<int> key;

  @override
  Future<List<int>> getOrCreateKey() async => key;
}

class _ThrowingCaptureKeyStore implements CaptureKeyStore {
  @override
  Future<List<int>> getOrCreateKey() async =>
      throw StateError('key unavailable');
}
