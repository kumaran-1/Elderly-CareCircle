import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'api_client.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

class CareCircleApp extends StatefulWidget {
  const CareCircleApp({super.key});

  @override
  State<CareCircleApp> createState() => _CareCircleAppState();
}

class _CareCircleAppState extends State<CareCircleApp> {
  final apiClient = ApiClient(
    baseUrl: const String.fromEnvironment(
      'CARECIRCLE_API_BASE_URL',
      defaultValue: 'http://localhost:4000',
    ),
  );
  bool? authenticated;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final restored = await apiClient.restoreSession();
    if (!mounted) {
      return;
    }

    setState(() {
      authenticated = restored;
    });
  }

  void _handleAuthenticated() {
    setState(() {
      authenticated = true;
    });
  }

  Future<void> _handleLogout() async {
    await apiClient.signOut();
    setState(() {
      authenticated = false;
    });
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
        textTheme: textTheme,
        scaffoldBackgroundColor: AppTheme.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppTheme.background,
          foregroundColor: AppTheme.ink,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppTheme.background,
          labelStyle: const TextStyle(color: AppTheme.muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFFD7E3DD)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFFD7E3DD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: AppTheme.accent, width: 2),
          ),
        ),
      ),
      home: authenticated == null
          ? const _SplashScreen()
          : authenticated == true
              ? DashboardScreen(apiClient: apiClient, onLogout: _handleLogout)
              : HomeScreen(
                  loginBuilder: (context) => LoginScreen(
                    apiClient: apiClient,
                    onAuthenticated: _handleAuthenticated,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
    );
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
            Text('Restoring CareCircle session...', style: TextStyle(color: AppTheme.muted)),
          ],
        ),
      ),
    );
  }
}
