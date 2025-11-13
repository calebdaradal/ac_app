import 'package:ac_app/constants/banks_data.dart';
import 'package:ac_app/services/bank_details_service.dart';
import 'package:ac_app/shared/styled_button.dart';
import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/shared/styled_textfield.dart';
import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';

class BankDetailsModal extends StatefulWidget {
  final BankDetails? existingDetails;
  final VoidCallback onSaved;

  const BankDetailsModal({
    this.existingDetails,
    required this.onSaved,
    super.key,
  });

  @override
  State<BankDetailsModal> createState() => _BankDetailsModalState();
}

class _BankDetailsModalState extends State<BankDetailsModal> {
  final _formKey = GlobalKey<FormState>();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  
  String? _selectedBank;
  String? _selectedLocation;
  List<String> _availableBanks = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingDetails != null) {
      _selectedLocation = widget.existingDetails!.location;
      _accountNumberController.text = widget.existingDetails!.accountNumber;
      _accountNameController.text = widget.existingDetails!.accountName;
      
      // Load banks for the existing location
      if (_selectedLocation != null) {
        _availableBanks = BanksData.getBanksByCountry(_selectedLocation!);
        // Validate and set the bank if it exists in the list
        final bankExists = _availableBanks.contains(widget.existingDetails!.bankName);
        if (bankExists) {
          _selectedBank = widget.existingDetails!.bankName;
        }
      }
    }
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedBank == null || _selectedBank!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a bank')),
      );
      return;
    }

    if (_accountNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter account number')),
      );
      return;
    }

    if (_selectedLocation == null || _selectedLocation!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
      return;
    }

    if (_accountNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter account name')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await BankDetailsService.saveBankDetails(
        bankName: _selectedBank!,
        accountNumber: _accountNumberController.text.trim(),
        location: _selectedLocation!,
        accountName: _accountNameController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bank details saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving bank details: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                TitleText(
                  'Bank Details',
                  fontSize: 24,
                  color: AppColors.titleColor,
                ),
                const SizedBox(height: 8),
                SecondaryText(
                  'Please provide your bank account information',
                  fontSize: 14,
                ),
                const SizedBox(height: 24),

                // Location Dropdown (should come first to filter banks)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrimaryText(
                      'Location',
                      fontSize: 14,
                      color: AppColors.titleColor.withOpacity(0.7),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(247, 249, 252, 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedLocation,
                        decoration: InputDecoration(
                          hintText: 'Select your location',
                          hintStyle: TextStyle(
                            color: AppColors.titleColor.withOpacity(0.5),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.transparent),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        items: BanksData.countries.map((country) {
                          return DropdownMenuItem(
                            value: country,
                            child: Text(country),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedLocation = value;
                            _selectedBank = null; // Reset bank when location changes
                            _availableBanks = value != null ? BanksData.getBanksByCountry(value) : [];
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Bank Name Dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrimaryText(
                      'Bank Name',
                      fontSize: 14,
                      color: AppColors.titleColor.withOpacity(0.7),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(247, 249, 252, 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedBank,
                        decoration: InputDecoration(
                          hintText: _selectedLocation == null 
                              ? 'Select location first' 
                              : 'Select your bank',
                          hintStyle: TextStyle(
                            color: AppColors.titleColor.withOpacity(0.5),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.transparent),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        items: _availableBanks.map((bank) {
                          return DropdownMenuItem(
                            value: bank,
                            child: Text(bank),
                          );
                        }).toList(),
                        onChanged: _selectedLocation == null ? null : (value) {
                          setState(() => _selectedBank = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Account Number
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrimaryText(
                      'Account Number',
                      fontSize: 14,
                      color: AppColors.titleColor.withOpacity(0.7),
                    ),
                    const SizedBox(height: 8),
                    StyledTextfield(
                      controller: _accountNumberController,
                      keyboardType: TextInputType.number,
                      label: 'Enter account number',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Account Name
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrimaryText(
                      'Account Name',
                      fontSize: 14,
                      color: AppColors.titleColor.withOpacity(0.7),
                    ),
                    const SizedBox(height: 8),
                    StyledTextfield(
                      controller: _accountNameController,
                      keyboardType: TextInputType.name,
                      label: 'Enter account name',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Save Button
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        onPressed: _submitting ? null : _save,
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const PrimaryTextW('Save Details'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// Helper function to show the bank details modal
void showBankDetailsModal(BuildContext context, {BankDetails? existingDetails, required VoidCallback onSaved}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => BankDetailsModal(
      existingDetails: existingDetails,
      onSaved: onSaved,
    ),
  );
}

