import 'package:ac_app/constants/banks_data.dart';
import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';

class ManageBanksScreen extends StatefulWidget {
  static const routeName = '/manage-banks';
  const ManageBanksScreen({super.key});

  @override
  State<ManageBanksScreen> createState() => _ManageBanksScreenState();
}

class _ManageBanksScreenState extends State<ManageBanksScreen> {
  String _filterCountry = 'All';

  List<String> get _allBanks {
    final allBanks = <String>[];
    allBanks.addAll(BanksData.philippineBanks);
    allBanks.addAll(BanksData.ukBanks);
    return allBanks;
  }

  List<String> get _filteredBanks {
    if (_filterCountry == 'All') return _allBanks;
    if (_filterCountry == 'Philippines') return BanksData.philippineBanks;
    if (_filterCountry == 'UK') return BanksData.ukBanks;
    return [];
  }

  String _getBankCountry(String bankName) {
    if (BanksData.philippineBanks.contains(bankName)) return 'Philippines';
    if (BanksData.ukBanks.contains(bankName)) return 'UK';
    return 'Unknown';
  }

  void _showAddBankInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const TitleText('Add Bank', fontSize: 18),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SecondaryText(
                'To add a new bank, edit the following file:',
                fontSize: 14,
              ),
              SizedBox(height: 12),
              SelectableText(
                'lib/constants/banks_data.dart',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              SizedBox(height: 16),
              SecondaryText(
                'Add the bank name to the appropriate list:',
                fontSize: 14,
              ),
              SizedBox(height: 8),
              SelectableText(
                "• For Philippine banks: Add to 'philippineBanks' list\n• For UK banks: Add to 'ukBanks' list",
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 16),
              SecondaryText(
                'Example:',
                fontSize: 14,
                color: Colors.grey,
              ),
              SizedBox(height: 8),
              SelectableText(
                "static const List<String> philippineBanks = [\n  'BDO Unibank',\n  'BPI',\n  'Your New Bank', // ← Add here\n];",
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16),
              SecondaryText(
                'After editing, hot reload the app to see changes.',
                fontSize: 13,
                color: Colors.orange,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const TitleText('Manage Banks', fontSize: 20),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: AppColors.primaryColor),
            onPressed: _showAddBankInstructions,
            tooltip: 'How to add banks',
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: SecondaryText(
                    'Banks are stored locally. Tap the info icon to learn how to add/edit banks.',
                    fontSize: 13,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),
          // Filter chips
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const TitleText('Filter: ', fontSize: 14),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('All (${_allBanks.length})'),
                  selected: _filterCountry == 'All',
                  onSelected: (selected) {
                    if (selected) setState(() => _filterCountry = 'All');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Philippines (${BanksData.philippineBanks.length})'),
                  selected: _filterCountry == 'Philippines',
                  onSelected: (selected) {
                    if (selected) setState(() => _filterCountry = 'Philippines');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('UK (${BanksData.ukBanks.length})'),
                  selected: _filterCountry == 'UK',
                  onSelected: (selected) {
                    if (selected) setState(() => _filterCountry = 'UK');
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Banks list
          Expanded(
            child: _filteredBanks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const SecondaryText(
                          'No banks found',
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredBanks.length,
                    itemBuilder: (context, index) {
                      final bankName = _filteredBanks[index];
                      final country = _getBankCountry(bankName);
                      return ListTile(
                        leading: Icon(
                          Icons.account_balance,
                          color: country == 'Philippines'
                              ? Colors.blue
                              : Colors.red,
                        ),
                        title: TitleText(bankName, fontSize: 15),
                        subtitle: SecondaryText(
                          country,
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBankInstructions,
        backgroundColor: AppColors.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

