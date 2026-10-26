import 'package:flutter/material.dart';
import 'register_screen.dart';
import '../api_client.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen(
      {super.key,
      required this.apiClient,
      required this.onAuthenticated,
      required this.onBack,
      this.initialError});

  final ApiClient apiClient;
  final VoidCallback onAuthenticated;
  final VoidCallback onBack;
  final String? initialError;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController(text: 'rajendran@example.com');
  final passwordController = TextEditingController(text: 'Password123!');
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    errorMessage = widget.initialError;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await widget.apiClient
          .login(emailController.text.trim(), passwordController.text);
      widget.onAuthenticated();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() =>
            errorMessage = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F8F6), Color(0xFFE4F1EA), Color(0xFFF5F8F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFD7E3DD)),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x1A18332B),
                            blurRadius: 28,
                            offset: Offset(0, 18))
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: widget.onBack,
                                icon: const Icon(Icons.arrow_back,
                                    color: AppTheme.ink),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('CareCircle Access',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.ink)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sign in with your email and password to enter the dashboard.',
                            style: TextStyle(color: AppTheme.muted),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration:
                                const InputDecoration(labelText: 'Email'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            decoration:
                                const InputDecoration(labelText: 'Password'),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: isLoading ? null : login,
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Sign In'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Don't have an account?"),
                              TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => RegisterScreen(
                                              apiClient: widget.apiClient,
                                              onAuthenticated:
                                                  widget.onAuthenticated,
                                              onBack: () =>
                                                  Navigator.of(context).pop(),
                                            ),
                                          ),
                                        );
                                      },
                                child: const Text('Register'),
                              ),
                            ],
                          ),
                          if (errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(errorMessage!,
                                style:
                                    const TextStyle(color: Colors.redAccent)),
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
    );
  }
}
