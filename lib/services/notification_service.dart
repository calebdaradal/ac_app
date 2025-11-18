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
      
      // Strategy: Check if token exists first, then update or insert accordingly
      // This handles account switching on the same device properly
      
      print('[NotificationService] Attempting to register token for user ${user.id}, device_token: $token');
      
      // Step 1: Check if token exists (we can see it even if it belongs to another user)
      final existingToken = await Supabase.instance.client
          .from('device_tokens')
          .select('id, user_id, is_active')
          .eq('device_token', token)
          .maybeSingle();
      
      if (existingToken != null) {
        print('[NotificationService] Token exists: user_id=${existingToken['user_id']}, is_active=${existingToken['is_active']}');
        
        // Token exists - try to update it
        // If it belongs to a different user, RLS should allow update if policy is correct
        try {
          final updateResult = await Supabase.instance.client
              .from('device_tokens')
              .update({
                'user_id': user.id,
                'is_active': true,
                'platform': platform,
              })
              .eq('device_token', token)
              .select('user_id, is_active');
          
          print('[NotificationService] Update result: ${updateResult.length} row(s) updated');
          
          if (updateResult.isNotEmpty) {
            final updated = updateResult[0];
            print('[NotificationService] Updated: user_id=${updated['user_id']}, is_active=${updated['is_active']}');
            
            // Verify by querying again
            final verify = await Supabase.instance.client
                .from('device_tokens')
                .select('user_id, is_active')
                .eq('device_token', token)
                .single();
            
            print('[NotificationService] Verification: user_id=${verify['user_id']}, is_active=${verify['is_active']}');
            
            if (verify['is_active'] == true && verify['user_id'] == user.id) {
              print('[NotificationService] ✅ Token updated and verified for user ${user.id}');
              return; // Success!
            } else {
              print('[NotificationService] ⚠️ Verification failed - RLS may be blocking');
            }
          } else {
            print('[NotificationService] ⚠️ Update returned 0 rows - RLS policy is blocking the update');
            print('[NotificationService] ⚠️ Please ensure RLS policy allows: USING (true) WITH CHECK (auth.uid()::text = user_id)');
          }
        } catch (updateError) {
          print('[NotificationService] Update error: $updateError');
        }
      } else {
        print('[NotificationService] Token does not exist, will insert new one');
      }
      
      // Step 2: If token doesn't exist or update failed, try insert
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
        
        // Verify insert
        final verifyInsert = await Supabase.instance.client
            .from('device_tokens')
            .select('user_id, is_active')
            .eq('device_token', token)
            .single();
        
        if (verifyInsert['is_active'] == true && verifyInsert['user_id'] == user.id) {
          print('[NotificationService] ✅ Token inserted and verified for user ${user.id}');
          return; // Success!
        }
      } catch (insertError) {
        if (insertError.toString().contains('duplicate key') || insertError.toString().contains('23505')) {
          print('[NotificationService] ⚠️ Insert failed - token exists but update returned 0 rows');
          print('[NotificationService] ⚠️ This means RLS policy is blocking UPDATE');
          print('[NotificationService] ⚠️ Please run FINAL_RLS_FIX.sql to fix the RLS policy');
          
          // Last resort: Try update one more time without verification
          try {
            await Supabase.instance.client
                .from('device_tokens')
                .update({
                  'user_id': user.id,
                  'is_active': true,
                  'platform': platform,
                })
                .eq('device_token', token);
            
            print('[NotificationService] Attempted final update (no verification)');
          } catch (finalError) {
            print('[NotificationService] ❌ Final update also failed: $finalError');
          }
        } else {
          print('[NotificationService] ❌ Insert failed: $insertError');
        }
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

