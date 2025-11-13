import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateUserScreen extends StatefulWidget {
  static const routeName = '/create-user';
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _avatarUrlController = TextEditingController();
  bool _isAdmin = false;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
    });

    final supabase = Supabase.instance.client;
    try {
      // Call Edge Function to create user (has service role privileges)
      final response = await supabase.functions.invoke(
        'create-user',
        body: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'avatar_url': _avatarUrlController.text.trim(),
          'is_admin': _isAdmin,
        },
      );

      // Check for errors in response
      if (response.data != null && response.data['error'] != null) {
        throw Exception(response.data['error']);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User created successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Clear form
      _formKey.currentState!.reset();
      _emailController.clear();
      _passwordController.clear();
      _firstNameController.clear();
      _lastNameController.clear();
      _avatarUrlController.clear();
      setState(() {
        _isAdmin = false;
      });
    } on FunctionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Function error: ${e.details}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create user: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: TitleText('Create User', fontSize: 20),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.titleColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // First Name
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Last Name
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
              ),
              const SizedBox(height: 12),

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Password
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 12),

              // Avatar URL
              TextFormField(
                controller: _avatarUrlController,
                decoration: const InputDecoration(labelText: 'Avatar URL (optional)'),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Checkbox(
                    value: _isAdmin,
                    onChanged: (val) {
                      setState(() {
                        _isAdmin = val ?? false;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  PrimaryText('Is Admin', color: AppColors.titleColor),
                ],
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _createUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create User'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

