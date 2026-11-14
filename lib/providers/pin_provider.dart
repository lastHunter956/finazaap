import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/core/security/encryption_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class PinProvider with ChangeNotifier {
  static const String _legacyPinKey = 'user_pin';
  static const String _pinHashKey = 'user_pin_hash_v2';
  static const String _pinEnabledKey = 'pin_enabled';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _failedAttemptsKey = 'pin_failed_attempts';
  static const String _lockoutUntilKey = 'pin_lockout_until_ms';

  static const int maxFailedAttemptsBeforeLockout = 5;
  static const int baseLockoutSeconds = 30;
  static const int maxLockoutSeconds = 900;
  static const int _pbkdf2Iterations = 10000;
  static const int _saltLengthBytes = 16;
  static const int _derivedKeyBytes = 32;

  final EncryptionKeyStore _storage;
  final LocalAuthentication? _localAuth;
  final DateTime Function() _now;
  final Completer<void> _initCompleter = Completer<void>();

  bool _isPinEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isBiometricAvailable = false;
  bool _isLoading = true;
  int _failedAttempts = 0;
  int _lockoutUntilMs = 0;

  bool get isPinEnabled => _isPinEnabled;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isBiometricAvailable => _isBiometricAvailable;
  bool get isLoading => _isLoading;
  int get failedAttempts => _failedAttempts;

  bool get isLockedOut => remainingLockoutSeconds > 0;

  int get remainingLockoutSeconds {
    if (_lockoutUntilMs <= 0) return 0;
    final diffMs = _lockoutUntilMs - _now().millisecondsSinceEpoch;
    if (diffMs <= 0) return 0;
    return (diffMs / 1000).ceil();
  }

  Duration get remainingLockout => Duration(seconds: remainingLockoutSeconds);

  PinProvider({
    EncryptionKeyStore? keyStore,
    LocalAuthentication? localAuth,
    DateTime Function()? nowProvider,
    bool skipBiometricCheck = false,
  })  : _storage = keyStore ?? const FlutterSecureEncryptionKeyStore(),
        _localAuth = skipBiometricCheck ? null : (localAuth ?? LocalAuthentication()),
        _now = nowProvider ?? DateTime.now {
    _init();
  }

  /// Garantiza que la carga inicial desde almacenamiento seguro haya concluido.
  Future<void> ensureInitialized() => _initCompleter.future;

  Future<void> _init() async {
    try {
      // 1. Leer pin_enabled y biometric_enabled desde FlutterSecureStorage,
      // migrando desde SharedPreferences si existen valores legados.
      String? pinEnabledRaw;
      String? bioEnabledRaw;
      String? failedRaw;
      String? lockoutRaw;

      try {
        pinEnabledRaw = await _storage.read(_pinEnabledKey);
        bioEnabledRaw = await _storage.read(_biometricEnabledKey);
        failedRaw = await _storage.read(_failedAttemptsKey);
        lockoutRaw = await _storage.read(_lockoutUntilKey);
      } on MissingPluginException {
        // Entorno de pruebas sin canal nativo de FlutterSecureStorage.
      }

      if (pinEnabledRaw == null || bioEnabledRaw == null) {
        try {
          final prefs = await PrefsManager.instance;
          if (pinEnabledRaw == null && prefs.containsKey(_pinEnabledKey)) {
            final legacyVal = prefs.getBool(_pinEnabledKey) ?? false;
            pinEnabledRaw = legacyVal.toString();
            try {
              await _storage.write(_pinEnabledKey, pinEnabledRaw);
              await prefs.remove(_pinEnabledKey);
            } on MissingPluginException {}
          }
          if (bioEnabledRaw == null && prefs.containsKey(_biometricEnabledKey)) {
            final legacyVal = prefs.getBool(_biometricEnabledKey) ?? false;
            bioEnabledRaw = legacyVal.toString();
            try {
              await _storage.write(_biometricEnabledKey, bioEnabledRaw);
              await prefs.remove(_biometricEnabledKey);
            } on MissingPluginException {}
          }
        } catch (_) {
          // Ignorar si SharedPreferences no está inicializado en tests aislados.
        }
      }

      _isPinEnabled = pinEnabledRaw == 'true';
      _isBiometricEnabled = bioEnabledRaw == 'true';
      _failedAttempts = int.tryParse(failedRaw ?? '') ?? 0;
      _lockoutUntilMs = int.tryParse(lockoutRaw ?? '') ?? 0;

      // 2. Verificar disponibilidad biométrica
      if (_localAuth != null) {
        try {
          _isBiometricAvailable = await _localAuth!.canCheckBiometrics ||
              await _localAuth!.isDeviceSupported();
        } catch (_) {
          _isBiometricAvailable = false;
        }
      }
    } finally {
      _isLoading = false;
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
      notifyListeners();
    }
  }

  /// Guarda el PIN hasheado con PBKDF2-HMAC-SHA256 + salt aleatorio de 16 bytes.
  Future<void> setPin(String pin) async {
    final salt = _generateSalt(_saltLengthBytes);
    final hash = _derivePbkdf2(pin, salt, _pbkdf2Iterations, _derivedKeyBytes);
    final encoded =
        'pbkdf2_sha256\$$_pbkdf2Iterations\$${base64Url.encode(salt)}\$${base64Url.encode(hash)}';

    await _storage.write(_pinHashKey, encoded);
    await _storage.delete(_legacyPinKey);
    await _resetLockoutState();
    await _enablePin(true);
  }

  /// Verifica el PIN aplicando lockout exponencial tras 5 intentos fallidos
  /// y migración transparente si existe un PIN legado en texto plano.
  Future<bool> verifyPin(String pin) async {
    await ensureInitialized();

    if (isLockedOut) {
      return false;
    }

    final storedHash = await _storage.read(_pinHashKey);
    if (storedHash != null && storedHash.isNotEmpty) {
      final isValid = _verifyPbkdf2Record(pin, storedHash);
      if (isValid) {
        await _resetLockoutState();
        return true;
      }
      await _recordFailedAttempt();
      return false;
    }

    // Migración transparente desde PIN legado en texto plano al primer login válido.
    final legacyPin = await _storage.read(_legacyPinKey);
    if (legacyPin != null && _constantTimeStringEquals(legacyPin, pin)) {
      await setPin(pin);
      return true;
    }

    await _recordFailedAttempt();
    return false;
  }

  Future<void> _recordFailedAttempt() async {
    _failedAttempts += 1;
    await _storage.write(_failedAttemptsKey, _failedAttempts.toString());

    if (_failedAttempts >= maxFailedAttemptsBeforeLockout) {
      final exponent =
          (_failedAttempts - maxFailedAttemptsBeforeLockout).clamp(0, 10);
      final durationSeconds =
          min(baseLockoutSeconds * (1 << exponent), maxLockoutSeconds);
      _lockoutUntilMs =
          _now().millisecondsSinceEpoch + (durationSeconds * 1000);
      await _storage.write(_lockoutUntilKey, _lockoutUntilMs.toString());
    }
    notifyListeners();
  }

  Future<void> _resetLockoutState() async {
    _failedAttempts = 0;
    _lockoutUntilMs = 0;
    await _storage.delete(_failedAttemptsKey);
    await _storage.delete(_lockoutUntilKey);
    notifyListeners();
  }

  Future<void> _enablePin(bool enable) async {
    await _storage.write(_pinEnabledKey, enable.toString());
    _isPinEnabled = enable;
    notifyListeners();
  }

  Future<void> disablePin() async {
    await _storage.delete(_pinHashKey);
    await _storage.delete(_legacyPinKey);
    await _resetLockoutState();
    await _enablePin(false);
    await setBiometricEnabled(false);
  }

  Future<bool> checkHasPin() async {
    final hash = await _storage.read(_pinHashKey);
    if (hash != null && hash.isNotEmpty) return true;
    final legacy = await _storage.read(_legacyPinKey);
    return legacy != null && legacy.isNotEmpty;
  }

  // ═══════════════════════════════════════════════════════════════
  // BIOMETRIC METHODS
  // ═══════════════════════════════════════════════════════════════

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(_biometricEnabledKey, enabled.toString());
    _isBiometricEnabled = enabled;
    notifyListeners();
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!_isBiometricAvailable || !_isBiometricEnabled || _localAuth == null) {
      return false;
    }

    try {
      return await _localAuth!.authenticate(
        localizedReason: 'Usa tu huella o Face ID para desbloquear Moneo',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> checkBiometricAvailability() async {
    if (_localAuth == null) {
      _isBiometricAvailable = false;
      return false;
    }
    try {
      final canCheck = await _localAuth!.canCheckBiometrics;
      final isSupported = await _localAuth!.isDeviceSupported();
      _isBiometricAvailable = canCheck || isSupported;
      notifyListeners();
      return _isBiometricAvailable;
    } catch (_) {
      _isBiometricAvailable = false;
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // PBKDF2-HMAC-SHA256 HELPERS
  // ═══════════════════════════════════════════════════════════════

  Uint8List _generateSalt(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  Uint8List _derivePbkdf2(
    String password,
    Uint8List salt,
    int iterations,
    int dkLen,
  ) {
    final passwordBytes = utf8.encode(password);
    final hmac = Hmac(sha256, passwordBytes);
    final hashLen = 32; // SHA-256 output
    final numBlocks = (dkLen / hashLen).ceil();
    final output = BytesBuilder(copy: false);

    for (var blockIndex = 1; blockIndex <= numBlocks; blockIndex++) {
      final blockBytes = Uint8List(4)
        ..buffer.asByteData().setUint32(0, blockIndex, Endian.big);
      final initialInput = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt)
        ..setRange(salt.length, salt.length + 4, blockBytes);

      var u = Uint8List.fromList(hmac.convert(initialInput).bytes);
      final t = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      output.add(t);
    }

    return Uint8List.sublistView(output.toBytes(), 0, dkLen);
  }

  bool _verifyPbkdf2Record(String pin, String record) {
    final parts = record.split('\$');
    if (parts.length != 4 || parts[0] != 'pbkdf2_sha256') {
      return false;
    }
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations <= 0) return false;

    try {
      final salt = Uint8List.fromList(base64Url.decode(parts[2]));
      final expectedHash = base64Url.decode(parts[3]);
      final derived = _derivePbkdf2(pin, salt, iterations, expectedHash.length);
      return _constantTimeBytesEquals(derived, expectedHash);
    } catch (_) {
      return false;
    }
  }

  bool _constantTimeBytesEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  bool _constantTimeStringEquals(String a, String b) {
    return _constantTimeBytesEquals(utf8.encode(a), utf8.encode(b));
  }
}
