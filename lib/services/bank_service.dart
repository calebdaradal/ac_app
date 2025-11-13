import 'package:supabase_flutter/supabase_flutter.dart';

class BankService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all banks from a specific country
  static Future<List<Bank>> getBanksByCountry(String country) async {
    final response = await _supabase
        .from('banks')
        .select('id, bank_name, country')
        .eq('country', country)
        .order('bank_name', ascending: true);

    return (response as List).map((item) => Bank.fromJson(item)).toList();
  }

  /// Get all banks (all countries)
  static Future<List<Bank>> getAllBanks() async {
    final response = await _supabase
        .from('banks')
        .select('id, bank_name, country')
        .order('country, bank_name', ascending: true);

    return (response as List).map((item) => Bank.fromJson(item)).toList();
  }

  /// Add a new bank (admin only)
  static Future<void> addBank({
    required String bankName,
    required String country,
  }) async {
    await _supabase.from('banks').insert({
      'bank_name': bankName,
      'country': country,
    });
  }

  /// Delete a bank (admin only)
  static Future<void> deleteBank(int bankId) async {
    await _supabase.from('banks').delete().eq('id', bankId);
  }

  /// Update a bank (admin only)
  static Future<void> updateBank({
    required int bankId,
    required String bankName,
    required String country,
  }) async {
    await _supabase.from('banks').update({
      'bank_name': bankName,
      'country': country,
    }).eq('id', bankId);
  }
}

/// Bank model
class Bank {
  final int id;
  final String bankName;
  final String country;

  Bank({
    required this.id,
    required this.bankName,
    required this.country,
  });

  factory Bank.fromJson(Map<String, dynamic> json) {
    return Bank(
      id: json['id'] as int,
      bankName: json['bank_name'] as String,
      country: json['country'] as String,
    );
  }
}

