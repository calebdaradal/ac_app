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
      // Try to get created_at if available, otherwise we'll use ID-based sorting
      final userTransactionsResponse = await _supabase
          .from('usertransactions')
          .select('id, transaction_id, amount, status, applied_at')
          .eq('user_uid', uid)
          .eq('vehicle_id', vehicleId);

      print('[TransactionHistory] Found ${userTransactionsResponse.length} user transactions');

      // First, get all yields to establish a reference point for transaction timing
      // Also get yield IDs to compare with transaction IDs
      final yieldDistributionsForRef = await _supabase
          .from('user_yield_distributions')
          .select('id, created_at')
          .eq('user_uid', uid)
          .eq('vehicle_id', vehicleId);
      
      DateTime? mostRecentYieldDate;
      DateTime? oldestYieldDate;
      int? maxYieldId;
      int? minYieldId;
      
      if (yieldDistributionsForRef.isNotEmpty) {
        for (var dist in yieldDistributionsForRef) {
          if (dist['created_at'] != null) {
            final createdAt = DateTime.parse(dist['created_at'] as String);
            if (mostRecentYieldDate == null || createdAt.isAfter(mostRecentYieldDate)) {
              mostRecentYieldDate = createdAt;
            }
            if (oldestYieldDate == null || createdAt.isBefore(oldestYieldDate)) {
              oldestYieldDate = createdAt;
            }
          }
          final yieldId = dist['id'] as int?;
          if (yieldId != null) {
            if (maxYieldId == null || yieldId > maxYieldId) maxYieldId = yieldId;
            if (minYieldId == null || yieldId < minYieldId) minYieldId = yieldId;
          }
        }
      }

      // Find max and min transaction IDs for relative positioning
      int maxTransactionId = 0;
      int minTransactionId = 999999999;
      for (var trans in userTransactionsResponse) {
        final id = trans['id'] as int;
        if (id > maxTransactionId) maxTransactionId = id;
        if (id < minTransactionId) minTransactionId = id;
      }

      for (var trans in userTransactionsResponse) {
        final transactionTypeId = trans['transaction_id'] as int;
        final status = trans['status'] as String;
        final amount = (trans['amount'] as num).toDouble();
        final appliedAt = DateTime.parse(trans['applied_at'] as String);
        final transactionId = trans['id'] as int;

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

        // Estimate actionDate: Since usertransactions doesn't have created_at,
        // we estimate based on transaction ID relative to yield IDs and timestamps.
        // Key insight: Compare transaction IDs with yield IDs to determine relative creation order.
        
        DateTime estimatedActionDate;
        
        if (mostRecentYieldDate != null && oldestYieldDate != null && maxYieldId != null) {
          // We have yield data - compare transaction ID with yield IDs to determine order
          
          // If transaction ID is LESS than the maximum yield ID, it was likely created BEFORE yields
          // If transaction ID is GREATER than the maximum yield ID, it was likely created AFTER yields
          
          final maxYieldIdValue = maxYieldId; // Safe because we checked != null above
          
          if (transactionId < maxYieldIdValue) {
            // Transaction was created BEFORE yields - position it before oldestYieldDate
            // Use transaction ID relative to minTransactionId to position it
            final idRange = maxYieldIdValue - minTransactionId;
            if (idRange > 0) {
              final idPosition = (transactionId - minTransactionId) / idRange;
              // Position before oldestYieldDate, going back up to 30 days
              final daysBeforeOldest = ((1.0 - idPosition) * 30).toInt();
              estimatedActionDate = oldestYieldDate.subtract(Duration(days: daysBeforeOldest));
            } else {
              estimatedActionDate = oldestYieldDate.subtract(const Duration(days: 1));
            }
          } else {
            // Transaction was created AFTER yields - position it after mostRecentYieldDate
            // Use transaction ID relative to maxYieldId to determine how much after
            final idRange = maxTransactionId - maxYieldIdValue;
            if (idRange > 0) {
              final idPosition = (transactionId - maxYieldIdValue) / idRange;
              // Position after mostRecentYieldDate, extending forward up to 7 days
              final daysAfterRecent = (idPosition * 7).toInt();
              estimatedActionDate = mostRecentYieldDate.add(Duration(days: daysAfterRecent + 1));
            } else {
              estimatedActionDate = mostRecentYieldDate.add(const Duration(days: 1));
            }
          }
        } else {
          // No yields yet - use current time as reference
          final idRange = maxTransactionId - minTransactionId;
          final idPosition = idRange > 0 
              ? (transactionId - minTransactionId) / idRange 
              : 1.0;
          
          // Position relative to current time (last 90 days)
          final daysAgo = ((1.0 - idPosition) * 90).toInt();
          estimatedActionDate = DateTime.now().subtract(Duration(days: daysAgo));
        }
        
        final finalActionDate = estimatedActionDate;

        allTransactions.add(TransactionHistoryItem(
          id: transactionId,
          type: type,
          amount: amount,
          yieldPercent: null,
          status: displayStatus,
          date: appliedAt,
          actionDate: finalActionDate,
          isPositive: type == 'Deposit',
        ));
      }

      // 2. Fetch yield distributions with applied_date from yields table and created_at from user_yield_distributions
      final yieldDistributions = await _supabase
          .from('user_yield_distributions')
          .select('id, net_yield, gross_yield, balance_before, yield_id, created_at, yields!inner(yield_type, yield_amount, applied_date)')
          .eq('user_uid', uid)
          .eq('vehicle_id', vehicleId);

      print('[TransactionHistory] Found ${yieldDistributions.length} yield distributions');

      for (var yieldDist in yieldDistributions) {
        final netYield = (yieldDist['net_yield'] as num).toDouble();
        final grossYield = (yieldDist['gross_yield'] as num).toDouble();
        final balanceBefore = (yieldDist['balance_before'] as num).toDouble();
        // Get applied_date from nested yields object
        final yieldsData = yieldDist['yields'] as Map<String, dynamic>;
        final appliedDate = DateTime.parse(yieldsData['applied_date'] as String);
        // Use created_at from user_yield_distributions (when the yield was distributed to this user) for ordering
        final createdAtStr = yieldDist['created_at'] as String?;
        final actionDate = createdAtStr != null 
            ? DateTime.parse(createdAtStr)
            : appliedDate; // Fallback to applied_date if created_at is not available
        
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

