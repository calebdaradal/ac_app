import 'package:flutter/material.dart';
import '../shared/styled_text.dart';
import '../shared/styled_textfield.dart';
import '../shared/styled_button.dart';
import '../theme.dart';
import '../services/user_profile_service.dart';
import '../services/bank_details_service.dart';
import '../constants/banks_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'verify_current_pin_screen.dart';

class ProfileScreen extends StatefulWidget {
  static const routeName = '/profile';
  
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bankFormKey = GlobalKey<FormState>();
  
  // Profile controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  
  // Bank details controllers
  String? _selectedLocation;
  String? _selectedBank;
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _shortCodeController = TextEditingController();
  
  List<String> _availableBanks = [];
  List<BankDetails> _allBankDetails = [];
  bool _isLoadingProfile = true;
  bool _isLoadingBank = true;
  bool _isUpdatingProfile = false;
  bool _isUpdatingBank = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadProfileData();
    await _loadBankDetails();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _shortCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      final profile = UserProfileService().profile;
      if (profile != null) {
        setState(() {
          _firstNameController.text = profile.firstName ?? '';
          _lastNameController.text = profile.lastName ?? '';
          _emailController.text = profile.email;
          _isAdmin = profile.isAdmin == true;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _loadBankDetails() async {
    try {
      if (_isAdmin) {
        // Load all bank details for admin
        final allDetails = await BankDetailsService.getAllBankDetails();
        if (mounted) {
          setState(() {
            _allBankDetails = allDetails;
            _isLoadingBank = false;
          });
        }
      } else {
        // Load single bank detail for regular users
        final bankDetails = await BankDetailsService.getBankDetails();
        if (bankDetails != null && mounted) {
          // Load banks for this location FIRST, before setting the selected bank
          if (bankDetails.location == 'Philippines' || bankDetails.location == 'UK') {
            _availableBanks = BanksData.getBanksByCountry(bankDetails.location);
          }
          
          // Validate that the bank exists in the available banks list
          final bankExists = _availableBanks.contains(bankDetails.bankName);
          
          setState(() {
            _selectedLocation = bankDetails.location;
            _selectedBank = bankExists ? bankDetails.bankName : null;
            _accountNumberController.text = bankDetails.accountNumber;
            _accountNameController.text = bankDetails.accountName;
            _shortCodeController.text = bankDetails.shortCode ?? '';
          });
          
          if (!bankExists && bankDetails.bankName.isNotEmpty) {
            print('[ProfileScreen] Warning: Bank "${bankDetails.bankName}" not found in ${bankDetails.location} banks list');
          }
        }
        if (mounted) {
          setState(() => _isLoadingBank = false);
        }
      }
    } catch (e) {
      print('[ProfileScreen] Error loading bank details: $e');
      if (mounted) {
        setState(() => _isLoadingBank = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bank details: $e')),
        );
      }
    }
  }

  void _loadBanksForLocation(String location) {
    setState(() {
      _availableBanks = BanksData.getBanksByCountry(location);
    });
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUpdatingProfile = true);

    try {
      final supabase = Supabase.instance.client;
      final uid = UserProfileService().profile?.uid;

      if (uid == null) {
        throw Exception('User not authenticated');
      }

      // Update profile in database
      await supabase.from('profiles').update({
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
      }).eq('id', uid);

      // Update email in Supabase Auth
      await supabase.auth.updateUser(
        UserAttributes(email: _emailController.text.trim()),
      );

      // Refresh profile in cache
      await UserProfileService().refreshProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingProfile = false);
      }
    }
  }

  Future<void> _updateBankDetails() async {
    if (!_bankFormKey.currentState!.validate()) return;
    
    if (_selectedLocation == null || _selectedLocation!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
      return;
    }
    
    if (_selectedBank == null || _selectedBank!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a bank')),
      );
      return;
    }

    // Validate short_code for UK banks
    if (_selectedLocation == 'UK') {
      if (_shortCodeController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Short code is required for UK banks')),
        );
        return;
      }
      if (_shortCodeController.text.trim().length != 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Short code must be exactly 6 digits')),
        );
        return;
      }
    }

    setState(() => _isUpdatingBank = true);

    try {
      await BankDetailsService.saveBankDetails(
        bankName: _selectedBank!,
        accountNumber: _accountNumberController.text.trim(),
        location: _selectedLocation!,
        accountName: _accountNameController.text.trim(),
        shortCode: _selectedLocation == 'UK' ? _shortCodeController.text.trim() : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bank details updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating bank details: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingBank = false);
      }
    }
  }

  void _navigateToUpdatePin() {
    Navigator.pushNamed(context, VerifyCurrentPinScreen.routeName);
  }

  Future<void> _showBankDetailDialog({BankDetails? existingDetail}) async {
    final formKey = GlobalKey<FormState>();
    String? selectedLocation = existingDetail?.location;
    String? selectedBank = existingDetail?.bankName;
    final accountNumberController = TextEditingController(text: existingDetail?.accountNumber ?? '');
    final accountNameController = TextEditingController(text: existingDetail?.accountName ?? '');
    final shortCodeController = TextEditingController(text: existingDetail?.shortCode ?? '');
    List<String> availableBanks = [];

    if (selectedLocation != null) {
      availableBanks = BanksData.getBanksByCountry(selectedLocation);
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: TitleText(
            existingDetail == null ? 'Add Bank Detail' : 'Edit Bank Detail',
            fontSize: 18,
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SecondaryText('Location', fontSize: 14),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedLocation,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: ['Philippines', 'UK'].map((location) {
                        return DropdownMenuItem<String>(
                          value: location,
                          child: Text(location),
                        );
                      }).toList(),
                      validator: (value) => value == null ? 'Required' : null,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedLocation = value;
                          selectedBank = null;
                          availableBanks = value != null ? BanksData.getBanksByCountry(value) : [];
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const SecondaryText('Bank Name', fontSize: 14),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedBank,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        hintText: selectedLocation == null ? 'Select location first' : 'Select bank',
                      ),
                      items: availableBanks.map((bank) {
                        return DropdownMenuItem<String>(
                          value: bank,
                          child: Text(
                            bank,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      validator: (value) => value == null ? 'Required' : null,
                      onChanged: selectedLocation == null ? null : (value) {
                        setDialogState(() {
                          selectedBank = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const SecondaryText('Account Number', fontSize: 14),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: accountNumberController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    const SecondaryText('Account Name', fontSize: 14),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: accountNameController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    if (selectedLocation == 'UK') ...[
                      const SizedBox(height: 16),
                      const SecondaryText('Short Code', fontSize: 14),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: shortCodeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          hintText: '6-digit short code',
                        ),
                        validator: (v) {
                          if (selectedLocation == 'UK') {
                            if (v == null || v.trim().isEmpty) return 'Required for UK banks';
                            if (v.trim().length != 6) return 'Must be 6 digits';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    if (existingDetail == null) {
                      // Add new
                      await BankDetailsService.addBankDetail(
                        bankName: selectedBank!,
                        accountNumber: accountNumberController.text.trim(),
                        location: selectedLocation!,
                        accountName: accountNameController.text.trim(),
                        shortCode: selectedLocation == 'UK' ? shortCodeController.text.trim() : null,
                      );
                    } else {
                      // Update existing
                      await BankDetailsService.updateBankDetail(
                        id: existingDetail.id,
                        bankName: selectedBank!,
                        accountNumber: accountNumberController.text.trim(),
                        location: selectedLocation!,
                        accountName: accountNameController.text.trim(),
                        shortCode: selectedLocation == 'UK' ? shortCodeController.text.trim() : null,
                      );
                    }
                    
                    Navigator.pop(context);
                    _loadBankDetails(); // Reload list
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(existingDetail == null ? 'Bank detail added!' : 'Bank detail updated!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                }
              },
              child: Text(existingDetail == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBankDetail(BankDetails detail) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bank Detail'),
        content: Text('Are you sure you want to delete ${detail.bankName} account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await BankDetailsService.deleteBankDetail(detail.id);
        _loadBankDetails(); // Reload list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bank detail deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // title: const TitleText('My Profile', fontSize: 20),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.titleColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: My Profile
            const TitleText(
              'My Profile',
              color: Colors.grey,
              fontSize: 19,
            ),
            const SizedBox(height: 16),
            
            if (_isLoadingProfile)
              const Center(child: CircularProgressIndicator())
            else
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SecondaryText('First Name', fontSize: 14),
                    const SizedBox(height: 8),
                    StyledTextfield(
                      controller: _firstNameController,
                      keyboardType: TextInputType.text,
                      label: 'Enter first name',
                    ),
                    const SizedBox(height: 16),
                    
                    const SecondaryText('Last Name', fontSize: 14),
                    const SizedBox(height: 8),
                    StyledTextfield(
                      controller: _lastNameController,
                      keyboardType: TextInputType.text,
                      label: 'Enter last name',
                    ),
                    const SizedBox(height: 16),
                    
                    const SecondaryText('Email Address', fontSize: 14),
                    const SizedBox(height: 8),
                    StyledTextfield(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      label: 'Enter email address',
                    ),
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: StyledButton(
                        onPressed: _isUpdatingProfile ? null : _updateProfile,
                        child: Text(_isUpdatingProfile ? 'Updating...' : 'Update my Profile'),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 40),
            
            // Section 2: Update Pin
            const TitleText(
              'Update Pin',
              color: Colors.grey,
              fontSize: 19,
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: StyledButton(
                onPressed: _navigateToUpdatePin,
                child: const Text('Change PIN'),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Section 3: Bank Details
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const TitleText(
                      'Bank Details',
                      color: Colors.grey,
                      fontSize: 19,
                    ),
                    const Spacer(),
                    if (_isAdmin)
                      IconButton(
                        onPressed: () => _showBankDetailDialog(),
                        icon: Icon(Icons.add_circle, color: AppColors.primaryColor),
                        tooltip: 'Add New Bank Detail',
                      ),
                  ],
                ),
                if (_isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/manage-banks')
                            .then((_) {
                              // Reload bank list after managing banks
                              if (_selectedLocation != null) {
                                _loadBanksForLocation(_selectedLocation!);
                              }
                            });
                      },
                      icon: Icon(Icons.settings, size: 16, color: AppColors.primaryColor),
                      label: PrimaryText('Manage Banks', fontSize: 13, color: AppColors.primaryColor),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_isLoadingBank)
              const Center(child: CircularProgressIndicator())
            else if (_isAdmin)
              // Admin view - List of bank details
              _allBankDetails.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.account_balance, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const SecondaryText(
                            'No bank details added yet',
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => _showBankDetailDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Bank Detail'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: _allBankDetails.map((detail) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Icon(
                              Icons.account_balance,
                              color: detail.location == 'Philippines' ? Colors.blue : Colors.red,
                            ),
                            title: TitleText(detail.bankName, fontSize: 15),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                SecondaryText(
                                  '${detail.accountName} • ${detail.location}',
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                                const SizedBox(height: 2),
                                SecondaryText(
                                  'Account: ${detail.accountNumber}',
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                if (detail.location == 'UK' && detail.shortCode != null) ...[
                                  const SizedBox(height: 2),
                                  SecondaryText(
                                    'Short Code: ${detail.shortCode}',
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  color: Colors.blue,
                                  onPressed: () => _showBankDetailDialog(existingDetail: detail),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  color: Colors.red,
                                  onPressed: () => _deleteBankDetail(detail),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    )
            else
              // Regular user view - Single bank detail form
              Form(
                key: _bankFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SecondaryText('Location', fontSize: 14),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(247, 249, 252, 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedLocation,
                        decoration: InputDecoration(
                          labelText: 'Select location',
                          labelStyle: TextStyle(
                            color: AppColors.titleColor.withOpacity(0.5),
                          ),
                          filled: true,
                          fillColor: const Color.fromRGBO(247, 249, 252, 1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                        ),
                        items: ['Philippines', 'UK'].map((location) {
                          return DropdownMenuItem<String>(
                            value: location,
                            child: Text(location),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedLocation = value;
                            _selectedBank = null; // Reset bank selection
                          });
                          if (value != null) {
                            _loadBanksForLocation(value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    const SecondaryText('Bank Name', fontSize: 14),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(247, 249, 252, 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedBank,
                        decoration: InputDecoration(
                          labelText: _selectedLocation == null 
                              ? 'Select location first'
                              : 'Select bank',
                          labelStyle: TextStyle(
                            color: AppColors.titleColor.withOpacity(0.5),
                          ),
                          filled: true,
                          fillColor: const Color.fromRGBO(247, 249, 252, 1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                        ),
                        items: _availableBanks.map((bank) {
                          return DropdownMenuItem<String>(
                            value: bank,
                            child: Text(bank),
                          );
                        }).toList(),
                        onChanged: _selectedLocation == null 
                            ? null 
                            : (value) {
                                setState(() {
                                  _selectedBank = value;
                                });
                              },
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    const SecondaryText('Account Number', fontSize: 14),
                    const SizedBox(height: 8),
                    StyledTextfield(
                      controller: _accountNumberController,
                      keyboardType: TextInputType.number,
                      label: 'Enter account number',
                    ),
                    const SizedBox(height: 16),
                    
                    const SecondaryText('Account Name', fontSize: 14),
                    const SizedBox(height: 8),
                    StyledTextfield(
                      controller: _accountNameController,
                      keyboardType: TextInputType.text,
                      label: 'Enter account name',
                    ),
                    const SizedBox(height: 16),
                    
                    // Short Code field - only for UK banks
                    if (_selectedLocation == 'UK') ...[
                      const SecondaryText('Short Code', fontSize: 14),
                      const SizedBox(height: 8),
                      StyledTextfield(
                        controller: _shortCodeController,
                        keyboardType: TextInputType.number,
                        label: 'Enter 6-digit short code',
                      ),
                      const SizedBox(height: 8),
                      const SecondaryText(
                        'UK banks require a 6-digit short code (sort code)',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: StyledButton(
                        onPressed: _isUpdatingBank ? null : _updateBankDetails,
                        child: Text(_isUpdatingBank ? 'Updating...' : 'Update Bank Details'),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

