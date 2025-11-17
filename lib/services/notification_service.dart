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
  Future<void> storeDeviceToken(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('[NotificationService] No authenticated user, skipping token storage');
        return;
      }

      final platform = Platform.isIOS ? 'ios' : 'android';
      
      print('[NotificationService] Storing device token for user: ${user.id}, platform: $platform');
      
      await Supabase.instance.client
          .from('device_tokens')
          .upsert({
            'user_id': user.id,
            'device_token': token,
            'platform': platform,
            'is_active': true,
          }, onConflict: 'device_token');
      
      print('[NotificationService] ✅ Device token stored successfully');
    } catch (e) {
      print('[NotificationService] ❌ Error storing device token: $e');
      // Don't throw - token storage failure shouldn't break the app
    }
  }

  /// Remove device token when user logs out
  Future<void> removeDeviceToken() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Get current device token
      final deviceState = await OneSignal.User.pushSubscription.id;
      if (deviceState == null) return;

      // Mark token as inactive in database
      await Supabase.instance.client
          .from('device_tokens')
          .update({'is_active': false})
          .eq('user_id', user.id)
          .eq('device_token', deviceState);
      
      print('[NotificationService] ✅ Device token deactivated');
    } catch (e) {
      print('[NotificationService] ❌ Error removing device token: $e');
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

