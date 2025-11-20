/// Service to track OTP sessions
/// This allows users to return to the email screen and continue with the same OTP
/// if they accidentally navigate back, without needing to request a new OTP
class OtpSessionService {
  static String? _lastEmail;
  static DateTime? _lastOtpTimestamp;
  static const int _otpValiditySeconds = 60;

  /// Store an OTP session when an OTP is successfully requested
  static void storeOtpSession(String email) {
    _lastEmail = email.toLowerCase().trim();
    _lastOtpTimestamp = DateTime.now();
  }

  /// Check if there's a valid OTP session for the given email
  /// Returns the remaining seconds if valid, null otherwise
  static int? getValidSessionRemainingSeconds(String email) {
    final normalizedEmail = email.toLowerCase().trim();
    
    // Check if email matches and session exists
    if (_lastEmail != normalizedEmail || _lastOtpTimestamp == null) {
      return null;
    }

    // Calculate elapsed time
    final elapsed = DateTime.now().difference(_lastOtpTimestamp!);
    final remaining = _otpValiditySeconds - elapsed.inSeconds;

    // Return remaining seconds if still valid (>= 0), null otherwise
    return remaining >= 0 ? remaining : null;
  }

  /// Check if there's a valid session for the email (without returning seconds)
  static bool hasValidSession(String email) {
    return getValidSessionRemainingSeconds(email) != null;
  }

  /// Clear the stored session (e.g., after successful verification)
  static void clearSession() {
    _lastEmail = null;
    _lastOtpTimestamp = null;
  }

  /// Get the timestamp of the last OTP request for an email
  /// Returns null if no valid session exists
  static DateTime? getSessionTimestamp(String email) {
    if (hasValidSession(email)) {
      return _lastOtpTimestamp;
    }
    return null;
  }
}

