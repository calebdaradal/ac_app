/// Transaction status constants
class TransactionStatus {
  static const String pending = 'PENDING';
  static const String verifying = 'VERIFYING';
  static const String success = 'SUCCESS';
  static const String failed = 'FAILED';
  static const String issued = 'ISSUED';
  static const String verified = 'VERIFIED';
  static const String denied = 'DENIED';

  static const List<String> allStatuses = [
    pending,
    verifying,
    success,
    failed,
    issued,
    verified,
    denied,
  ];
}

/// Transaction type IDs (should match your database)
class TransactionType {
  static const int deposit = 2; // Based on your transactions table: Deposit = 2
  static const int withdrawal = 1; // Withdrawal = 1
  static const int yield = 3; // Yield = 3
}

