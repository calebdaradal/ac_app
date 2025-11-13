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
      final userTransactions = await _supabase
          .from('usertransactions')
          .select('id, transaction_id, amount, status, applied_at')
          .eq('user_uid', uid)
          .eq('vehicle_id', vehicleId)
          .order('applied_at', ascending: false);

      print('[TransactionHistory] Found ${userTransactions.length} user transactions');

      for (var trans in userTransactions) {
        final transactionTypeId = trans['transaction_id'] as int;
        final status = trans['status'] as String;
        final amount = (trans['amount'] as num).toDouble();
        final appliedAt = DateTime.parse(trans['applied_at'] as String);

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

        allTransactions.add(TransactionHistoryItem(
          id: trans['id'] as int,
          type: type,
          amount: amount,
          yieldPercent: null,
          status: displayStatus,
          date: appliedAt,
          isPositive: type == 'Deposit',
        ));
      }

      // 2. Fetch yield distributions with applied_date from yields table
      final yieldDistributions = await _supabase
          .from('user_yield_distributions')
          .select('id, net_yield, gross_yield, balance_before, yield_id, yields!inner(yield_type, yield_amount, applied_date)')
          .eq('user_uid', uid)
          .eq('vehicle_id', vehicleId);

      print('[TransactionHistory] Found ${yieldDistributions.length} yield distributions');

      // Sort yield distributions by applied_date (most recent first)
      final sortedYieldDistributions = (yieldDistributions as List).toList()
        ..sort((a, b) {
          final yieldsA = a['yields'] as Map<String, dynamic>;
          final yieldsB = b['yields'] as Map<String, dynamic>;
          final dateA = DateTime.parse(yieldsA['applied_date'] as String);
          final dateB = DateTime.parse(yieldsB['applied_date'] as String);
          return dateB.compareTo(dateA); // Most recent first
        });

      for (var yieldDist in sortedYieldDistributions) {
        final netYield = (yieldDist['net_yield'] as num).toDouble();
        final grossYield = (yieldDist['gross_yield'] as num).toDouble();
        final balanceBefore = (yieldDist['balance_before'] as num).toDouble();
        // Get applied_date from nested yields object
        final yieldsData = yieldDist['yields'] as Map<String, dynamic>;
        final appliedDate = DateTime.parse(yieldsData['applied_date'] as String);
        
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
          isPositive: netYield >= 0, // Positive if net yield is positive, negative otherwise
        ));
      }

      // Sort all transactions by date (most recent first)
      allTransactions.sort((a, b) => b.date.compareTo(a.date));

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
  final DateTime date;
  final bool isPositive; // true for deposits and yields, false for withdrawals

  TransactionHistoryItem({
    required this.id,
    required this.type,
    required this.amount,
    this.yieldPercent,
    required this.status,
    required this.date,
    required this.isPositive,
  });

  String get displayAmount {
    final formatter = NumberFormat.decimalPattern();
    final prefix = isPositive ? '+ ₱' : '- ₱';
    return '$prefix${formatter.format(amount)}';
  }

  String get displayDate {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  String get displayYieldPercent {
    if (yieldPercent == null) return '';
    return '${yieldPercent! >= 0 ? '+' : ''}${yieldPercent!.toStringAsFixed(2)}%';
  }
}

