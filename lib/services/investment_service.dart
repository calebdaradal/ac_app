import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_service.dart';

/// Service to manage investment vehicle subscriptions and operations
class InvestmentService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all user's subscriptions across all vehicles
  /// Returns aggregated totals for the home screen
  static Future<AggregatedSubscriptions> getAllSubscriptions() async {
    final uid = UserProfileService().profile?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    print('[InvestmentService] Fetching all subscriptions for user: $uid');
    print('[InvestmentService] User UID type: ${uid.runtimeType}, value: "$uid"');
    
    // Check current Supabase auth user
    final authUser = _supabase.auth.currentUser;
    print('[InvestmentService] Supabase auth user ID: ${authUser?.id}');
    print('[InvestmentService] Profile UID matches auth UID: ${uid == authUser?.id}');

    // Fetch all subscriptions for this user
    final subscriptions = await _supabase
        .from('userinvestmentvehicle')
        .select('id, user_uid, vehicle_id, total_contrib, current_balance')
        .eq('user_uid', uid);

    print('[InvestmentService] Query successful. Found ${subscriptions.length} subscriptions');
    
    if (subscriptions.isNotEmpty) {
      print('[InvestmentService] First subscription: ${subscriptions[0]}');
      print('[InvestmentService] First subscription user_uid: "${subscriptions[0]['user_uid']}"');
    } else {
      print('[InvestmentService] No subscriptions found for user: $uid');
      print('[InvestmentService] === DEBUGGING: Checking database directly ===');
      
      // Try to see ALL subscriptions (will be blocked by RLS if policies are correct)
      try {
        final allSubs = await _supabase
            .from('userinvestmentvehicle')
            .select('id, user_uid');
        print('[InvestmentService] ⚠️ RLS IS NOT WORKING! Can see ${allSubs.length} subscriptions from other users');
        if (allSubs.isNotEmpty) {
          print('[InvestmentService] Sample user_uids in DB: ${allSubs.map((s) => s['user_uid']).toList()}');
        }
      } catch (e) {
        print('[InvestmentService] ✅ RLS is working (cannot see other users\' subscriptions): $e');
      }
      
      // Check if there's a subscription for the auth user ID
      if (authUser?.id != null && authUser!.id != uid) {
        print('[InvestmentService] Trying query with auth UID instead of profile UID...');
        try {
          final authSubs = await _supabase
              .from('userinvestmentvehicle')
              .select('id, user_uid, vehicle_id, total_contrib, current_balance')
              .eq('user_uid', authUser.id);
          print('[InvestmentService] Found ${authSubs.length} subscriptions for auth UID: ${authUser.id}');
        } catch (e) {
          print('[InvestmentService] Error querying with auth UID: $e');
        }
      }
    }

    if (subscriptions.isEmpty) {
      return AggregatedSubscriptions(
        totalContributions: 0.0,
        currentBalance: 0.0,
        totalYield: 0.0,
        yieldPercentage: 0.0,
      );
    }

    // Sum up all values across all vehicles
    double totalContrib = 0.0;
    double currentBalance = 0.0;
    double totalYield = 0.0;
    bool hasAnyYieldDistributions = false;

    // Check which users have been affected by yield updates (have yield distributions)
    for (var sub in subscriptions) {
      final userUid = sub['user_uid'] as String;
      final vehicleId = sub['vehicle_id'] as int;
      
      // Check if user has yield distributions (affected by admin yield updates)
      final hasYieldDistributions = await _supabase
          .from('user_yield_distributions')
          .select('id')
          .eq('user_uid', userUid)
          .eq('vehicle_id', vehicleId)
          .limit(1)
          .maybeSingle();

      final contrib = (sub['total_contrib'] as num?)?.toDouble() ?? 0.0;
      final balance = (sub['current_balance'] as num?)?.toDouble() ?? 0.0;
      
      totalContrib += contrib;
      currentBalance += balance;
      
      // Only calculate yield if user has been affected by yield updates
      if (hasYieldDistributions != null) {
        hasAnyYieldDistributions = true;
        totalYield += (balance - contrib);
      }
    }

    // Calculate yield percentage from aggregated totals using formula: ((current_balance - total_contrib) / total_contrib) * 100
    // Only if at least one user has been affected by yield updates
    double yieldPercentage = 0.0;
    if (hasAnyYieldDistributions && totalContrib > 0) {
      yieldPercentage = ((currentBalance - totalContrib) / totalContrib) * 100;
    }

    return AggregatedSubscriptions(
      totalContributions: totalContrib,
      currentBalance: currentBalance,
      totalYield: totalYield, // Only sum for users affected by yield updates
      yieldPercentage: yieldPercentage, // Calculate from aggregated totals using formula
    );
  }

  /// Check if user is subscribed to a vehicle
  /// Returns the subscription data or null if not subscribed
  static Future<UserVehicleSubscription?> checkSubscription(String vehicleName) async {
    final uid = UserProfileService().profile?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    print('[InvestmentService] Checking subscription for: $vehicleName, user: $uid');

    // First get the vehicle ID from vehicle name
    // Note: Supabase converts table names to lowercase unless quoted
    final vehicleResponse = await _supabase
        .from('investmentvehicles')  // Try lowercase
        .select('id, vehicle_name, desc, type')
        .ilike('vehicle_name', vehicleName)
        .maybeSingle();

    print('[InvestmentService] Vehicle response: $vehicleResponse');

    if (vehicleResponse == null) {
      throw Exception('Investment vehicle not found: $vehicleName. Check: 1) Table exists, 2) vehicle_name matches');
    }

    final vehicleId = vehicleResponse['id'] as int;

    // Check if user has a subscription to this vehicle
    print('[InvestmentService] Querying subscription for vehicle_id: $vehicleId, user_uid: $uid');
    
    final subscriptionResponse = await _supabase
        .from('userinvestmentvehicle')  // Lowercase to match PostgreSQL
        .select('id, vehicle_id, registered_at, total_contrib, current_balance')
        .eq('user_uid', uid)
        .eq('vehicle_id', vehicleId)
        .maybeSingle();
    
    print('[InvestmentService] Subscription query response: $subscriptionResponse');
    
    if (subscriptionResponse == null) {
      print('[InvestmentService] No subscription found for vehicle_id: $vehicleId');
    } else {
      print('[InvestmentService] Subscription found: ${subscriptionResponse['id']}');
    }

    // Check if user has been affected by yield updates (has yield distributions)
    final hasYieldDistributions = await _supabase
        .from('user_yield_distributions')
        .select('id')
        .eq('user_uid', uid)
        .eq('vehicle_id', vehicleId)
        .limit(1)
        .maybeSingle();

    if (subscriptionResponse == null) {
      // User is not subscribed, return vehicle info with null subscription
      return UserVehicleSubscription(
        vehicleId: vehicleId,
        vehicleName: vehicleResponse['vehicle_name'] as String,
        isSubscribed: false,
        totalContributions: 0.0,
        currentBalance: 0.0,
        totalYield: 0.0,
        hasYieldDistributions: false,
      );
    }

    // User is subscribed
    return UserVehicleSubscription(
      vehicleId: vehicleId,
      vehicleName: vehicleResponse['vehicle_name'] as String,
      subscriptionId: subscriptionResponse['id'] as int,
      isSubscribed: true,
      totalContributions: (subscriptionResponse['total_contrib'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (subscriptionResponse['current_balance'] as num?)?.toDouble() ?? 0.0,
      totalYield: 0.0, // Not used - will be calculated
      hasYieldDistributions: hasYieldDistributions != null,
      registeredAt: subscriptionResponse['registered_at'] != null
          ? DateTime.parse(subscriptionResponse['registered_at'] as String)
          : null,
    );
  }

  /// Create first deposit and subscribe user to vehicle
  /// Applies 2% fee to the deposit
  /// 
  /// [userUid] - Optional. Used by admins to process deposits for other users.
  ///             If not provided, uses the current authenticated user's UID.
  static Future<DepositResult> createDeposit({
    required int vehicleId,
    required double amount,
    String? userUid, // Optional: for admin to process deposits for other users
  }) async {
    // Use provided userUid (for admin) or current user's UID (for self-deposits)
    final uid = userUid ?? UserProfileService().profile?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    print('[InvestmentService] Creating deposit for user: $uid (admin processing: ${userUid != null})');

    // Calculate 2% fee
    const feePercentage = 0.02;
    final feeAmount = amount * feePercentage;
    final amountAfterFee = amount - feeAmount;

    // Check if user already has a subscription
    final existingSubscription = await _supabase
        .from('userinvestmentvehicle')
        .select('id, total_contrib, current_balance')
        .eq('user_uid', uid)
        .eq('vehicle_id', vehicleId)
        .maybeSingle();

    if (existingSubscription != null) {
      // User already subscribed, add to existing amounts
      final newTotalContrib = (existingSubscription['total_contrib'] as num).toDouble() + amount;
      final newCurrentBalance = (existingSubscription['current_balance'] as num).toDouble() + amountAfterFee;

      await _supabase
          .from('userinvestmentvehicle')
          .update({
            'total_contrib': newTotalContrib,
            'current_balance': newCurrentBalance,
          })
          .eq('id', existingSubscription['id']);

      return DepositResult(
        success: true,
        totalContributions: newTotalContrib,
        currentBalance: newCurrentBalance,
        feeAmount: feeAmount,
        isNewSubscription: false,
      );
    } else {
      // Create new subscription
      await _supabase.from('userinvestmentvehicle').insert({
        'user_uid': uid,
        'vehicle_id': vehicleId,
        'registered_at': DateTime.now().toIso8601String(),
        'total_contrib': amount,
        'current_balance': amountAfterFee,
      });

      return DepositResult(
        success: true,
        totalContributions: amount,
        currentBalance: amountAfterFee,
        feeAmount: feeAmount,
        isNewSubscription: true,
      );
    }
  }

  /// Helper to map frontend identifiers to database vehicle names
  static String _getVehicleName(String identifier) {
    switch (identifier.toUpperCase()) {
      case 'AFF':
        return 'AFF';
      case 'STK':
        return 'SP'; // STK maps to SP (Stock Portfolio) in database
      default:
        return identifier;
    }
  }

  /// Get vehicle summary including latest yield update
  static Future<VehicleSummary?> getVehicleSummary(String vehicleIdentifier) async {
    final uid = UserProfileService().profile?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    print('[InvestmentService] === Fetching vehicle summary for: $vehicleIdentifier ===');
    print('[InvestmentService] User UID: $uid');

    try {
      // Map frontend identifier to database vehicle name
      final vehicleName = _getVehicleName(vehicleIdentifier);
      print('[InvestmentService] 🔍 Searching for vehicle: $vehicleIdentifier → $vehicleName');
      
      final vehicle = await _supabase
          .from('investmentvehicles')
          .select('id, vehicle_name, type')
          .eq('vehicle_name', vehicleName)
          .maybeSingle();

      if (vehicle == null) {
        print('[InvestmentService] ❌ Vehicle not found: $vehicleName');
        return null;
      }

      final vehicleId = vehicle['id'] as int;
      print('[InvestmentService] ✅ Found vehicle: ${vehicle['vehicle_name']} (ID: $vehicleId)');

      // Get latest yield distribution for this user and vehicle (using applied_date from yields)
      // Order by applied_date descending to get most recent yield
      final latestYield = await _supabase
          .from('user_yield_distributions')
          .select('gross_yield, balance_before, yield_id, yields!inner(applied_date, created_at)')
          .eq('user_uid', uid)
          .eq('vehicle_id', vehicleId)
          .order('yields(applied_date)', ascending: false)
          .limit(1)
          .maybeSingle();

      print('[InvestmentService] Latest yield distribution: $latestYield');

      double latestYieldPercent = 0.0;
      DateTime? lastUpdated;

      if (latestYield != null) {
        final grossYield = (latestYield['gross_yield'] as num).toDouble();
        final balanceBefore = (latestYield['balance_before'] as num).toDouble();
        // Get applied_date from nested yields object
        final yieldsData = latestYield['yields'] as Map<String, dynamic>;
        lastUpdated = DateTime.parse(yieldsData['applied_date'] as String);
        
        if (balanceBefore > 0) {
          latestYieldPercent = (grossYield / balanceBefore) * 100;
        }
        
        print('[InvestmentService] ✅ Latest yield %: $latestYieldPercent, Last updated: $lastUpdated');
      } else {
        print('[InvestmentService] ⚠️ No yield distributions found');
        print('[InvestmentService] 🔍 This could be an RLS issue - check if "Users can view their related yields" policy is applied');
      }

      // Calculate totalYield from current balance and total contributions
      // Get subscription to calculate totalYield = currentBalance - totalContrib
      final subscription = await _supabase
          .from('userinvestmentvehicle')
          .select('total_contrib, current_balance')
          .eq('user_uid', uid)
          .eq('vehicle_id', vehicleId)
          .maybeSingle();
      
      double totalYield = 0.0;
      if (subscription != null) {
        final totalContrib = (subscription['total_contrib'] as num?)?.toDouble() ?? 0.0;
        final currentBalance = (subscription['current_balance'] as num?)?.toDouble() ?? 0.0;
        totalYield = currentBalance - totalContrib;
      }

      print('[InvestmentService] === Summary Result ===');
      print('[InvestmentService] Total Yield: $totalYield');
      print('[InvestmentService] Latest Yield %: $latestYieldPercent');
      print('[InvestmentService] Last Updated: $lastUpdated');

      return VehicleSummary(
        totalYield: totalYield,
        latestYieldPercent: latestYieldPercent,
        lastUpdated: lastUpdated,
      );
    } catch (e, stackTrace) {
      print('[InvestmentService] ❌ ERROR fetching vehicle summary: $e');
      print('[InvestmentService] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

/// Model for user's vehicle subscription data
class UserVehicleSubscription {
  final int vehicleId;
  final String vehicleName;
  final int? subscriptionId;
  final bool isSubscribed;
  final double totalContributions;
  final double currentBalance;
  final double totalYield;
  final bool hasYieldDistributions; // Whether user has been affected by admin yield updates
  final DateTime? registeredAt;

  UserVehicleSubscription({
    required this.vehicleId,
    required this.vehicleName,
    this.subscriptionId,
    required this.isSubscribed,
    required this.totalContributions,
    required this.currentBalance,
    required this.totalYield,
    bool? hasYieldDistributions,
    this.registeredAt,
  }) : hasYieldDistributions = hasYieldDistributions ?? false;

  // Calculate yield percentage ONLY if user has been affected by yield updates
  // Use formula: ((current_balance - total_contrib) / total_contrib) * 100
  double get yieldPercentage {
    if (!hasYieldDistributions) {
      return 0.0; // Not affected by yield updates, return 0
    }
    if (totalContributions > 0) {
      return ((currentBalance - totalContributions) / totalContributions) * 100;
    }
    return 0.0;
  }
  
  // Calculate yield amount ONLY if user has been affected by yield updates
  double get calculatedYield {
    if (!hasYieldDistributions) {
      return 0.0; // Not affected by yield updates, return 0
    }
    return currentBalance - totalContributions;
  }
}

/// Aggregated subscriptions across all vehicles
class AggregatedSubscriptions {
  final double totalContributions;
  final double currentBalance;
  final double totalYield;
  final double yieldPercentage;

  AggregatedSubscriptions({
    required this.totalContributions,
    required this.currentBalance,
    required this.totalYield,
    required this.yieldPercentage,
  });
}

/// Result of a deposit operation
class DepositResult {
  final bool success;
  final double totalContributions;
  final double currentBalance;
  final double feeAmount;
  final bool isNewSubscription;

  DepositResult({
    required this.success,
    required this.totalContributions,
    required this.currentBalance,
    required this.feeAmount,
    required this.isNewSubscription,
  });
}

/// Vehicle summary for home screen card
class VehicleSummary {
  final double totalYield;
  final double latestYieldPercent;
  final DateTime? lastUpdated;

  VehicleSummary({
    required this.totalYield,
    required this.latestYieldPercent,
    this.lastUpdated,
  });
}


