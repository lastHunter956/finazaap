import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinProvider with ChangeNotifier {
  static const String _pinKey = 'user_pin';
  static const String _pinEnabledKey = 'pin_enabled';
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isPinEnabled = false;
  bool _isLoading = true;

  bool get isPinEnabled => _isPinEnabled;
  bool get isLoading => _isLoading;

  PinProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPinEnabled = prefs.getBool(_pinEnabledKey) ?? false;
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
  }
  
  Future<bool> checkHasPin() async {
    return await _storage.containsKey(key: _pinKey);
  }
}
