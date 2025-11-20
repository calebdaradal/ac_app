import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ac_app/constants/transaction_constants.dart';
import 'package:ac_app/services/user_profile_service.dart';

class DepositService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all user profiles for admin to select from
  static Future<List<UserProfile>> getAllUsers() async {
    final response = await _supabase
        .from('profiles')
        .select('id, first_name, last_name, email, avatar_url, is_active')
        .order('first_name', ascending: true);

    return (response as List).map((item) {
      return UserProfile(
        uid: item['id'] as String,
        firstName: item['first_name'] as String?,
        lastName: item['last_name'] as String?,
        email: item['email'] as String? ?? '',
        avatarUrl: item['avatar_url'] as String?,
        isAdmin: false,
        isActive: item['is_active'] as bool? ?? true,
      );
    }).toList();
  }

  /// Apply deposit manually for a specific user
  /// Applies 2% deduction and updates userinvestmentvehicle table
  static Future<void> applyDeposit({
    required String userUid,
    required int vehicleId,
    required double amount,
    required DateTime appliedDate,
  }) async {
    print('[DepositService] Applying deposit...');
    print('[DepositService] User UID: $userUid');
    print('[DepositService] Vehicle ID: $vehicleId');
    print('[DepositService] Amount: $amount');
    print('[DepositService] Applied Date: $appliedDate');

    // Round original amount to 2 decimal places
    final originalAmountRounded = (amount * 100).round() / 100.0;

    // Apply 2% fee reduction
    const feePercentage = 0.02;
    final amountAfterFee = originalAmountRounded * (1 - feePercentage);
    // Round to 2 decimal places
    final amountAfterFeeRounded = (amountAfterFee * 100).round() / 100.0;

    // Format applied_date for database (date only, no time)
    final appliedDateStr = appliedDate.toIso8601String().split('T')[0];

    // Insert into usertransactions table with deducted amount
    await _supabase
        .from('usertransactions')
        .insert({
          'user_uid': userUid,
          'transaction_id': TransactionType.deposit,
          'amount': amountAfterFeeRounded, // Store deducted amount
          'status': TransactionStatus.verified, // Set as verified since admin is applying it
          'vehicle_id': vehicleId,
          'applied_at': appliedDateStr,
          'bank_detail': null, // No bank detail for manual admin deposits
          'ref_number': null, // No reference number for manual admin deposits
        });

    // Check if user already has a subscription for this vehicle
    final existingSubscription = await _supabase
        .from('userinvestmentvehicle')
        .select('id, total_contrib, current_balance')
        .eq('user_uid', userUid)
        .eq('vehicle_id', vehicleId)
        .maybeSingle();

    if (existingSubscription != null) {
      // User already subscribed, add to existing amounts
      final newTotalContrib = (existingSubscription['total_contrib'] as num).toDouble() + originalAmountRounded;
      final newCurrentBalance = (existingSubscription['current_balance'] as num).toDouble() + amountAfterFeeRounded;
      
      // Round to 2 decimal places before saving
      final newTotalContribRounded = (newTotalContrib * 100).round() / 100.0;
      final newCurrentBalanceRounded = (newCurrentBalance * 100).round() / 100.0;

      await _supabase
          .from('userinvestmentvehicle')
          .update({
            'total_contrib': newTotalContribRounded,
            'current_balance': newCurrentBalanceRounded,
          })
          .eq('id', existingSubscription['id']);
    } else {
      // Create new subscription
      // Round to 2 decimal places before saving
      final totalContribRounded = (originalAmountRounded * 100).round() / 100.0;
      final currentBalanceRounded = (amountAfterFeeRounded * 100).round() / 100.0;
      
      await _supabase.from('userinvestmentvehicle').insert({
        'user_uid': userUid,
        'vehicle_id': vehicleId,
        'registered_at': appliedDateStr, // Use applied date
        'total_contrib': totalContribRounded, // Original amount
        'current_balance': currentBalanceRounded, // Deducted amount
      });
    }

    print('[DepositService] Deposit applied successfully');
  }
}

