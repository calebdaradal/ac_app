import 'dart:io';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import '../screens/vehicles/asc_screen.dart';
import '../screens/vehicles/stk_screen.dart';
import '../screens/home_screen.dart';

/// Service to handle OneSignal push notifications
/// Manages device token registration and notification handling
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _initialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Set the navigator key for navigation from notifications
  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  /// Initialize OneSignal with App ID from environment variables
  /// Call this in main() after Supabase initialization
  Future<void> initialize() async {
    if (_initialized) {
      print('[NotificationService] Already initialized');
      return;
    }

    try {
      final onesignalAppId = dotenv.env['ONESIGNAL_APP_ID'];
      
      if (onesignalAppId == null || onesignalAppId.isEmpty) {
        print('[NotificationService] ⚠️ ONESIGNAL_APP_ID not found in .env file');
        print('[NotificationService] Notifications will not work until OneSignal App ID is configured');
        return;
      }

      print('[NotificationService] Initializing OneSignal with App ID: $onesignalAppId');
      
      // Initialize OneSignal
      OneSignal.initialize(onesignalAppId);
      
      // Request permission
      final permissionGranted = await OneSignal.Notifications.requestPermission(true);
      
      if (permissionGranted) {
        print('[NotificationService] ✅ Notification permission granted');
        
        // Get device token
        final deviceState = await OneSignal.User.pushSubscription.id;
        
        if (deviceState != null) {
          print('[NotificationService] Device token obtained: $deviceState');
          // Store token if user is logged in
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            await storeDeviceToken(deviceState);
          }
        } else {
          print('[NotificationService] ⚠️ Device token not available yet');
        }
        
        // Listen for token changes
        OneSignal.User.pushSubscription.addObserver((state) {
          if (state.current.id != null) {
            print('[NotificationService] Device token updated: ${state.current.id}');
            storeDeviceToken(state.current.id!);
          }
        });
      } else {
        print('[NotificationService] ⚠️ Notification permission denied');
      }

      // Set up notification click handler
      OneSignal.Notifications.addClickListener((event) {
        print('[NotificationService] Notification clicked: ${event.notification.notificationId}');
        final data = event.notification.additionalData;
        
        if (data != null) {
          print('[NotificationService] Notification data: $data');
          _handleNotificationNavigation(data);
        }
      });

      _initialized = true;
      print('[NotificationService] ✅ Initialization complete');
    } catch (e) {
      print('[NotificationService] ❌ Error initializing OneSignal: $e');
      // Don't throw - allow app to continue without notifications
    }
  }

  /// Store device token in Supabase device_tokens table
  /// Called automatically when token is obtained or updated
  /// Deactivates old tokens for this device if they belong to a different user
  Future<void> storeDeviceToken(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('[NotificationService] No authenticated user, skipping token storage');
        return;
      }

      final platform = Platform.isIOS ? 'ios' : 'android';
      
      print('[NotificationService] Storing device token for user: ${user.id}, platform: $platform');
      
      // First, deactivate any old tokens for this device that belong to different users
      // This prevents notifications from going to the wrong user when switching accounts
      try {
        final deactivateResult = await Supabase.instance.client
            .from('device_tokens')
            .update({'is_active': false})
            .eq('device_token', token)
            .neq('user_id', user.id)
            .eq('is_active', true)
            .select();
        
        if (deactivateResult.isNotEmpty) {
          print('[NotificationService] Deactivated ${deactivateResult.length} old token(s) for this device from different user(s)');
        }
      } catch (e) {
        print('[NotificationService] Warning: Could not deactivate old tokens: $e');
        // Continue anyway
      }
      
      // Try to update first (in case token already exists)
      // This handles both cases: token exists for this user, or token exists for different user
      try {
        final updateResult = await Supabase.instance.client
            .from('device_tokens')
            .update({
              'user_id': user.id,
              'is_active': true,
              'platform': platform,
            })
            .eq('device_token', token)
            .select();
        
        if (updateResult.isNotEmpty) {
          print('[NotificationService] ✅ Updated existing token for user ${user.id}');
          // Verify the update worked
          final verifyResult = await Supabase.instance.client
              .from('device_tokens')
              .select('is_active, user_id')
              .eq('device_token', token)
              .eq('user_id', user.id)
              .single();
          
          if (verifyResult['is_active'] == true && verifyResult['user_id'] == user.id) {
            print('[NotificationService] ✅ Device token updated and verified for user ${user.id}');
            return; // Success
          }
        }
      } catch (updateError) {
        print('[NotificationService] Update failed (token might not exist): $updateError');
        // Continue to try insert
      }
      
      // If update didn't work (token doesn't exist), try to insert
      try {
        await Supabase.instance.client
            .from('device_tokens')
            .insert({
              'user_id': user.id,
              'device_token': token,
              'platform': platform,
              'is_active': true,
            });
        print('[NotificationService] ✅ Inserted new token for user ${user.id}');
      } catch (insertError) {
        // If insert fails with duplicate key, token exists but update didn't work
        // This shouldn't happen, but handle it gracefully
        if (insertError.toString().contains('duplicate key') || insertError.toString().contains('23505')) {
          print('[NotificationService] ⚠️ Token exists but update failed, trying update again...');
          // Try update one more time
          try {
            await Supabase.instance.client
                .from('device_tokens')
                .update({
                  'user_id': user.id,
                  'is_active': true,
                  'platform': platform,
                })
                .eq('device_token', token);
            print('[NotificationService] ✅ Updated token on retry');
            return;
          } catch (retryError) {
            print('[NotificationService] ❌ Both insert and update failed: $retryError');
            throw insertError; // Re-throw original error
          }
        } else {
          throw insertError; // Re-throw if it's a different error
        }
      }
      
      // Verify the token was stored/updated correctly
      final verifyResult = await Supabase.instance.client
          .from('device_tokens')
          .select('is_active, user_id')
          .eq('device_token', token)
          .eq('user_id', user.id)
          .single();
      
      if (verifyResult['is_active'] == true && verifyResult['user_id'] == user.id) {
        print('[NotificationService] ✅ Device token stored and verified for user ${user.id}');
      } else {
        print('[NotificationService] ⚠️ Device token stored but verification failed: $verifyResult');
      }
    } catch (e) {
      print('[NotificationService] ❌ Error storing device token: $e');
      // Don't throw - token storage failure shouldn't break the app
    }
  }

  /// Remove device token when user logs out
  /// Deactivates ALL device tokens for the current user
  Future<void> removeDeviceToken() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('[NotificationService] No authenticated user, cannot remove device tokens');
        return;
      }

      // Get current device token (for logging)
      final deviceState = await OneSignal.User.pushSubscription.id;
      
      // Deactivate ALL device tokens for this user (not just current device)
      // This ensures no notifications are sent to old sessions
      final result = await Supabase.instance.client
          .from('device_tokens')
          .update({'is_active': false})
          .eq('user_id', user.id)
          .eq('is_active', true)
          .select();
      
      final deactivatedCount = result.length;
      print('[NotificationService] ✅ Deactivated $deactivatedCount device token(s) for user ${user.id}');
      
      if (deviceState != null) {
        print('[NotificationService] Current device token: $deviceState');
      }
    } catch (e) {
      print('[NotificationService] ❌ Error removing device tokens: $e');
      // Don't throw - allow logout to continue even if token removal fails
    }
  }

  /// Handle navigation when notification is tapped
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    if (_navigatorKey?.currentState == null) {
      print('[NotificationService] Navigator key not set, cannot navigate');
      return;
    }

    final type = data['type'] as String?;
    final screen = data['screen'] as String?;
    final vehicleId = data['vehicle_id'];
    final vehicleName = data['vehicle_name'] as String?;

    print('[NotificationService] Handling navigation - type: $type, screen: $screen, vehicleId: $vehicleId, vehicleName: $vehicleName');

    // Navigate based on notification type
    if (type == 'yield_update' || type == 'deposit_verified' || type == 'withdrawal_verified') {
      // Navigate to the appropriate vehicle screen based on vehicle name
      if (vehicleName != null) {
        final routeName = _getVehicleRoute(vehicleName);
        if (routeName != null) {
          print('[NotificationService] Navigating to: $routeName');
          _navigatorKey!.currentState!.pushNamed(routeName);
        } else {
          // Fallback to home screen if vehicle not recognized
          print('[NotificationService] Vehicle not recognized, navigating to home');
          _navigatorKey!.currentState!.pushNamed(HomeScreen.routeName);
        }
      } else if (screen == 'transaction_history') {
        // Fallback: navigate to home if we don't have vehicle info
        print('[NotificationService] No vehicle info, navigating to home');
        _navigatorKey!.currentState!.pushNamed(HomeScreen.routeName);
      }
    } else {
      // Default: navigate to home screen
      print('[NotificationService] Unknown notification type, navigating to home');
      _navigatorKey!.currentState!.pushNamed(HomeScreen.routeName);
    }
  }

  /// Map vehicle name to route name
  String? _getVehicleRoute(String vehicleName) {
    // Normalize vehicle name (case-insensitive)
    final normalized = vehicleName.toUpperCase().trim();
    
    switch (normalized) {
      case 'AFF':
      case 'ASCENDO FUTURES FUND':
        return AscScreen.routeName;
      case 'SP':
      case 'STK':
      case 'SOL/ETH STAKING POOL':
      case 'STAKING POOL':
        return StkScreen.routeName;
      default:
        // Try to match partial names
        if (normalized.contains('FUTURES') || normalized.contains('AFF')) {
          return AscScreen.routeName;
        }
        if (normalized.contains('STAKING') || normalized.contains('STK') || normalized.contains('SOL') || normalized.contains('ETH')) {
          return StkScreen.routeName;
        }
        return null;
    }
  }

  /// Check if notifications are initialized
  bool get isInitialized => _initialized;
}

