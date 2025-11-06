import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinStorage {
  static const _key = 'user_pin';
  static const _storage = FlutterSecureStorage();

  // Platform-specific secure options
  static const _iOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );
  static const _aOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  static Future<void> savePin(String pin) async {
    await _storage.write(
      key: _key,
      value: pin,
      iOptions: _iOptions,
      aOptions: _aOptions,
    );
  }

  static Future<String?> readPin() async {
    return _storage.read(key: _key, iOptions: _iOptions, aOptions: _aOptions);
  }

  static Future<void> clearPin() async {
    await _storage.delete(key: _key, iOptions: _iOptions, aOptions: _aOptions);
  }
}


