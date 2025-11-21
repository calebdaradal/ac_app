import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_service.dart';
import 'package:ac_app/constants/transaction_constants.dart';

class YieldService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const double performanceFeeRate = 0.20; // 20%

  /// Fetch all investment vehicles
  static Future<List<InvestmentVehicle>> getAllVehicles() async {
    final response = await _supabase
        .from('investmentvehicles')
        .select('id, vehicle_name, desc, type')
        .order('vehicle_name', ascending: true);

    return (response as List).map((item) {
      return InvestmentVehicle(
        id: item['id'] as int,
        vehicleName: item['vehicle_name'] as String,
        description: item['desc'] as String?,
        type: item['type'] as String?,
      );
    }).toList();
  }

  /// Apply yield to all users in a vehicle
  static Future<YieldApplicationResult> applyYield({
    required int vehicleId,
    required double yieldValue,
    required String yieldType, // 'Amount' or 'Percentage'
    required DateTime appliedDate,
  }) async {
    final adminUid = UserProfileService().profile?.uid;
    if (adminUid == null) {
      throw Exception('User not authenticated');
    }

    print('[YieldService] Starting yield application...');
    print('[YieldService] Vehicle ID: $vehicleId');
    print('[YieldService] Yield Value: $yieldValue');
    print('[YieldService] Yield Type: $yieldType');
    print('[YieldService] Applied Date: $appliedDate');

    // Format applied_date for comparison (date only, no time)
    final appliedDateStr = appliedDate.toIso8601String().split('T')[0];

    // 1. Fetch all users subscribed to this vehicle
    final subscriptions = await _supabase
        .from('userinvestmentvehicle')
        .select('id, user_uid, current_balance')
        .eq('vehicle_id', vehicleId);

    if (subscriptions.isEmpty) {
      throw Exception('No subscriptions found for this vehicle');
    }

    print('[YieldService] Found ${subscriptions.length} subscriptions');

    // 2. Calculate eligible balance for each user based on deposits/withdrawals before yield date
    Map<String, double> eligibleBalances = {};
    double totalAum = 0;

    for (var sub in subscriptions) {
      final userUid = sub['user_uid'] as String;
      
      // Check if user account is active - skip disabled accounts
      final profileResponse = await _supabase
          .from('profiles')
          .select('is_active')
          .eq('id', userUid)
          .maybeSingle();
      
      final isActive = profileResponse?['is_active'] as bool? ?? true;
      if (isActive == false) {
        print('[YieldService] User $userUid: Account is disabled - skipping yield update');
        continue;
      }
      
      // Get all VERIFIED deposits for this user and vehicle up to yield date
      final deposits = await _supabase
          .from('usertransactions')
          .select('amount, applied_at')
          .eq('user_uid', userUid)
          .eq('vehicle_id', vehicleId)
          .eq('transaction_id', TransactionType.deposit)
          .eq('status', TransactionStatus.verified)
          .lte('applied_at', appliedDateStr);

      // Get all ISSUED withdrawals for this user and vehicle up to yield date
      final withdrawals = await _supabase
          .from('usertransactions')
          .select('amount, applied_at')
          .eq('user_uid', userUid)
          .eq('vehicle_id', vehicleId)
          .eq('transaction_id', TransactionType.withdrawal)
          .eq('status', TransactionStatus.issued)
          .lte('applied_at', appliedDateStr);

      // Calculate eligible balance: sum of deposits - sum of withdrawals (before yield date)
      double eligibleBalance = 0.0;
      
      // Sum verified deposits
      // Note: Amount stored in database is already after 2% management fee (see deposit_service.dart)
      // So we use the amount directly without applying the fee again
      for (var deposit in deposits) {
        final amount = (deposit['amount'] as num).toDouble();
        eligibleBalance += amount;
      }
      
      // Subtract issued withdrawals
      for (var withdrawal in withdrawals) {
        final amount = (withdrawal['amount'] as num).toDouble();
        eligibleBalance -= amount;
      }

      // Only include users with positive eligible balance
      if (eligibleBalance > 0) {
        eligibleBalances[userUid] = eligibleBalance;
        totalAum += eligibleBalance;
        
        print('[YieldService] User $userUid: Eligible Balance = ₱${eligibleBalance.toStringAsFixed(2)} (${deposits.length} deposits, ${withdrawals.length} withdrawals)');
      } else {
        print('[YieldService] User $userUid: Eligible Balance = ₱0.00 (skipped)');
      }
    }

    print('[YieldService] Total Eligible AUM: ₱${totalAum.toStringAsFixed(2)}');

    if (totalAum == 0) {
      throw Exception('Total eligible AUM is zero - no deposits eligible for this yield date');
    }

    // 3. Create yield record
    final yieldRecord = await _supabase
        .from('yields')
        .insert({
          'vehicle_id': vehicleId,
          'yield_amount': yieldValue,
          'yield_type': yieldType,
          'performance_fee_rate': performanceFeeRate,
          'total_aum': totalAum,
          'applied_date': appliedDateStr,
          'created_by': adminUid,
        })
        .select('id')
        .single();

    final yieldId = yieldRecord['id'] as int;
    print('[YieldService] Created yield record with ID: $yieldId');

    // 4. Calculate and apply yield to each user with eligible balance
    List<Map<String, dynamic>> distributions = [];
    int usersProcessed = 0;

    for (var sub in subscriptions) {
      final subId = sub['id'] as int;
      final userUid = sub['user_uid'] as String;
      
      // Skip users without eligible balance (disabled users are already filtered out in step 2)
      if (!eligibleBalances.containsKey(userUid)) {
        continue;
      }
      
      final eligibleBalance = eligibleBalances[userUid]!;

      // Calculate yield based on type
      double grossYield;

      if (yieldType == 'Amount') {
        // Formula: Y_gross_i = (B_i / ΣB) * Y_total
        // Use eligible balance instead of current balance
        grossYield = (eligibleBalance / totalAum) * yieldValue;
      } else {
        // yieldType == 'Percentage'
        // Formula: Y_gross_i = B_i * r
        // Use eligible balance instead of current balance
        final rate = yieldValue / 100; // Convert percentage to decimal
        grossYield = eligibleBalance * rate;
      }

      // Calculate performance fee: Y_perf_i = Y_gross_i * pf
      // For negative yields, performance fee is also negative (reduces the loss)
      // For positive yields, performance fee is positive (reduces the gain)
      final performanceFee = grossYield * performanceFeeRate;

      // Calculate net yield: Y_net_i = Y_gross_i - Y_perf_i
      // For negative yields: netYield = grossYield - (negative fee) = grossYield + abs(fee) (less negative)
      // For positive yields: netYield = grossYield - (positive fee) = grossYield - fee (less positive)
      final netYield = grossYield - performanceFee;

      // Get current balance
      final currentBalance = (sub['current_balance'] as num).toDouble();
      
      // Calculate new balance: Current Balance + Net Yield
      // Note: We add yield to current balance, not eligible balance
      // because eligible balance is just for calculation purposes
      final balanceAfter = currentBalance + netYield;
      
      print('[YieldService] User: $userUid');
      print('  Eligible Balance (for yield calc): ₱${eligibleBalance.toStringAsFixed(2)}');
      print('  Current Balance (before yield): ₱${currentBalance.toStringAsFixed(2)}');
      print('  Gross Yield: ₱${grossYield.toStringAsFixed(2)}');
      print('  Performance Fee: ₱${performanceFee.toStringAsFixed(2)}');
      print('  Net Yield: ₱${netYield.toStringAsFixed(2)}');
      print('  Balance After: ₱${balanceAfter.toStringAsFixed(2)}');

      // Store distribution record for batch insert
      distributions.add({
        'yield_id': yieldId,
        'user_uid': userUid,
        'vehicle_id': vehicleId,
        'balance_before': eligibleBalance, // Store eligible balance used for calculation
        'gross_yield': grossYield,
        'performance_fee': performanceFee,
        'net_yield': netYield,
        'balance_after': balanceAfter,
      });

      // Update user's balance only (total_yield and total_yield_percent removed from schema)
      await _supabase
          .from('userinvestmentvehicle')
          .update({
            'current_balance': balanceAfter,
          })
          .eq('id', subId);

      usersProcessed++;
    }

    // 5. Batch insert distribution records
    if (distributions.isEmpty) {
      print('[YieldService] ⚠️ WARNING: No distributions to insert (no users with eligible balance)');
    } else {
      try {
        final insertResponse = await _supabase
            .from('user_yield_distributions')
            .insert(distributions)
            .select();
        
        print('[YieldService] ✅ Successfully inserted ${insertResponse.length} distribution records');
        
        // Verify the insert
        if (insertResponse.length != distributions.length) {
          print('[YieldService] ⚠️ WARNING: Inserted ${insertResponse.length} but expected ${distributions.length}');
        }
      } catch (e) {
        print('[YieldService] ❌ ERROR inserting distributions: $e');
        rethrow; // Re-throw to fail the yield application
      }
    }

    print('[YieldService] Successfully processed $usersProcessed users');

    return YieldApplicationResult(
      yieldId: yieldId,
      usersAffected: usersProcessed,
      totalAum: totalAum,
      totalGrossYield: yieldType == 'Amount' ? yieldValue : totalAum * (yieldValue / 100),
      totalPerformanceFee: (yieldType == 'Amount' ? yieldValue : totalAum * (yieldValue / 100)) * performanceFeeRate,
    );
  }

  /// Apply personal yield to a specific user for a specific vehicle
  static Future<YieldApplicationResult> applyPersonalYield({
    required String userUid,
    required int vehicleId,
    required double yieldValue,
    required String yieldType, // 'Amount' or 'Percentage'
    required DateTime appliedDate,
  }) async {
    final adminUid = UserProfileService().profile?.uid;
    if (adminUid == null) {
      throw Exception('User not authenticated');
    }

    print('[YieldService] Starting personal yield application...');
    print('[YieldService] User UID: $userUid');
    print('[YieldService] Vehicle ID: $vehicleId');
    print('[YieldService] Yield Value: $yieldValue');
    print('[YieldService] Yield Type: $yieldType');
    print('[YieldService] Applied Date: $appliedDate');

    // Format applied_date for comparison (date only, no time)
    final appliedDateStr = appliedDate.toIso8601String().split('T')[0];

    // 1. Check if user is subscribed to this vehicle
    final subscriptionResponse = await _supabase
        .from('userinvestmentvehicle')
        .select('id, user_uid, current_balance')
        .eq('user_uid', userUid)
        .eq('vehicle_id', vehicleId)
        .maybeSingle();

    if (subscriptionResponse == null) {
      throw Exception('User is not subscribed to this vehicle');
    }

    final subId = subscriptionResponse['id'] as int;
    final currentBalance = (subscriptionResponse['current_balance'] as num).toDouble();

    print('[YieldService] Found subscription with ID: $subId');
    print('[YieldService] Current Balance: ₱${currentBalance.toStringAsFixed(2)}');

    // 2. Calculate eligible balance for this user based on deposits/withdrawals before yield date
    // Get all VERIFIED deposits for this user and vehicle up to yield date
    final deposits = await _supabase
        .from('usertransactions')
        .select('amount, applied_at')
        .eq('user_uid', userUid)
        .eq('vehicle_id', vehicleId)
        .eq('transaction_id', TransactionType.deposit)
        .eq('status', TransactionStatus.verified)
        .lte('applied_at', appliedDateStr);

    // Get all ISSUED withdrawals for this user and vehicle up to yield date
    final withdrawals = await _supabase
        .from('usertransactions')
        .select('amount, applied_at')
        .eq('user_uid', userUid)
        .eq('vehicle_id', vehicleId)
        .eq('transaction_id', TransactionType.withdrawal)
        .eq('status', TransactionStatus.issued)
        .lte('applied_at', appliedDateStr);

    // Calculate eligible balance: sum of deposits - sum of withdrawals (before yield date)
    double eligibleBalance = 0.0;
    
    // Sum verified deposits
    // Note: Amount stored in database is already after 2% management fee (see deposit_service.dart)
    // So we use the amount directly without applying the fee again
    for (var deposit in deposits) {
      final amount = (deposit['amount'] as num).toDouble();
      eligibleBalance += amount;
    }
    
    // Subtract issued withdrawals
    for (var withdrawal in withdrawals) {
      final amount = (withdrawal['amount'] as num).toDouble();
      eligibleBalance -= amount;
    }

    print('[YieldService] Eligible Balance: ₱${eligibleBalance.toStringAsFixed(2)} (${deposits.length} deposits, ${withdrawals.length} withdrawals)');

    if (eligibleBalance <= 0) {
      throw Exception('User has no eligible balance for this yield date');
    }

    // 3. Calculate yield based on type
    double grossYield;

    if (yieldType == 'Amount') {
      // For personal yield with Amount type, apply the full amount to this user
      grossYield = yieldValue;
    } else {
      // yieldType == 'Percentage'
      // Formula: Y_gross_i = B_i * r
      final rate = yieldValue / 100; // Convert percentage to decimal
      grossYield = eligibleBalance * rate;
    }

    // Calculate performance fee: Y_perf_i = Y_gross_i * pf
    final performanceFee = grossYield * performanceFeeRate;

    // Calculate net yield: Y_net_i = Y_gross_i - Y_perf_i
    final netYield = grossYield - performanceFee;

    // Calculate new balance: Current Balance + Net Yield
    final balanceAfter = currentBalance + netYield;
    
    print('[YieldService] User: $userUid');
    print('  Eligible Balance (for yield calc): ₱${eligibleBalance.toStringAsFixed(2)}');
    print('  Current Balance (before yield): ₱${currentBalance.toStringAsFixed(2)}');
    print('  Gross Yield: ₱${grossYield.toStringAsFixed(2)}');
    print('  Performance Fee: ₱${performanceFee.toStringAsFixed(2)}');
    print('  Net Yield: ₱${netYield.toStringAsFixed(2)}');
    print('  Balance After: ₱${balanceAfter.toStringAsFixed(2)}');

    // 4. Create yield record (use eligible balance as total_aum for personal yield)
    final yieldRecord = await _supabase
        .from('yields')
        .insert({
          'vehicle_id': vehicleId,
          'yield_amount': yieldValue,
          'yield_type': yieldType,
          'performance_fee_rate': performanceFeeRate,
          'total_aum': eligibleBalance, // For personal yield, this is just the user's balance
          'applied_date': appliedDateStr,
          'created_by': adminUid,
        })
        .select('id')
        .single();

    final yieldId = yieldRecord['id'] as int;
    print('[YieldService] Created yield record with ID: $yieldId');

    // 5. Create distribution record for this user
    await _supabase
        .from('user_yield_distributions')
        .insert({
          'yield_id': yieldId,
          'user_uid': userUid,
          'vehicle_id': vehicleId,
          'balance_before': eligibleBalance,
          'gross_yield': grossYield,
          'performance_fee': performanceFee,
          'net_yield': netYield,
          'balance_after': balanceAfter,
        });

    // 6. Update user's balance
    await _supabase
        .from('userinvestmentvehicle')
        .update({
          'current_balance': balanceAfter,
        })
        .eq('id', subId);

    print('[YieldService] Successfully applied personal yield to user $userUid');

    return YieldApplicationResult(
      yieldId: yieldId,
      usersAffected: 1,
      totalAum: eligibleBalance,
      totalGrossYield: grossYield,
      totalPerformanceFee: performanceFee,
    );
  }

  /// Get all vehicles a user is subscribed to
  static Future<List<InvestmentVehicle>> getUserVehicles(String userUid) async {
    final subscriptions = await _supabase
        .from('userinvestmentvehicle')
        .select('vehicle_id, investmentvehicles!inner(id, vehicle_name, desc, type)')
        .eq('user_uid', userUid);

    return (subscriptions as List).map((sub) {
      final vehicle = sub['investmentvehicles'] as Map<String, dynamic>;
      return InvestmentVehicle(
        id: vehicle['id'] as int,
        vehicleName: vehicle['vehicle_name'] as String,
        description: vehicle['desc'] as String?,
        type: vehicle['type'] as String?,
      );
    }).toList();
  }

  /// Get yield history for a vehicle
  static Future<List<YieldRecord>> getYieldHistory(int vehicleId) async {
    final response = await _supabase
        .from('yields')
        .select('id, yield_amount, yield_type, total_aum, applied_date')
        .eq('vehicle_id', vehicleId)
        .order('applied_date', ascending: false);

    return (response as List).map((item) {
      return YieldRecord(
        id: item['id'] as int,
        yieldAmount: (item['yield_amount'] as num).toDouble(),
        yieldType: item['yield_type'] as String,
        totalAum: (item['total_aum'] as num).toDouble(),
        appliedDate: DateTime.parse(item['applied_date'] as String),
      );
    }).toList();
  }
}

/// Investment Vehicle model
class InvestmentVehicle {
  final int id;
  final String vehicleName;
  final String? description;
  final String? type;

  InvestmentVehicle({
    required this.id,
    required this.vehicleName,
    this.description,
    this.type,
  });
}

/// Yield Application Result
class YieldApplicationResult {
  final int yieldId;
  final int usersAffected;
  final double totalAum;
  final double totalGrossYield;
  final double totalPerformanceFee;

  YieldApplicationResult({
    required this.yieldId,
    required this.usersAffected,
    required this.totalAum,
    required this.totalGrossYield,
    required this.totalPerformanceFee,
  });
}

/// Yield Record model
class YieldRecord {
  final int id;
  final double yieldAmount;
  final String yieldType;
  final double totalAum;
  final DateTime appliedDate;

  YieldRecord({
    required this.id,
    required this.yieldAmount,
    required this.yieldType,
    required this.totalAum,
    required this.appliedDate,
  });
}

