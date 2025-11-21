import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ac_app/constants/transaction_constants.dart';
import 'package:ac_app/services/user_profile_service.dart';
import 'package:ac_app/utils/redemption_dates.dart';

class WithdrawalService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all user profiles that have contributions > 0 for admin to select from
  static Future<List<UserProfile>> getUsersWithContributions() async {
    // Get all unique user_uids from userinvestmentvehicle where total_contrib > 0
    final vehicleResponse = await _supabase
        .from('userinvestmentvehicle')
        .select('user_uid')
        .gt('total_contrib', 0);

    if (vehicleResponse.isEmpty) {
      return [];
    }

    // Extract unique user UIDs
    final userUids = (vehicleResponse as List)
        .map((item) => item['user_uid'] as String)
        .toSet()
        .toList();

    // Get user profiles for these UIDs
    // Build query with multiple OR conditions since Supabase doesn't have .in_ method
    var query = _supabase
        .from('profiles')
        .select('id, first_name, last_name, email');
    
    // Filter by user UIDs using OR conditions
    if (userUids.isNotEmpty) {
      query = query.or(userUids.map((uid) => 'id.eq.$uid').join(','));
    }
    
    final profilesResponse = await query.order('first_name', ascending: true);

    return (profilesResponse as List).map((item) {
      return UserProfile(
        uid: item['id'] as String,
        firstName: item['first_name'] as String?,
        lastName: item['last_name'] as String?,
        email: item['email'] as String? ?? '',
        avatarUrl: null,
        isAdmin: false,
      );
    }).toList();
  }

  /// Get current balance for a user and vehicle
  static Future<double> getCurrentBalance({
    required String userUid,
    required int vehicleId,
  }) async {
    final response = await _supabase
        .from('userinvestmentvehicle')
        .select('current_balance')
        .eq('user_uid', userUid)
        .eq('vehicle_id', vehicleId)
        .maybeSingle();

    if (response == null) {
      return 0.0;
    }

    return ((response['current_balance'] as num?)?.toDouble() ?? 0.0);
  }

  /// Apply withdrawal manually for a specific user
  /// Applies 5% fee if withdrawal > 33.33% of current balance
  /// Resets yield fields and updates balances
  static Future<void> applyWithdrawal({
    required String userUid,
    required int vehicleId,
    required double amount,
    required DateTime appliedDate,
  }) async {
    print('[WithdrawalService] Applying withdrawal...');
    print('[WithdrawalService] User UID: $userUid');
    print('[WithdrawalService] Vehicle ID: $vehicleId');
    print('[WithdrawalService] Amount: $amount');
    print('[WithdrawalService] Applied Date: $appliedDate');

    // Round withdrawal amount to 2 decimal places
    final withdrawalAmountRounded = (amount * 100).round() / 100.0;

    // Get current balance
    final currentBalance = await getCurrentBalance(
      userUid: userUid,
      vehicleId: vehicleId,
    );

    if (currentBalance <= 0) {
      throw Exception('User has no balance for this vehicle');
    }

    if (withdrawalAmountRounded > currentBalance) {
      throw Exception('Insufficient balance. Available: $currentBalance, Requested: $withdrawalAmountRounded');
    }

    // Check if applied date is a redemption date
    final isRedemptionDate = RedemptionDates.isRedemptionDate(appliedDate);
    
    // Calculate 33.33% threshold (using 1/3 for precision)
    final threshold = currentBalance / 3.0;
    
    // TWO PENALTIES (applied sequentially):
    // 1. Redemption penalty (5%): Reduces withdrawal amount by 5%
    // 2. Gate penalty (5%): Applied to the reduced amount if threshold is met
    double withdrawalAfterPenalties = withdrawalAmountRounded;
    double totalFee = 0.0;
    
    // STEP 1: Apply redemption penalty (5% on NON-redemption dates)
    // This reduces the withdrawal amount by 5%
    if (!isRedemptionDate) {
      final redemptionPenalty = withdrawalAmountRounded * 0.05;
      withdrawalAfterPenalties = withdrawalAmountRounded - redemptionPenalty;
      totalFee += redemptionPenalty;
      print('[WithdrawalService] Applied redemption penalty (5%): $redemptionPenalty');
      print('[WithdrawalService] Withdrawal after redemption penalty: $withdrawalAfterPenalties');
    }
    
    // STEP 2: Check if original withdrawal amount >= 33.33% of balance
    // If yes, apply gate penalty (5%) to the NEW withdrawal amount (after redemption penalty)
    if (withdrawalAmountRounded >= threshold) {
      final gatePenalty = withdrawalAfterPenalties * 0.05;
      withdrawalAfterPenalties = withdrawalAfterPenalties - gatePenalty;
      totalFee += gatePenalty;
      print('[WithdrawalService] Applied gate penalty (5%): $gatePenalty');
      print('[WithdrawalService] Final withdrawal amount: $withdrawalAfterPenalties');
      print('[WithdrawalService] Original withdrawal: $withdrawalAmountRounded, Threshold: $threshold, Percentage: ${(withdrawalAmountRounded / currentBalance * 100).toStringAsFixed(2)}%');
    } else {
      print('[WithdrawalService] No gate penalty - Original withdrawal: $withdrawalAmountRounded, Threshold: $threshold, Percentage: ${(withdrawalAmountRounded / currentBalance * 100).toStringAsFixed(2)}%');
    }
    
    // Round fee to 2 decimal places
    final feeAmountRounded = (totalFee * 100).round() / 100.0;
    final finalWithdrawRounded = (withdrawalAfterPenalties * 100).round() / 100.0;
    
    // Total deduction from balance is still the original withdrawal amount
    // But the actual amount user receives is reduced by penalties
    final totalDeductionRounded = withdrawalAmountRounded;

    // Check if withdrawal exceeds balance
    if (totalDeductionRounded > currentBalance) {
      throw Exception('Insufficient balance. Available: $currentBalance, Required: $totalDeductionRounded');
    }

    // Format applied_date for database (date only, no time)
    final appliedDateStr = appliedDate.toIso8601String().split('T')[0];

    // Get existing subscription
    final existingSubscription = await _supabase
        .from('userinvestmentvehicle')
        .select('id, current_balance, total_contrib')
        .eq('user_uid', userUid)
        .eq('vehicle_id', vehicleId)
        .maybeSingle();

    if (existingSubscription == null) {
      throw Exception('User investment vehicle not found');
    }

    // Calculate new balance after withdrawal (deduct original withdrawal amount)
    final newCurrentBalance = currentBalance - totalDeductionRounded;
    final newCurrentBalanceRounded = (newCurrentBalance * 100).round() / 100.0;

    // Set total_contrib to equal new current_balance (this resets yield to 0 since yield = current_balance - total_contrib)
    final newTotalContribRounded = (newCurrentBalanceRounded * 100).round() / 100.0;

    // Update userinvestmentvehicle: subtract withdrawal, set total_contrib = current_balance (resets yield to 0)
    await _supabase
        .from('userinvestmentvehicle')
        .update({
          'current_balance': newCurrentBalanceRounded,
          'total_contrib': newTotalContribRounded, // Set to equal current_balance (yield becomes 0)
        })
        .eq('id', existingSubscription['id']);

    // Insert into usertransactions table with total deduction (withdrawal + fee)
    await _supabase
        .from('usertransactions')
        .insert({
          'user_uid': userUid,
          'transaction_id': TransactionType.withdrawal, // Withdrawal = 1
          'amount': totalDeductionRounded, // Store total deduction (withdrawal + fee)
          'status': TransactionStatus.issued, // Set as issued since admin is applying it
          'vehicle_id': vehicleId,
          'applied_at': appliedDateStr,
          'bank_detail': null, // No bank detail for manual admin withdrawals
          'ref_number': null, // No reference number for manual admin withdrawals
        });

    print('[WithdrawalService] Withdrawal applied successfully');
    print('[WithdrawalService] Applied date: $appliedDate (Redemption date: $isRedemptionDate)');
    print('[WithdrawalService] Original withdrawal amount: $withdrawalAmountRounded');
    print('[WithdrawalService] Total fees deducted: $feeAmountRounded');
    print('[WithdrawalService] Final withdrawal amount (what user receives): $finalWithdrawRounded');
    print('[WithdrawalService] Total deduction from balance: $totalDeductionRounded');
    print('[WithdrawalService] New balance: $newCurrentBalanceRounded');
  }
}

