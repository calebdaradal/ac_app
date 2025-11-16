import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'user_profile_service.dart';

class TransactionHistoryService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch all transaction history for a specific vehicle and user
  /// Includes: Deposits, Withdrawals, and Yield distributions
  static Future<List<TransactionHistoryItem>> getVehicleTransactionHistory(int vehicleId) async {
    final uid = UserProfileService().profile?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    print('[TransactionHistory] Fetching history for vehicle: $vehicleId, user: $uid');

    List<TransactionHistoryItem> allTransactions = [];

    try {
      // 1. Fetch user transactions (deposits and withdrawals)
      // Now using created_at from usertransactions table for accurate ordering
      final userTransactionsResponse = await _supabase
          .from('usertransactions')
          .select('id, transaction_id, amount, status, applied_at, created_at')
          .eq('user_uid', uid)
          .eq('vehicle_id', vehicleId);

      print('[TransactionHistory] Found ${userTransactionsResponse.length} user transactions');

      for (var trans in userTransactionsResponse) {
        final transactionTypeId = trans['transaction_id'] as int;
        final status = trans['status'] as String;
        final amount = (trans['amount'] as num).toDouble();
        final appliedAt = DateTime.parse(trans['applied_at'] as String);
        final transactionId = trans['id'] as int;
        // Get created_at for ordering (when transaction was actually created)
        final createdAtStr = trans['created_at'] as String?;

        String type;
        String displayStatus;
        
        if (transactionTypeId == 2) {
          // Deposit
          type = 'Deposit';
          if (status == 'PENDING') {
            displayStatus = 'Verifying';
          } else if (status == 'DENIED') {
            displayStatus = 'Denied';
          } else if (status == 'VERIFIED') {
            displayStatus = 'Verified';
          } else {
            displayStatus = status; // Show actual status for any other cases
          }
        } else {
          // Withdrawal
          type = 'Withdrawal';
          if (status == 'PENDING') {
            displayStatus = 'Verifying';
          } else if (status == 'ISSUED') {
            displayStatus = 'Completed';
          } else if (status == 'DENIED') {
            displayStatus = 'Denied';
          } else {
            displayStatus = status; // Show actual status for any other cases
          }
        }

        // Use created_at for actionDate (when transaction was actually created)
        // Fallback to applied_at if created_at is null (shouldn't happen with default now())
        DateTime actionDate;
        if (createdAtStr != null && createdAtStr.isNotEmpty) {
          try {
            actionDate = DateTime.parse(createdAtStr);
          } catch (e) {
            print('[TransactionHistory] Error parsing created_at for transaction $transactionId: $e');
            // Fallback to applied_at if parsing fails
            actionDate = appliedAt;
          }
        } else {
          // Fallback to applied_at if created_at is null
          actionDate = appliedAt;
        }

        allTransactions.add(TransactionHistoryItem(
          id: transactionId,
          type: type,
          amount: amount,
          yieldPercent: null,
          status: displayStatus,
          date: appliedAt,
          actionDate: actionDate,
          isPositive: type == 'Deposit',
        ));
      }

      // 2. Fetch yield distributions with applied_date and created_at from yields table
      // Use created_at from yields table (when admin created the yield) for ordering
      final yieldDistributions = await _supabase
          .from('user_yield_distributions')
          .select('id, net_yield, gross_yield, balance_before, yield_id, yields!inner(yield_type, yield_amount, applied_date, created_at)')
          .eq('user_uid', uid)
          .eq('vehicle_id', vehicleId);

      print('[TransactionHistory] Found ${yieldDistributions.length} yield distributions');

      for (var yieldDist in yieldDistributions) {
        final netYield = (yieldDist['net_yield'] as num).toDouble();
        final grossYield = (yieldDist['gross_yield'] as num).toDouble();
        final balanceBefore = (yieldDist['balance_before'] as num).toDouble();
        // Get applied_date and created_at from nested yields object
        final yieldsData = yieldDist['yields'] as Map<String, dynamic>;
        final appliedDate = DateTime.parse(yieldsData['applied_date'] as String);
        // Use created_at from yields table (when admin created/applied the yield) for ordering
        final createdAtStr = yieldsData['created_at'] as String?;
        DateTime actionDate;
        if (createdAtStr != null && createdAtStr.isNotEmpty) {
          try {
            actionDate = DateTime.parse(createdAtStr);
          } catch (e) {
            print('[TransactionHistory] Error parsing created_at for yield: $e');
            // Fallback to applied_date if parsing fails
            actionDate = appliedDate;
          }
        } else {
          // Fallback to applied_date if created_at is null
          actionDate = appliedDate;
        }
        
        // Calculate yield percentage: (gross_yield / balance_before) * 100
        double yieldPercent = 0.0;
        if (balanceBefore > 0) {
          yieldPercent = (grossYield / balanceBefore) * 100;
        }

        allTransactions.add(TransactionHistoryItem(
          id: yieldDist['id'] as int,
          type: 'Yield',
          amount: netYield,
          yieldPercent: yieldPercent,
          status: 'Applied',
          date: appliedDate,
          actionDate: actionDate,
          isPositive: netYield >= 0, // Positive if net yield is positive, negative otherwise
        ));
      }

      // Sort all transactions by actionDate (most recent action first)
      allTransactions.sort((a, b) => b.actionDate.compareTo(a.actionDate));

      // Debug: Print transaction order for troubleshooting
      print('[TransactionHistory] Transaction order after sorting:');
      for (var trans in allTransactions) {
        print('[TransactionHistory] - ${trans.type} (id=${trans.id}): actionDate=${trans.actionDate.toIso8601String()}, displayDate=${trans.date.toIso8601String()}');
      }

      print('[TransactionHistory] Total transactions: ${allTransactions.length}');

      return allTransactions;
    } catch (e) {
      print('[TransactionHistory] Error fetching history: $e');
      rethrow;
    }
  }

  /// Format date for display
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  /// Format currency
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.decimalPattern();
    return formatter.format(amount);
  }
}

/// Transaction History Item model
class TransactionHistoryItem {
  final int id;
  final String type; // 'Deposit', 'Withdrawal', 'Yield'
  final double amount;
  final double? yieldPercent;
  final String status;
  final DateTime date; // Applied date (for display)
  final DateTime actionDate; // When the action was made (for sorting)
  final bool isPositive; // true for deposits and yields, false for withdrawals

  TransactionHistoryItem({
    required this.id,
    required this.type,
    required this.amount,
    this.yieldPercent,
    required this.status,
    required this.date,
    required this.actionDate,
    required this.isPositive,
  });

  String get displayAmount {
    final formatter = NumberFormat.decimalPattern();
    final prefix = isPositive ? '+ ₱' : '- ₱';
    return '$prefix${formatter.format(amount)}';
  }

  String get displayDate {
    // For all transaction types, show "Applied date: Nov 7 2025" format
    return 'Applied date: ${DateFormat('MMM d yyyy').format(date)}';
  }

  String get displayYieldPercent {
    if (yieldPercent == null) return '';
    return '${yieldPercent! >= 0 ? '+' : ''}${yieldPercent!.toStringAsFixed(2)}%';
  }
}

