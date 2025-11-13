import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Global singleton service to manage user profile data
/// Fetches once after login, stores in memory + local storage
class UserProfileService {
  static final UserProfileService _instance = UserProfileService._internal();
  factory UserProfileService() => _instance;
  UserProfileService._internal();

  UserProfile? _profile;
  
  /// Get current cached profile (null if not loaded)
  UserProfile? get profile => _profile;

  /// Check if profile is loaded
  bool get isLoaded => _profile != null;

  /// Load profile from Supabase database and cache it
  /// Call this after successful login/OTP verification
  Future<void> loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    print('[UserProfileService] Loading profile for auth user: ${user.id}');
    print('[UserProfileService] Auth user email: ${user.email}');

    // Fetch profile from database
    final response = await Supabase.instance.client
        .from('profiles')
        .select('id, first_name, last_name, avatar_url, is_admin, email')
        .eq('id', user.id)
        .maybeSingle();

    print('[UserProfileService] Profile response: $response');

    if (response == null) {
      throw Exception('Profile not found in database');
    }

    _profile = UserProfile(
      uid: response['id'] as String,
      firstName: response['first_name'] as String?,
      lastName: response['last_name'] as String?,
      email: user.email ?? '',
      avatarUrl: response['avatar_url'] as String?,
      isAdmin: response['is_admin'] as bool? ?? false,
    );

    print('[UserProfileService] Loaded profile: uid=${_profile?.uid}, name=${_profile?.fullName}, email=${_profile?.email}, admin=${_profile?.isAdmin}');

    // Persist to local storage
    await _saveToStorage();
  }

  /// Load profile from local storage (for app restart)
  /// Returns true if successfully loaded from cache
  Future<bool> loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('user_profile');
      if (json == null) return false;

      final data = jsonDecode(json) as Map<String, dynamic>;
      _profile = UserProfile.fromJson(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Save profile to local storage
  Future<void> _saveToStorage() async {
    if (_profile == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', jsonEncode(_profile!.toJson()));
  }

  /// Clear profile data from memory and cache (call on logout)
  Future<void> clearProfile() async {
    _profile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_profile');
  }

  /// Completely remove all profile data (use for account deletion only)
  Future<void> deleteProfile() async {
    _profile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_profile');
  }

  /// Refresh profile from database (use sparingly)
  Future<void> refreshProfile() async {
    await loadProfile();
  }
}

/// User profile model
class UserProfile {
  final String uid;
  final String? firstName;
  final String? lastName;
  final String email;
  final String? avatarUrl;
  final bool isAdmin;

  UserProfile({
    required this.uid,
    this.firstName,
    this.lastName,
    required this.email,
    this.avatarUrl,
    this.isAdmin = false,
  });

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return firstName ?? lastName ?? 'User';
  }

  String get initials {
    final first = firstName?.isNotEmpty == true ? firstName![0] : '';
    final last = lastName?.isNotEmpty == true ? lastName![0] : '';
    return (first + last).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'avatar_url': avatarUrl,
        'is_admin': isAdmin,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        uid: json['uid'] as String,
        firstName: json['first_name'] as String?,
        lastName: json['last_name'] as String?,
        email: json['email'] as String,
        avatarUrl: json['avatar_url'] as String?,
        isAdmin: json['is_admin'] as bool? ?? false,
      );
}

