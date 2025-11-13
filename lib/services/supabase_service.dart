import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> requestOtp(String email) async {
    // Request a 6-digit email OTP (no magic link). Make sure Email provider is set to OTP in Supabase.
    // shouldCreateUser: true allows OTP for both existing users (created by admin) and new signups
    await client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: null, // ensures no magic link deep link is included
      shouldCreateUser: true,
    );
  }

  static Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) async {
    return client.auth.verifyOTP(
      token: token,
      type: OtpType.email,
      email: email,
    );
  }
}


