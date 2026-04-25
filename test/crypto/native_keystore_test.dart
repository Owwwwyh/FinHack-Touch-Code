import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tng_clone_flutter/core/crypto/native_keystore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the method channel
  const testChannel = MethodChannel('com.tng.finhack/keystore');
  final List<MethodCall> methodCalls = [];

  setUp(() {
    methodCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(testChannel, (call) async {
      methodCalls.add(call);

      switch (call.method) {
        case 'generateKey':
          return Uint8List.fromList(List.generate(32, (i) => i % 256));

        case 'sign':
          return Uint8List.fromList(List.generate(64, (i) => i % 256));

        case 'getPublicKey':
          return Uint8List.fromList(List.generate(32, (i) => i % 256));

        case 'keyExists':
          return call.arguments['alias'] == 'test_key';

        case 'listKeys':
          return ['test_key', 'another_key'];

        case 'deleteKey':
          return null;

        case 'getAttestationCertificateChain':
          return ['cert1_base64', 'cert2_base64'];

        default:
          throw PlatformException(code: 'NOT_IMPLEMENTED');
      }
    });
  });

  group('NativeKeystore', () {
    test('generateKey calls platform with correct arguments', () async {
      final alias = 'test_key_123';
      final challenge = Uint8List.fromList([1, 2, 3, 4]);

      final result = await NativeKeystore.generateKey(alias, challenge);

      expect(methodCalls, isNotEmpty);
      expect(methodCalls.last.method, 'generateKey');
      expect(methodCalls.last.arguments['alias'], alias);
      expect(methodCalls.last.arguments['attestationChallenge'], challenge);
      expect(result.length, 32);
    });

    test('sign calls platform with correct arguments', () async {
      final alias = 'test_key';
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);

      final result = await NativeKeystore.sign(alias, data);

      expect(methodCalls, isNotEmpty);
      expect(methodCalls.last.method, 'sign');
      expect(methodCalls.last.arguments['alias'], alias);
      expect(methodCalls.last.arguments['data'], data);
      expect(methodCalls.last.arguments['amountCents'], 0);
      expect(result.length, 64);
    });

    test('getPublicKey calls platform with correct arguments', () async {
      final alias = 'test_key';

      final result = await NativeKeystore.getPublicKey(alias);

      expect(methodCalls, isNotEmpty);
      expect(methodCalls.last.method, 'getPublicKey');
      expect(methodCalls.last.arguments['alias'], alias);
      expect(result.length, 32);
    });

    test('keyExists calls platform with correct arguments', () async {
      final alias = 'test_key';

      final result = await NativeKeystore.keyExists(alias);

      expect(methodCalls, isNotEmpty);
      expect(methodCalls.last.method, 'keyExists');
      expect(methodCalls.last.arguments['alias'], alias);
      expect(result, true);
    });

    test('keyExists returns false for nonexistent key', () async {
      final result = await NativeKeystore.keyExists('nonexistent');

      expect(result, false);
    });

    test('listKeys calls platform and returns list', () async {
      final result = await NativeKeystore.listKeys();

      expect(methodCalls, isNotEmpty);
      expect(methodCalls.last.method, 'listKeys');
      expect(result, isA<List<String>>());
      expect(result.length, 2);
      expect(result[0], 'test_key');
    });

    test('deleteKey calls platform with correct arguments', () async {
      final alias = 'test_key';

      await NativeKeystore.deleteKey(alias);

      expect(methodCalls, isNotEmpty);
      expect(methodCalls.last.method, 'deleteKey');
      expect(methodCalls.last.arguments['alias'], alias);
    });

    test('getAttestationCertificateChain calls platform', () async {
      final alias = 'test_key';

      final result = await NativeKeystore.getAttestationCertificateChain(alias);

      expect(methodCalls, isNotEmpty);
      expect(methodCalls.last.method, 'getAttestationCertificateChain');
      expect(methodCalls.last.arguments['alias'], alias);
      expect(result, isA<List<String>>());
      expect(result.length, 2);
    });

    test('generateKey throws on platform exception', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, (call) async {
        throw PlatformException(
            code: 'KEYSTORE_ERROR', message: 'Key generation failed');
      });

      expect(
        () => NativeKeystore.generateKey('test', Uint8List(0)),
        throwsA(isA<Exception>()),
      );
    });

    test('sign throws on platform exception', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, (call) async {
        throw PlatformException(
            code: 'KEYSTORE_ERROR', message: 'Signing failed');
      });

      expect(
        () => NativeKeystore.sign('test', Uint8List(0)),
        throwsA(isA<Exception>()),
      );
    });

    test('handles null responses gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, (call) async {
        if (call.method == 'generateKey') {
          return null;
        }
        return [];
      });

      expect(
        () => NativeKeystore.generateKey('test', Uint8List(0)),
        throwsA(isA<Exception>()),
      );
    });
  });
}
