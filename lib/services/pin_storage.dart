import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_service.dart';

class PinStorage {
  static const _key = 'user_pin';
  static const _uidKey = 'user_uid';
  static const _storage = FlutterSecureStorage();

  // Platform-specific secure options
  static const _iOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );
  static const _aOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  /// Hash a PIN using SHA-256
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Save PIN locally (for quick unlock)
  static Future<void> savePin(String pin) async {
    await _storage.write(
      key: _key,
      value: pin,
      iOptions: _iOptions,
      aOptions: _aOptions,
    );
  }

  /// Read PIN from local storage
  static Future<String?> readPin() async {
    return _storage.read(key: _key, iOptions: _iOptions, aOptions: _aOptions);
  }

  /// Clear local PIN
  static Future<void> clearPin() async {
    await _storage.delete(key: _key, iOptions: _iOptions, aOptions: _aOptions);
  }

  /// Save user UID locally (persists across logout)
  static Future<void> saveUid(String uid) async {
    await _storage.write(
      key: _uidKey,
      value: uid,
      iOptions: _iOptions,
      aOptions: _aOptions,
    );
    print('[PinStorage] UID saved locally: $uid');
  }

  /// Read UID from local storage
  static Future<String?> readUid() async {
    return _storage.read(key: _uidKey, iOptions: _iOptions, aOptions: _aOptions);
  }

  /// Clear local UID (call this only when truly removing user data)
  static Future<void> clearUid() async {
    await _storage.delete(key: _uidKey, iOptions: _iOptions, aOptions: _aOptions);
  }

  /// Save PIN hash to database (during signup/PIN creation)
  static Future<void> savePinToDatabase(String pin) async {
    final uid = UserProfileService().profile?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    final hashedPin = hashPin(pin);
    
    print('[PinStorage] Saving PIN to database for user: $uid');
    print('[PinStorage] Hashed PIN: $hashedPin');
    
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .update({'pin': hashedPin})
          .eq('id', uid)
          .select();
      
      print('[PinStorage] Update response: $response');
    } catch (e) {
      print('[PinStorage] Error saving PIN to database: $e');
      rethrow;
    }
  }

  /// Check if user has a PIN in the database
  static Future<bool> hasPinInDatabase() async {
    // Use currently authenticated user (works right after OTP verification)
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      print('[PinStorage] No authenticated user found');
      return false;
    }

    print('[PinStorage] Checking PIN for user: $uid');

    final response = await Supabase.instance.client
        .from('profiles')
        .select('pin')
        .eq('id', uid)
        .maybeSingle();

    print('[PinStorage] PIN check response: $response');

    if (response == null) {
      print('[PinStorage] No profile found for user');
      return false;
    }
    
    final pin = response['pin'];
    final hasPin = pin != null && pin.toString().isNotEmpty;
    print('[PinStorage] User has PIN: $hasPin');
    return hasPin;
  }

  /// Verify PIN against database hash
  static Future<bool> verifyPinWithDatabase(String pin) async {
    // Use currently authenticated user
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return false;

    final response = await Supabase.instance.client
        .from('profiles')
        .select('pin')
        .eq('id', uid)
        .maybeSingle();

    if (response == null) return false;
    
    final storedHash = response['pin'] as String?;
    if (storedHash == null) return false;

    final inputHash = hashPin(pin);
    return inputHash == storedHash;
  }
}


