import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.apiClient, required this.onAuthenticated, required this.onBack});

  final ApiClient apiClient;
  final VoidCallback onAuthenticated;
  final VoidCallback onBack;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  String? _errorMessage;
  String _selectedRole = 'family';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final response = await widget.apiClient.register(
        name: _nameController.text.trim(),
        email: email,
        password: _passwordController.text,
        role: _selectedRole,
      );
      if (!mounted) return;

      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _OtpDialog(
          apiClient: widget.apiClient,
          email: email,
          suggestedCode: response['otpCode']?.toString(),
        ),
      );
      if (verified != true || !mounted) return;

      widget.onAuthenticated();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      setState(() => _errorMessage = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border.all(color: const Color(0xFFD7E3DD)),
                    boxShadow: const [BoxShadow(color: Color(0x1A18332B), blurRadius: 28, offset: Offset(0, 18))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: widget.onBack,
                                  icon: const Icon(Icons.arrow_back, color: AppTheme.ink),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Create Account',
                                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.ink),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Join CareCircle to connect with your care team.',
                              style: TextStyle(color: AppTheme.muted),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) return 'Name is required.';
                                if ((value ?? '').trim().length < 2) return 'Name must be at least 2 characters.';
                                return null;
                              },
                              decoration: const InputDecoration(labelText: 'Full Name'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty) return 'Email is required.';
                                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                                  return 'Enter a valid email address.';
                                }
                                return null;
                              },
                              decoration: const InputDecoration(labelText: 'Email'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_showPassword,
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                final password = value ?? '';
                                if (password.isEmpty) return 'Password is required.';
                                if (password.length < 8) return 'Password must be at least 8 characters.';
                                if (!RegExp(r'[A-Z]').hasMatch(password)) {
                                  return 'Password must contain at least one uppercase letter.';
                                }
                                if (!RegExp(r'[a-z]').hasMatch(password)) {
                                  return 'Password must contain at least one lowercase letter.';
                                }
                                if (!RegExp(r'[0-9]').hasMatch(password)) {
                                  return 'Password must contain at least one number.';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: 'Password',
                                suffixIcon: IconButton(
                                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _showPassword = !_showPassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('I am a...', style: TextStyle(color: AppTheme.muted, fontSize: 14)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _roleChip('Elder', 'elder'),
                                const SizedBox(width: 8),
                                _roleChip('Family', 'family'),
                                const SizedBox(width: 8),
                                _roleChip('Caregiver', 'caregiver'),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _register,
                                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                                child: Text(_isLoading ? 'Please wait...' : 'Create Account'),
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Text(_errorMessage!, style: const TextStyle(color: AppTheme.danger)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleChip(String label, String value) {
    final selected = _selectedRole == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accent : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppTheme.accent : const Color(0xFFD7E3DD)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.ink,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpDialog extends StatefulWidget {
  const _OtpDialog({
    required this.apiClient,
    required this.email,
    this.suggestedCode,
  });

  final ApiClient apiClient;
  final String email;
  final String? suggestedCode;

  @override
  State<_OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<_OtpDialog> {
  late final TextEditingController _controller;
  bool _isVerifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.suggestedCode ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit verification code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      await widget.apiClient.verifyOtp(widget.email, code);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verify your email'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the 6-digit code sent to ${widget.email}.',
            style: const TextStyle(color: AppTheme.muted),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Verification code',
              hintText: '000000',
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: AppTheme.fontSizeSm)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isVerifying ? null : _verify,
          child: _isVerifying
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Verify'),
        ),
      ],
    );
  }
}
