/// Banks data for different countries
class BanksData {
  // Philippine Banks
  static const List<String> philippineBanks = [
    'BDO Unibank',
    'Bank of the Philippine Islands (BPI)',
    'Metrobank',
    'Land Bank of the Philippines',
    'Philippine National Bank (PNB)',
    'Security Bank',
    'UnionBank',
    'RCBC',
    'Chinabank',
    'EastWest Bank',
    'Asia United Bank',
    'UCPB',
    'PNB Savings Bank',
    'Philippine Bank of Communications (PBCom)',
    'Maybank Philippines',
    'HSBC Philippines',
    'Citibank Philippines',
    'BPI Family Savings Bank',
    'PSBank',
    'Robinsons Bank',
  ];

  // UK Banks
  static const List<String> ukBanks = [
    'Barclays',
    'HSBC UK',
    'Lloyds Bank',
    'NatWest',
    'Santander UK',
    'TSB Bank',
    'Nationwide Building Society',
    'Royal Bank of Scotland',
    'Halifax',
    'Metro Bank',
    'Monzo',
    'Revolut',
    'Starling Bank',
    'First Direct',
    'Virgin Money',
    'Co-operative Bank',
    'Yorkshire Bank',
    'Clydesdale Bank',
    'Bank of Scotland',
    'Ulster Bank',
  ];

  /// Get banks by country
  static List<String> getBanksByCountry(String country) {
    switch (country) {
      case 'Philippines':
        return philippineBanks;
      case 'UK':
        return ukBanks;
      default:
        return [];
    }
  }

  /// Get all countries
  static const List<String> countries = ['Philippines', 'UK'];
}

