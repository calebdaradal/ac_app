# User Profile Service

## Overview

The `UserProfileService` is a global singleton that manages user profile data throughout the app. It fetches profile data once after login and caches it both in memory and local storage, eliminating the need for repeated database queries.

## Features

- ✅ **Single fetch after login** - Profile data is loaded once after successful authentication
- ✅ **In-memory caching** - Fast access throughout the app session
- ✅ **Persistent storage** - Profile survives app restarts using SharedPreferences
- ✅ **Global access** - Available anywhere in the app via singleton pattern
- ✅ **Automatic cleanup** - Clears on logout

## Profile Data Structure

The service stores the following user data:

```dart
class UserProfile {
  final String uid;           // User ID from Supabase auth
  final String? firstName;    // User's first name
  final String? lastName;     // User's last name
  final String email;         // User's email
  final String? avatarUrl;    // Optional avatar URL
  final bool isAdmin;         // Admin flag
  
  // Computed properties
  String get fullName;        // "First Last" or fallback
  String get initials;        // "FL"
}
```

## Usage

### 1. Loading Profile After Login

The profile is automatically loaded in two places:

**After PIN confirmation (first-time login):**
```dart
// In pin_confirm_screen.dart
await UserProfileService().loadProfile();
```

**After PIN unlock (returning user):**
```dart
// In pin_unlock_screen.dart
final profileService = UserProfileService();
if (!profileService.isLoaded) {
  // Try cache first, then database
  final loadedFromCache = await profileService.loadFromCache();
  if (!loadedFromCache) {
    await profileService.loadProfile();
  }
}
```

### 2. Accessing Profile Data Anywhere

```dart
// Get the profile instance
final profile = UserProfileService().profile;

// Use profile data
if (profile != null) {
  print('User: ${profile.fullName}');
  print('Email: ${profile.email}');
  print('UID: ${profile.uid}');
  print('Is Admin: ${profile.isAdmin}');
}

// Check if loaded
if (UserProfileService().isLoaded) {
  // Profile is available
}
```

### 3. Example: Using in Home Screen

```dart
@override
Widget build(BuildContext context) {
  final profile = UserProfileService().profile;
  
  return Scaffold(
    appBar: AppBar(
      title: Text('Welcome ${profile?.firstName ?? "User"}'),
    ),
    body: Column(
      children: [
        Text('Email: ${profile?.email ?? ""}'),
        Text('UID: ${profile?.uid ?? ""}'),
        if (profile?.isAdmin == true)
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/admin'),
            child: Text('Admin Panel'),
          ),
      ],
    ),
  );
}
```

### 4. Using UID for Database Queries

```dart
// Get current user's UID for queries
final uid = UserProfileService().profile?.uid;

if (uid != null) {
  // Fetch user-specific data
  final transactions = await Supabase.instance.client
      .from('transactions')
      .select()
      .eq('user_id', uid)
      .order('created_at', ascending: false);
      
  // Insert data for current user
  await Supabase.instance.client
      .from('user_preferences')
      .insert({
        'user_id': uid,
        'theme': 'dark',
        'notifications_enabled': true,
      });
}
```

### 5. Refreshing Profile (Use Sparingly)

```dart
// If you need to refresh profile data from the database
// (e.g., after user updates their profile)
await UserProfileService().refreshProfile();
```

### 6. Clearing on Logout

```dart
// Always clear profile when user signs out
await Supabase.instance.client.auth.signOut();
await PinStorage.clearPin();
await UserProfileService().clearProfile(); // ← Important!
```

## Implementation Details

### Data Flow

1. **Login/OTP Verification** → User authenticates
2. **PIN Confirmation** → `loadProfile()` fetches from database
3. **Profile Saved** → Stored in memory + SharedPreferences
4. **App Usage** → Access via `UserProfileService().profile`
5. **App Restart** → `loadFromCache()` restores from SharedPreferences
6. **Logout** → `clearProfile()` removes all cached data

### Database Schema

The service expects a `profiles` table with this structure:

```sql
create table public.profiles (
  id uuid not null default gen_random_uuid(),
  first_name text null,
  last_name text null,
  avatar_url text null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  is_admin boolean null,
  constraint profiles_pkey primary key (id)
);
```

### Error Handling

The service includes basic error handling. If profile loading fails:

```dart
try {
  await UserProfileService().loadProfile();
} catch (e) {
  // Handle error (e.g., show message to user)
  print('Failed to load profile: $e');
}
```

## Benefits

### Before (Without Profile Service)
- ❌ Database query on every screen navigation
- ❌ Loading states everywhere
- ❌ Inconsistent data across screens
- ❌ Poor performance with frequent queries
- ❌ Difficult to access user data globally

### After (With Profile Service)
- ✅ Single database query after login
- ✅ Instant access to profile data
- ✅ Consistent data across entire app
- ✅ Better performance and UX
- ✅ Simple global access pattern

## API Reference

### Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `loadProfile()` | Fetch profile from database and cache | `Future<void>` |
| `loadFromCache()` | Load profile from local storage | `Future<bool>` |
| `clearProfile()` | Clear all cached profile data | `Future<void>` |
| `refreshProfile()` | Re-fetch profile from database | `Future<void>` |

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `profile` | `UserProfile?` | Current cached profile (null if not loaded) |
| `isLoaded` | `bool` | Whether profile is currently loaded |

## Notes

- The service is a **singleton** - always returns the same instance
- Profile data is stored in **SharedPreferences** under the key `user_profile`
- The service does **not** automatically refresh on auth state changes
- You must manually call `clearProfile()` on logout
- For security, sensitive data should not be stored in the profile

## Migration Guide

If you're currently fetching profile data in screens:

**Before:**
```dart
class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user!.id)
        .single();
    setState(() {
      _profile = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return CircularProgressIndicator();
    return Text(_profile?['first_name'] ?? '');
  }
}
```

**After:**
```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final profile = UserProfileService().profile;
    return Text(profile?.firstName ?? '');
  }
}
```

Much simpler! 🎉

