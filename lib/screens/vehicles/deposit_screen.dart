import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/shared/styled_textfield.dart';
import 'package:ac_app/shared/styled_button.dart';
import 'package:ac_app/shared/success_dialog.dart';
import 'package:ac_app/services/bank_details_service.dart';
import 'package:ac_app/services/transaction_service.dart';
import 'package:ac_app/constants/transaction_constants.dart';
import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DepositFunds extends StatefulWidget {
  static const routeName = '/deposit';
  const DepositFunds({super.key});

  @override
  State<DepositFunds> createState() => _DepositFundsState();
}

class _DepositFundsState extends State<DepositFunds> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _refNumberController = TextEditingController();
  
  List<BankDetails> _adminBankDetails = [];
  List<BankDetails> _userBankDetails = [];
  BankDetails? _selectedUserBankDetail;
  bool _isLoading = true;
  bool _isSubmitting = false;
  int? _vehicleId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBankDetails();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get vehicleId from route arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is int) {
      _vehicleId = args;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadBankDetails() async {
    setState(() => _isLoading = true);
    
    try {
      // Fetch both admin and user bank details in parallel
      final results = await Future.wait([
        BankDetailsService.getAdminBankDetails(),
        BankDetailsService.getAllBankDetails(), // User's bank details
      ]);
      
      if (mounted) {
        setState(() {
          _adminBankDetails = results[0];
          _userBankDetails = results[1];
          // Auto-select first user bank detail if available
          if (_userBankDetails.isNotEmpty) {
            _selectedUserBankDetail = _userBankDetails[0];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[DepositScreen] Error loading bank details: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bank details: $e')),
        );
      }
    }
  }

  Future<void> _submitDeposit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_vehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid vehicle information')),
      );
      return;
    }

    if (_selectedUserBankDetail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add your bank details in Profile first')),
      );
      return;
    }

    // Validate amount
    if (_amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the deposit amount')),
      );
      return;
    }

    // Validate reference number
    if (_refNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the reference number')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_amountController.text.trim());
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amount must be greater than zero')),
        );
        setState(() => _isSubmitting = false);
        return;
      }
      final refNumber = int.parse(_refNumberController.text.trim());

      await TransactionService.createTransaction(
        transactionTypeId: TransactionType.deposit,
        amount: amount,
        bankDetailId: _selectedUserBankDetail!.id, // Use selected user bank detail
        status: TransactionStatus.pending,
        vehicleId: _vehicleId,
        refNumber: refNumber,
      );

      if (mounted) {
        // Show success dialog
        await showSuccessDialog(context, 'Deposit submitted successfully!');
        
        // Navigate back to vehicle screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting deposit: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }


  String _getFlagEmoji(String location) {
    if (location == 'Philippines') return '🇵🇭';
    if (location == 'UK') return '🇬🇧';
    return '🏳️';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.titleColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TitleText('Deposit Funds', fontSize: 24),
                  const SizedBox(height: 24),
                  
                  // Step 1: Transfer Funds
                  _buildStepHeader(
                    stepNumber: '1',
                    title: 'Transfer Funds',
                    description: 'Transfer funds using the bank details provided. Select the appropriate bank details based on your location (UK or PH). Note that we will need a reference number/transaction ID. (see next step)',
                  ),
                  const SizedBox(height: 16),
                  
                  if (_adminBankDetails.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.account_balance, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const SecondaryText(
                              'No bank details available',
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._adminBankDetails.map((detail) => _buildBankCard(detail)).toList(),
                  
                  const SizedBox(height: 32),
                  
                  // Step 2: Request Verification
                  _buildStepHeader(
                    stepNumber: '2',
                    title: 'Request Verification',
                    description: 'Fill out deposit form to request verification of deposit. If request is within UK working hours, this should not take more than an hour. You can track your deposit verification status in your dashboard.',
                  ),
                  const SizedBox(height: 16),
                  
                  // User's Bank Details
                  if (_userBankDetails.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange.shade700),
                          const SizedBox(height: 12),
                          const SecondaryText(
                            'No bank details found',
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          const SizedBox(height: 8),
                          const SecondaryText(
                            'Please add your bank details in Profile before making a deposit.',
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SecondaryText('Your Bank Details', fontSize: 14, color: Colors.black87),
                            const Spacer(),
                            if (_userBankDetails.length > 1)
                              PopupMenuButton<BankDetails>(
                                onSelected: (detail) {
                                  setState(() {
                                    _selectedUserBankDetail = detail;
                                  });
                                },
                                itemBuilder: (context) {
                                  return _userBankDetails.map((detail) {
                                    return PopupMenuItem<BankDetails>(
                                      value: detail,
                                      child: Row(
                                        children: [
                                          Text(_getFlagEmoji(detail.location)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              detail.bankName,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (detail.id == _selectedUserBankDetail?.id)
                                            Icon(Icons.check, color: AppColors.primaryColor, size: 20),
                                        ],
                                      ),
                                    );
                                  }).toList();
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SecondaryText(
                                      'Change',
                                      fontSize: 13,
                                      color: AppColors.primaryColor,
                                    ),
                                    Icon(Icons.arrow_drop_down, color: AppColors.primaryColor, size: 20),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildUserBankCard(_selectedUserBankDetail!),
                      ],
                    ),
                  const SizedBox(height: 24),
                  
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        
                        const SecondaryText('Amount Deposited', fontSize: 14),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(247, 249, 252, 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Text(
                                  '₱',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.titleColor,
                                  ),
                                ),
                              ),
                              Expanded(
                                
                                child: TextField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                  ],
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.titleColor,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter amount',
                                    hintStyle: TextStyle(
                                      color: AppColors.titleColor.withOpacity(0.5),
                                    ),
                                    filled: true,
                                    fillColor: const Color.fromRGBO(247, 249, 252, 1),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    // enabledBorder: OutlineInputBorder(
                                    //   borderRadius: BorderRadius.circular(12),
                                    //   borderSide: BorderSide.none,
                                    // ),
                                    // focusedBorder: OutlineInputBorder(
                                    //   borderRadius: BorderRadius.circular(12),
                                    //   borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                                    // ),
                                    contentPadding: const EdgeInsets.only(right: 16, top: 16, bottom: 16, left: 5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        const SecondaryText('Reference Number *', fontSize: 14),
                        const SizedBox(height: 8),
                        StyledTextfield(
                          controller: _refNumberController,
                          keyboardType: TextInputType.number,
                          label: 'Enter reference/transaction number',
                        ),
                        const SizedBox(height: 8),
                        const SecondaryText(
                          '* This is the reference number from your bank transfer',
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 24),
                        
                        SizedBox(
                          width: double.infinity,
                          child: StyledButton(
                            onPressed: _isSubmitting ? null : _submitDeposit,
                            child: Text(_isSubmitting ? 'Submitting...' : 'Submit Deposit Request'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildStepHeader({
    required String stepNumber,
    required String title,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  stepNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            TitleText(title, fontSize: 18),
          ],
        ),
        const SizedBox(height: 12),
        SecondaryText(
          description,
          fontSize: 13,
          color: Colors.grey.shade700,
        ),
      ],
    );
  }

  Widget _buildBankCard(BankDetails detail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _getFlagEmoji(detail.location),
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TitleText(detail.bankName, fontSize: 16),
                      const SizedBox(height: 4),
                      SecondaryText(
                        detail.location,
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    final text = '''
Bank: ${detail.bankName}
Account Name: ${detail.accountName}
Account Number: ${detail.accountNumber}${detail.location == 'UK' && detail.shortCode != null ? '\nShort Code: ${detail.shortCode}' : ''}
''';
                    Clipboard.setData(ClipboardData(text: text));
                    showSuccessDialog(context, 'Bank details copied to clipboard');
                  },
                  tooltip: 'Copy details',
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow('Account Name', detail.accountName),
            const SizedBox(height: 8),
            _buildDetailRow('Account Number', detail.accountNumber),
            if (detail.location == 'UK' && detail.shortCode != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow('Short Code', detail.shortCode!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserBankCard(BankDetails detail) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _getFlagEmoji(detail.location),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TitleText(detail.bankName, fontSize: 15),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow('Account Name', detail.accountName),
            const SizedBox(height: 8),
            _buildDetailRow('Account Number', detail.accountNumber),
            if (detail.location == 'UK' && detail.shortCode != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow('Short Code', detail.shortCode!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: SecondaryText(
            label,
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: TitleText(
            value,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}