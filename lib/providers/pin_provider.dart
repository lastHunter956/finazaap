import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class PinProvider with ChangeNotifier {
  static const String _pinKey = 'user_pin';
  static const String _pinEnabledKey = 'pin_enabled';
  static const String _biometricEnabledKey = 'biometric_enabled';
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  bool _isPinEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isBiometricAvailable = false;
  bool _isLoading = true;

  bool get isPinEnabled => _isPinEnabled;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isBiometricAvailable => _isBiometricAvailable;
  bool get isLoading => _isLoading;

  PinProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPinEnabled = prefs.getBool(_pinEnabledKey) ?? false;
    _isBiometricEnabled = prefs.getBool(_biometricEnabledKey) ?? false;
    
    // Check if device supports biometrics
    try {
      _isBiometricAvailable = await _localAuth.canCheckBiometrics || 
                              await _localAuth.isDeviceSupported();
    } catch (e) {
      _isBiometricAvailable = false;
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
    await _enablePin(true);
  }

  Future<bool> verifyPin(String pin) async {
    final storedPin = await _storage.read(key: _pinKey);
    return storedPin == pin;
  }

  Future<void> _enablePin(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pinEnabledKey, enable);
    _isPinEnabled = enable;
    notifyListeners();
  }

  Future<void> disablePin() async {
     await _storage.delete(key: _pinKey);
     await _enablePin(false);
     // Also disable biometric if PIN is disabled
     await setBiometricEnabled(false);
  }
  
  Future<bool> checkHasPin() async {
    return await _storage.containsKey(key: _pinKey);
  }

  // ═══════════════════════════════════════════════════════════════
  // BIOMETRIC METHODS
  // ═══════════════════════════════════════════════════════════════

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
    _isBiometricEnabled = enabled;
    notifyListeners();
  }

  /// Attempt to authenticate using biometrics
  /// Returns true if successful, false otherwise
  Future<bool> authenticateWithBiometrics() async {
    if (!_isBiometricAvailable || !_isBiometricEnabled) {
      return false;
    }
    
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Usa tu huella o Face ID para desbloquear Moneo',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      print('❌ Error en autenticación biométrica: $e');
      return false;
    }
  }

  /// Check if biometrics are available on this device
  Future<bool> checkBiometricAvailability() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      _isBiometricAvailable = canCheck || isSupported;
      notifyListeners();
      return _isBiometricAvailable;
    } catch (e) {
      _isBiometricAvailable = false;
      return false;
    }
  }
}
