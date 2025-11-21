import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ac_app/services/user_profile_service.dart';
import 'package:ac_app/constants/transaction_constants.dart';
import 'package:ac_app/utils/redemption_dates.dart';

class TransactionService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Calculate withdrawal fee based on amount, current balance, and applied date
  /// Returns a map with 'fee', 'totalDeduction', and 'finalWithdrawAmount'
  /// 
  /// Penalties are applied SEQUENTIALLY:
  /// 1. Redemption penalty (5%) reduces withdrawal amount
  /// 2. Gate penalty (5%) is applied to the reduced amount if threshold is met
  /// 
  /// Fee logic (TWO penalties applied sequentially):
  /// 1. Redemption penalty (5%): Applies when withdrawing on NON-redemption dates
  /// 2. Gate penalty (5%): Applies when withdrawal amount >= 33.33% of current balance
  /// 
  /// Process:
  /// - First apply redemption penalty (if non-redemption date)
  /// - Then check if original withdrawal amount >= 33.33% of balance
  /// - If yes, apply gate penalty
  /// 
  /// Examples:
  /// - Withdraw 10% on non-redemption date: 5% redemption penalty only
  /// - Withdraw 40% on non-redemption date: 5% redemption + 5% gate = 10% total
  /// - Withdraw 40% on redemption date: 5% gate penalty only
  /// - Withdraw 10% on redemption date: No penalties
  static Map<String, double> calculateWithdrawalFee({
    required double withdrawalAmount,
    required double currentBalance,
    DateTime? appliedDate,
  }) {
    // Use provided date or default to today
    final date = appliedDate ?? DateTime.now();
    
    // Check if it's a redemption date
    final isRedemptionDate = RedemptionDates.isRedemptionDate(date);
    
    // Calculate 33.33% threshold (using 1/3 for precision)
    final threshold = currentBalance / 3.0;
    
    print('[TransactionService] === FEE CALCULATION START ===');
    print('[TransactionService] Original Withdrawal Amount: $withdrawalAmount');
    print('[TransactionService] Current Balance: $currentBalance');
    print('[TransactionService] Threshold (33.33%): $threshold');
    print('[TransactionService] Is Redemption Date: $isRedemptionDate');
    
    double withdrawalAfterPenalties = withdrawalAmount;
    double totalFee = 0.0;
    
    // STEP 1: Apply redemption penalty (5% on NON-redemption dates)
    // This reduces the withdrawal amount by 5%
    if (!isRedemptionDate) {
      final redemptionPenalty = withdrawalAmount * 0.05;
      withdrawalAfterPenalties = withdrawalAmount - redemptionPenalty;
      totalFee += redemptionPenalty;
      print('[TransactionService] ✓ Applied redemption penalty (5%): $redemptionPenalty');
      print('[TransactionService] Withdrawal after redemption penalty: $withdrawalAfterPenalties');
    } else {
      print('[TransactionService] ✗ Skipped redemption penalty (redemption date)');
    }
    
    // STEP 2: Check if original withdrawal amount >= 33.33% of balance
    // If yes, apply gate penalty (5%) to the NEW withdrawal amount (after redemption penalty)
    final meetsGateThreshold = withdrawalAmount >= threshold;
    print('[TransactionService] Gate threshold check: $withdrawalAmount >= $threshold = $meetsGateThreshold');
    
    if (meetsGateThreshold) {
      // Apply gate penalty to the withdrawal amount AFTER redemption penalty
      final gatePenalty = withdrawalAfterPenalties * 0.05;
      withdrawalAfterPenalties = withdrawalAfterPenalties - gatePenalty;
      totalFee += gatePenalty;
      print('[TransactionService] ✓✓✓ APPLIED GATE PENALTY (5%): $gatePenalty ✓✓✓');
      print('[TransactionService] Final withdrawal amount: $withdrawalAfterPenalties');
    } else {
      print('[TransactionService] ✗✗✗ SKIPPED GATE PENALTY (withdrawal < 33.33%) ✗✗✗');
    }

    print('[TransactionService] === FEE CALCULATION END ===');
    print('[TransactionService] Total fee deducted: $totalFee');
    print('[TransactionService] Final withdrawal amount: $withdrawalAfterPenalties');
    print('[TransactionService] Total deduction from balance: ${withdrawalAmount}');
    
    // Return the fee amount and total deduction
    // Total deduction is still the original withdrawal amount (what gets deducted from balance)
    // But the actual amount user receives is withdrawalAmount - totalFee
    return {
      'fee': totalFee,
      'totalDeduction': withdrawalAmount, // Original withdrawal amount (what gets deducted from balance)
      'finalWithdrawAmount': withdrawalAfterPenalties, // What user actually receives
    };
  }

  /// Create a new transaction record
  /// For withdrawals: amount represents the total deduction from balance (including fee)
  /// For deposits: amount represents the deposit amount (fee handled separately in investment service)
  static Future<int> createTransaction({
    required int transactionTypeId,
    required double amount,
    required int? bankDetailId,
    required String status,
    required int? vehicleId, // Store vehicle_id for later processing
    int? refNumber, // Reference number for deposits
  }) async {
    final uid = UserProfileService().profile?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    print('[TransactionService] Creating transaction: type=$transactionTypeId, amount=$amount, status=$status, vehicleId=$vehicleId, refNumber=$refNumber');

    // Round amount to 2 decimal places before saving to database
    final amountRounded = (amount * 100).round() / 100.0;

    // Set default applied_at to today's date (admin will update this when approving)
    final data = {
      'user_uid': uid,
      'transaction_id': transactionTypeId,
      'amount': amountRounded,
      'bank_detail': bankDetailId,
      'status': status,
      'vehicle_id': vehicleId, // Store vehicle_id in transaction
      'applied_at': DateTime.now().toIso8601String().split('T')[0], // Default to today's date
    };

    // Add ref_number if provided (for deposits)
    if (refNumber != null) {
      data['ref_number'] = refNumber;
    }

    final response = await _supabase
        .from('usertransactions')
        .insert(data)
        .select('id')
        .single();

    final transactionId = response['id'] as int;
    print('[TransactionService] Transaction created with ID: $transactionId');
    return transactionId;
  }

  /// Update transaction status (for admin verification)
  static Future<void> updateTransactionStatus({
    required int transactionId,
    required String status,
  }) async {
    print('[TransactionService] Updating transaction $transactionId to status: $status');

    final response = await _supabase
        .from('usertransactions')
        .update({'status': status})
        .eq('id', transactionId)
        .select('id, status')
        .single();

    print('[TransactionService] Transaction status updated successfully');
    print('[TransactionService] Updated transaction: $response');
    
    // Verify the update was successful
    if (response['status'] != status) {
      throw Exception('Failed to update transaction status. Expected: $status, Got: ${response['status']}');
    }
  }

  /// Update transaction status and applied_at date together (for admin verification)
  /// This prevents duplicate webhook triggers by combining both updates into one
  static Future<void> updateTransactionStatusAndDate({
    required int transactionId,
    required String status,
    required DateTime appliedDate,
  }) async {
    print('[TransactionService] Updating transaction $transactionId: status=$status, applied_at=$appliedDate');

    final response = await _supabase
        .from('usertransactions')
        .update({
          'status': status,
          'applied_at': appliedDate.toIso8601String().split('T')[0],
        })
        .eq('id', transactionId)
        .select('id, status, applied_at')
        .single();

    print('[TransactionService] Transaction status and date updated successfully');
    print('[TransactionService] Updated transaction: $response');
    
    // Verify the update was successful
    if (response['status'] != status) {
      throw Exception('Failed to update transaction status. Expected: $status, Got: ${response['status']}');
    }
  }

  /// Update transaction applied_at date (for admin when approving)
  static Future<void> updateTransactionAppliedDate({
    required int transactionId,
    required DateTime appliedDate,
  }) async {
    print('[TransactionService] Updating transaction $transactionId applied_at to: $appliedDate');

    final response = await _supabase
        .from('usertransactions')
        .update({
          'applied_at': appliedDate.toIso8601String().split('T')[0],
        })
        .eq('id', transactionId)
        .select('id, applied_at')
        .single();

    print('[TransactionService] Transaction applied_at updated successfully');
    print('[TransactionService] Updated transaction: $response');
  }

  /// Get all pending transactions (for admin)
  static Future<List<UserTransaction>> getPendingTransactions() async {
    print('[TransactionService] Fetching pending transactions');

    // Fetch transactions
    final response = await _supabase
        .from('usertransactions')
        .select('''
          id,
          user_uid,
          transaction_id,
          status,
          amount,
          bank_detail,
          vehicle_id,
          applied_at,
          ref_number,
          transactions:transaction_id(type),
          bankdetails:bank_detail(id, bank_name, account_name, acaccount_number, location, short_code)
        ''')
        .eq('status', TransactionStatus.pending)
        .order('applied_at', ascending: false);

    print('[TransactionService] Found ${response.length} pending transactions');
    
    // Debug: Print first transaction to see structure
    if (response.isNotEmpty) {
      print('[TransactionService] First transaction data: ${response[0]}');
    }
    
    // Get unique user UIDs
    final userUids = (response as List)
        .map((item) => item['user_uid'] as String)
        .toSet()
        .toList();

    print('[TransactionService] User UIDs to fetch: $userUids');

    // Fetch profiles for all users
    Map<String, Map<String, String?>> userProfiles = {};
    if (userUids.isNotEmpty) {
      // Try batch query first
      final profilesResponse = await _supabase
          .from('profiles')
          .select('id, first_name, last_name')
          .inFilter('id', userUids);

      print('[TransactionService] Profiles query response: $profilesResponse');
      print('[TransactionService] Profiles response length: ${profilesResponse.length}');

      // If batch query returned results, use them
      if (profilesResponse.isNotEmpty) {
        for (var profile in profilesResponse) {
          print('[TransactionService] Profile: $profile');
          userProfiles[profile['id'] as String] = {
            'first_name': profile['first_name'] as String?,
            'last_name': profile['last_name'] as String?,
          };
        }
        print('[TransactionService] Fetched ${userProfiles.length} user profiles from batch query');
      } else {
        // Batch query returned empty - try fetching one by one (might be RLS issue)
        print('[TransactionService] Batch query returned empty, trying individual queries...');
        for (var uid in userUids) {
          try {
            final profileResponse = await _supabase
                .from('profiles')
                .select('id, first_name, last_name')
                .eq('id', uid)
                .maybeSingle();
            
            print('[TransactionService] Individual query for $uid: $profileResponse');
            
            if (profileResponse != null) {
              userProfiles[uid] = {
                'first_name': profileResponse['first_name'] as String?,
                'last_name': profileResponse['last_name'] as String?,
              };
            } else {
              print('[TransactionService] No profile found for $uid');
            }
          } catch (e) {
            print('[TransactionService] Error fetching profile for $uid: $e');
          }
        }
        print('[TransactionService] Fallback: Fetched ${userProfiles.length} user profiles');
      }
    }

    // Map transactions with profile data
    return (response as List).map((item) {
      final userUid = item['user_uid'] as String;
      final profile = userProfiles[userUid];
      
      // Add profile data to the item
      if (profile != null) {
        item['profiles'] = profile;
      }
      
      return UserTransaction.fromJson(item);
    }).toList();
  }

  /// Get all transactions for current user
  static Future<List<UserTransaction>> getUserTransactions() async {
    final uid = UserProfileService().profile?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    final response = await _supabase
        .from('usertransactions')
        .select('''
          id,
          user_uid,
          transaction_id,
          status,
          amount,
          bank_detail,
          applied_at,
          transactions:transaction_id(type),
          bankdetails:bank_detail(id, bank_name, account_name)
        ''')
        .eq('user_uid', uid)
        .order('applied_at', ascending: false);

    return (response as List).map((item) => UserTransaction.fromJson(item)).toList();
  }
}

/// User transaction model
class UserTransaction {
  final int id;
  final String userUid;
  final int? transactionId;
  final String? status;
  final double? amount;
  final int? bankDetailId;
  final int? vehicleId; // Store vehicle_id for processing on verification
  final DateTime appliedAt;
  final int? refNumber; // Reference number for deposits
  final String? transactionType;
  final String? bankName;
  final String? accountName;
  final String? accountNumber;
  final String? location;
  final String? shortCode;
  final String? firstName;
  final String? lastName;

  UserTransaction({
    required this.id,
    required this.userUid,
    this.transactionId,
    this.status,
    this.amount,
    this.bankDetailId,
    this.vehicleId,
    required this.appliedAt,
    this.refNumber,
    this.transactionType,
    this.bankName,
    this.accountName,
    this.accountNumber,
    this.location,
    this.shortCode,
    this.firstName,
    this.lastName,
  });

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return firstName ?? lastName ?? 'Unknown User';
  }

  factory UserTransaction.fromJson(Map<String, dynamic> json) {
    // Handle nested transaction type
    String? transactionType;
    if (json['transactions'] != null) {
      if (json['transactions'] is Map) {
        transactionType = json['transactions']['type'] as String?;
      }
    }

    // Handle nested bank details
    String? bankName;
    String? accountName;
    String? accountNumber;
    String? location;
    String? shortCode;
    
    print('[TransactionService] Bank details data: ${json['bankdetails']}');
    print('[TransactionService] Bank detail ID: ${json['bank_detail']}');
    
    if (json['bankdetails'] != null) {
      print('[TransactionService] Bank details found!');
      if (json['bankdetails'] is Map) {
        bankName = json['bankdetails']['bank_name'] as String?;
        accountName = json['bankdetails']['account_name'] as String?;
        accountNumber = json['bankdetails']['acaccount_number']?.toString();
        location = json['bankdetails']['location'] as String?;
        shortCode = json['bankdetails']['short_code']?.toString();
        print('[TransactionService] Parsed bank: $bankName, $accountName, $accountNumber, $location, short_code: $shortCode');
      }
    } else {
      print('[TransactionService] No bank details found in response');
    }

    // Handle nested user profile
    String? firstName;
    String? lastName;
    if (json['profiles'] != null) {
      print('[TransactionService] Profiles data found: ${json['profiles']}');
      if (json['profiles'] is Map) {
        firstName = json['profiles']['first_name'] as String?;
        lastName = json['profiles']['last_name'] as String?;
        print('[TransactionService] Parsed name: $firstName $lastName');
      } else if (json['profiles'] is List && (json['profiles'] as List).isNotEmpty) {
        // Sometimes Supabase returns a list instead of a single object
        final profile = (json['profiles'] as List)[0] as Map<String, dynamic>;
        firstName = profile['first_name'] as String?;
        lastName = profile['last_name'] as String?;
        print('[TransactionService] Parsed name from list: $firstName $lastName');
      }
    } else {
      print('[TransactionService] No profiles data found in transaction');
    }

    return UserTransaction(
      id: json['id'] as int,
      userUid: json['user_uid'] as String,
      transactionId: json['transaction_id'] as int?,
      status: json['status'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      bankDetailId: json['bank_detail'] as int?,
      vehicleId: json['vehicle_id'] as int?,
      appliedAt: DateTime.parse(json['applied_at'] as String),
      refNumber: json['ref_number'] as int?,
      transactionType: transactionType,
      bankName: bankName,
      accountName: accountName,
      accountNumber: accountNumber,
      location: location,
      shortCode: shortCode,
      firstName: firstName,
      lastName: lastName,
    );
  }
}

