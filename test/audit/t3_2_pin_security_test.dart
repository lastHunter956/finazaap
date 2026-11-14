import 'package:finazaap/Screens/pin_code_screen.dart';
import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/core/security/encryption_service.dart';
import 'package:finazaap/providers/pin_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InMemoryKeyStore implements EncryptionKeyStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _InMemoryKeyStore store;
  late DateTime fakeNow;

  setUp(() async {
    store = _InMemoryKeyStore();
    fakeNow = DateTime(2026, 11, 14, 12, 0, 0);
    SharedPreferences.setMockInitialValues({});
    await PrefsManager.init();
  });

  group('T3.2 PinProvider PBKDF2-HMAC-SHA256, migración y lockout', () {
    test('setPin guarda hash PBKDF2 con salt aleatorio y nunca el PIN en claro', () async {
      final provider = PinProvider(
        keyStore: store,
        skipBiometricCheck: true,
        nowProvider: () => fakeNow,
      );
      await provider.ensureInitialized();

      await provider.setPin('1234');
      final firstHash = store.data['user_pin_hash_v2'];

      expect(firstHash, isNotNull);
      expect(firstHash, startsWith('pbkdf2_sha256\$10000\$'));
      expect(firstHash, isNot(contains('1234')));
      expect(store.data.containsKey('user_pin'), isFalse);
      expect(store.data['pin_enabled'], equals('true'));
      expect(await provider.verifyPin('1234'), isTrue);
      expect(await provider.verifyPin('9999'), isFalse);

      // Un segundo setPin con el mismo PIN debe generar un salt diferente
      await provider.setPin('1234');
      final secondHash = store.data['user_pin_hash_v2'];
      expect(secondHash, isNot(equals(firstHash)));
    });

    test('ensureInitialized migra pin_enabled y biometric_enabled desde SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'pin_enabled': true,
        'biometric_enabled': true,
      });
      await PrefsManager.init();
      final prefs = await PrefsManager.instance;
      await prefs.reload();

      final provider = PinProvider(
        keyStore: store,
        skipBiometricCheck: true,
        nowProvider: () => fakeNow,
      );
      await provider.ensureInitialized();

      expect(provider.isPinEnabled, isTrue);
      expect(provider.isBiometricEnabled, isTrue);
      expect(store.data['pin_enabled'], equals('true'));
      expect(store.data['biometric_enabled'], equals('true'));
      expect(prefs.containsKey('pin_enabled'), isFalse);
      expect(prefs.containsKey('biometric_enabled'), isFalse);
    });

    test('migra PIN legado en texto plano al primer verifyPin exitoso', () async {
      store.data['user_pin'] = '4321';
      store.data['pin_enabled'] = 'true';

      final provider = PinProvider(
        keyStore: store,
        skipBiometricCheck: true,
        nowProvider: () => fakeNow,
      );
      await provider.ensureInitialized();

      expect(await provider.verifyPin('0000'), isFalse);
      expect(store.data['user_pin'], equals('4321'));

      expect(await provider.verifyPin('4321'), isTrue);
      expect(store.data.containsKey('user_pin'), isFalse);
      expect(store.data['user_pin_hash_v2'], startsWith('pbkdf2_sha256\$10000\$'));
    });

    test('lockout exponencial persistido tras 5 intentos fallidos (30s, 60s)', () async {
      final provider = PinProvider(
        keyStore: store,
        skipBiometricCheck: true,
        nowProvider: () => fakeNow,
      );
      await provider.ensureInitialized();
      await provider.setPin('2468');

      for (var i = 0; i < 4; i++) {
        expect(await provider.verifyPin('0000'), isFalse);
        expect(provider.isLockedOut, isFalse);
      }

      // 5to intento fallido activa bloqueo de 30s
      expect(await provider.verifyPin('0000'), isFalse);
      expect(provider.isLockedOut, isTrue);
      expect(provider.remainingLockoutSeconds, equals(30));

      // Incluso el PIN correcto se rechaza mientras dure el lockout
      expect(await provider.verifyPin('2468'), isFalse);

      // Nueva instancia de PinProvider conserva el lockout persistido
      final reloaded = PinProvider(
        keyStore: store,
        skipBiometricCheck: true,
        nowProvider: () => fakeNow,
      );
      await reloaded.ensureInitialized();
      expect(reloaded.isLockedOut, isTrue);
      expect(reloaded.remainingLockoutSeconds, equals(30));

      // Avanzar 31 segundos y volver a fallar activa 60s
      fakeNow = fakeNow.add(const Duration(seconds: 31));
      expect(reloaded.isLockedOut, isFalse);
      expect(await reloaded.verifyPin('0000'), isFalse);
      expect(reloaded.isLockedOut, isTrue);
      expect(reloaded.remainingLockoutSeconds, equals(60));

      // Tras expirar y validar PIN correcto, se limpia el estado de lockout
      fakeNow = fakeNow.add(const Duration(seconds: 61));
      expect(await reloaded.verifyPin('2468'), isTrue);
      expect(reloaded.failedAttempts, equals(0));
      expect(reloaded.isLockedOut, isFalse);
    });
  });

  group('T3.2 PinCodeScreen PopScope y UI de lockout', () {
    testWidgets('PopScope bloquea back cuando mode == verify y onCancel == null', (tester) async {
      final provider = PinProvider(
        keyStore: store,
        skipBiometricCheck: true,
        nowProvider: () => fakeNow,
      );
      await provider.ensureInitialized();
      await provider.setPin('1234');

      await tester.pumpWidget(
        MaterialApp(
          home: PinCodeScreen(
            mode: PinMode.verify,
            pinProvider: provider,
          ),
        ),
      );
      await tester.pump();

      final popScope = tester.widget<PopScope<dynamic>>(
        find.byWidgetPredicate((w) => w is PopScope),
      );
      expect(popScope.canPop, isFalse);
    });

    testWidgets('muestra mensaje de bloqueo cuando PinProvider está en lockout', (tester) async {
      final provider = PinProvider(
        keyStore: store,
        skipBiometricCheck: true,
        nowProvider: () => fakeNow,
      );
      await provider.ensureInitialized();
      await provider.setPin('1234');
      for (var i = 0; i < 5; i++) {
        await provider.verifyPin('0000');
      }

      await tester.pumpWidget(
        MaterialApp(
          home: PinCodeScreen(
            mode: PinMode.verify,
            pinProvider: provider,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Demasiados intentos. Espera'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
