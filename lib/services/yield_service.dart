import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_service.dart';

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

    // 1. Fetch all users subscribed to this vehicle with current_balance > 0
    final subscriptions = await _supabase
        .from('userinvestmentvehicle')
        .select('id, user_uid, current_balance, total_yield, total_yield_percent')
        .eq('vehicle_id', vehicleId)
        .gt('current_balance', 0);

    if (subscriptions.isEmpty) {
      throw Exception('No active subscriptions found for this vehicle');
    }

    print('[YieldService] Found ${subscriptions.length} active subscriptions');

    // 2. Calculate total AUM (sum of all balances)
    double totalAum = 0;
    for (var sub in subscriptions) {
      totalAum += (sub['current_balance'] as num).toDouble();
    }

    print('[YieldService] Total AUM: ₱${totalAum.toStringAsFixed(2)}');

    if (totalAum == 0) {
      throw Exception('Total AUM is zero');
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
          'applied_date': appliedDate.toIso8601String().split('T')[0],
          'created_by': adminUid,
        })
        .select('id')
        .single();

    final yieldId = yieldRecord['id'] as int;
    print('[YieldService] Created yield record with ID: $yieldId');

    // 4. Calculate and apply yield to each user
    List<Map<String, dynamic>> distributions = [];
    int usersProcessed = 0;

    for (var sub in subscriptions) {
      final subId = sub['id'] as int;
      final userUid = sub['user_uid'] as String;
      final balanceBefore = (sub['current_balance'] as num).toDouble();
      final currentTotalYield = (sub['total_yield'] as num?)?.toDouble() ?? 0.0;
      final currentTotalYieldPercent = (sub['total_yield_percent'] as num?)?.toDouble() ?? 0.0;

      // Calculate yield based on type
      double grossYield;
      double yieldPercent;

      if (yieldType == 'Amount') {
        // Formula: Y_gross_i = (B_i / ΣB) * Y_total
        grossYield = (balanceBefore / totalAum) * yieldValue;
        yieldPercent = (grossYield / balanceBefore) * 100;
      } else {
        // yieldType == 'Percentage'
        // Formula: Y_gross_i = B_i * r
        final rate = yieldValue / 100; // Convert percentage to decimal
        grossYield = balanceBefore * rate;
        yieldPercent = yieldValue;
      }

      // Calculate performance fee: Y_perf_i = Y_gross_i * pf
      final performanceFee = grossYield * performanceFeeRate;

      // Calculate net yield: Y_net_i = Y_gross_i - Y_perf_i
      final netYield = grossYield - performanceFee;

      // Calculate new balance: NewBalance_i = B_i + Y_net_i
      final balanceAfter = balanceBefore + netYield;

      // Update totals
      final newTotalYield = currentTotalYield + netYield;
      final newTotalYieldPercent = currentTotalYieldPercent + yieldPercent;

      print('[YieldService] User: $userUid');
      print('  Balance Before: ₱${balanceBefore.toStringAsFixed(2)}');
      print('  Gross Yield: ₱${grossYield.toStringAsFixed(2)}');
      print('  Performance Fee: ₱${performanceFee.toStringAsFixed(2)}');
      print('  Net Yield: ₱${netYield.toStringAsFixed(2)}');
      print('  Balance After: ₱${balanceAfter.toStringAsFixed(2)}');

      // Store distribution record for batch insert
      distributions.add({
        'yield_id': yieldId,
        'user_uid': userUid,
        'vehicle_id': vehicleId,
        'balance_before': balanceBefore,
        'gross_yield': grossYield,
        'performance_fee': performanceFee,
        'net_yield': netYield,
        'balance_after': balanceAfter,
      });

      // Update user's balance and yield totals
      await _supabase
          .from('userinvestmentvehicle')
          .update({
            'current_balance': balanceAfter,
            'total_yield': newTotalYield,
            'total_yield_percent': newTotalYieldPercent,
          })
          .eq('id', subId);

      usersProcessed++;
    }

    // 5. Batch insert distribution records
    await _supabase.from('user_yield_distributions').insert(distributions);

    print('[YieldService] Successfully processed $usersProcessed users');

    return YieldApplicationResult(
      yieldId: yieldId,
      usersAffected: usersProcessed,
      totalAum: totalAum,
      totalGrossYield: yieldType == 'Amount' ? yieldValue : totalAum * (yieldValue / 100),
      totalPerformanceFee: (yieldType == 'Amount' ? yieldValue : totalAum * (yieldValue / 100)) * performanceFeeRate,
    );
  }

  /// Get yield history for a vehicle
  static Future<List<YieldRecord>> getYieldHistory(int vehicleId) async {
    final response = await _supabase
        .from('yields')
        .select('id, yield_amount, yield_type, total_aum, applied_date, created_at')
        .eq('vehicle_id', vehicleId)
        .order('applied_date', ascending: false);

    return (response as List).map((item) {
      return YieldRecord(
        id: item['id'] as int,
        yieldAmount: (item['yield_amount'] as num).toDouble(),
        yieldType: item['yield_type'] as String,
        totalAum: (item['total_aum'] as num).toDouble(),
        appliedDate: DateTime.parse(item['applied_date'] as String),
        createdAt: DateTime.parse(item['created_at'] as String).toUtc(),
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
  final DateTime createdAt;

  YieldRecord({
    required this.id,
    required this.yieldAmount,
    required this.yieldType,
    required this.totalAum,
    required this.appliedDate,
    required this.createdAt,
  });
}

