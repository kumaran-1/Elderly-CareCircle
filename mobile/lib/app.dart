import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'screens/caregiver_shell.dart';
import 'screens/elder_shell.dart';
import 'screens/family_shell.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

class CareCircleApp extends StatefulWidget {
  const CareCircleApp({super.key});

  @override
  State<CareCircleApp> createState() => _CareCircleAppState();
}

class _CareCircleAppState extends State<CareCircleApp> {
  ApiClient? _apiClient;
  bool? _authenticated;
  String? _role;
  String? _startupError;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _startupError = null;
      _loginError = null;
      _authenticated = null;
    });

    try {
      final endpointStore = ApiEndpointStore();
      final storedOverride = await endpointStore.readOverride();
      final baseUrl = resolveApiBaseUrl(storedOverride: storedOverride);
      final client = ApiClient(baseUrl: baseUrl);
      final restored = await client.restoreSession();

      if (!mounted) return;
      setState(() => _apiClient = client);

      if (restored) {
        await _loadUser(client);
      } else {
        setState(() => _authenticated = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _startupError = _message(error);
        _authenticated = false;
      });
    }
  }

  Future<void> _loadUser(ApiClient client) async {
    try {
      final payload = await client.me();
      final user = payload['user'] as Map<String, dynamic>?;
      final role = user?['role']?.toString();

      if (role == null || role == 'admin') {
        await client.signOut();
        if (!mounted) return;
        setState(() {
          _authenticated = false;
          _role = null;
          _startupError = null;
          _loginError = role == 'admin'
              ? 'Admin accounts are not available in the CareCircle mobile app.'
              : 'Your account role could not be determined. Please sign in again.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _authenticated = true;
        _role = role;
        _startupError = null;
        _loginError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _authenticated = false;
        _role = null;
        _startupError = null;
        _loginError = _message(error);
      });
    }
  }

  Future<void> _handleAuthenticated() async {
    final client = _apiClient;
    if (client == null) return;
    setState(() {
      _authenticated = null;
      _startupError = null;
      _loginError = null;
    });
    await _loadUser(client);
  }

  Future<void> _handleLogout() async {
    await _apiClient?.signOut();
    if (!mounted) return;
    setState(() {
      _authenticated = false;
      _role = null;
      _loginError = null;
    });
  }

  Widget _buildAuthenticatedHome() {
    final client = _apiClient;
    if (client == null) {
      return _StartupErrorScreen(
          message: _startupError ?? 'Server configuration is unavailable.',
          onRetry: _bootstrap);
    }

    switch (_role) {
      case 'elder':
        return ElderShell(apiClient: client, onLogout: _handleLogout);
      case 'family':
        return FamilyShell(apiClient: client, onLogout: _handleLogout);
      case 'caregiver':
        return CaregiverShell(apiClient: client, onLogout: _handleLogout);
      default:
        return _RoleErrorScreen(onLogout: _handleLogout);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CareCircle',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: AppTheme.colorScheme,
        textTheme: textTheme.apply(
            bodyColor: AppTheme.ink, displayColor: AppTheme.ink),
        scaffoldBackgroundColor: AppTheme.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppTheme.background,
          foregroundColor: AppTheme.ink,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: AppTheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppTheme.surface,
          labelStyle: const TextStyle(color: AppTheme.muted),
          hintStyle: const TextStyle(color: AppTheme.muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: const BorderSide(color: AppTheme.surfaceBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: const BorderSide(color: AppTheme.surfaceBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: const BorderSide(color: AppTheme.teal, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.teal,
            side: const BorderSide(color: AppTheme.surfaceBorder),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
          ),
        ),
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    final client = _apiClient;
    if (client == null) {
      return _StartupErrorScreen(
        message: _startupError ?? 'Server configuration is unavailable.',
        onRetry: _bootstrap,
      );
    }

    if (_authenticated == null) {
      return const _SplashScreen();
    }

    if (_authenticated == true) {
      return _buildAuthenticatedHome();
    }

    return HomeScreen(
      errorMessage: _loginError,
      loginBuilder: (context) => LoginScreen(
        apiClient: client,
        initialError: _loginError,
        onAuthenticated: _handleAuthenticated,
        onBack: () => Navigator.of(context).pop(),
      ),
    );
  }

  String _message(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(),
            ),
            SizedBox(height: 16),
            Text('Restoring CareCircle session...',
                style: TextStyle(color: AppTheme.muted)),
          ],
        ),
      ),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 56, color: AppTheme.muted),
                const SizedBox(height: AppTheme.spacingLg),
                const Text(
                  'Unable to connect',
                  style: TextStyle(
                      fontSize: AppTheme.fontSizeXxl,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.muted)),
                const SizedBox(height: AppTheme.spacingXl),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleErrorScreen extends StatelessWidget {
  const _RoleErrorScreen({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_off_outlined,
                    size: 56, color: AppTheme.muted),
                const SizedBox(height: AppTheme.spacingLg),
                const Text(
                  'Unsupported account',
                  style: TextStyle(
                      fontSize: AppTheme.fontSizeXxl,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                const Text(
                  'This account does not have an elder, family, or caregiver role.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: AppTheme.spacingXl),
                FilledButton(
                    onPressed: onLogout, child: const Text('Sign out')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
