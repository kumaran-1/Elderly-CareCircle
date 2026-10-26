import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';
import 'ai_chat_screen.dart';
import 'care_circle_screen.dart';
import 'care_plan_screen.dart';
import 'elder_home_screen.dart';
import 'exercise_screen.dart';
import 'hydration_screen.dart';
import 'medications_screen.dart';
import 'profile_screen.dart';
import 'vitals_screen.dart';

class ElderShell extends StatefulWidget {
  const ElderShell({super.key, required this.apiClient, required this.onLogout});

  final ApiClient apiClient;
  final Future<void> Function() onLogout;

  @override
  State<ElderShell> createState() => _ElderShellState();
}

class _ElderShellState extends State<ElderShell> {
  int _currentIndex = 0;
  String? _userName;
  String? _elderId;
  String? _error;
  List<Widget>? _screens;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() {
      _error = null;
    });
    try {
      final me = await widget.apiClient.me();
      if (!mounted) return;
      setState(() {
        _userName = me['user']?['name']?.toString() ?? '';
        _elderId = me['user']?['id']?.toString() ?? '';
        _buildScreens();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _buildScreens() {
    final elderId = _elderId ?? '';
    _screens = [
      ElderHomeScreen(
        apiClient: widget.apiClient,
        userName: _userName ?? '',
        onViewHealth: () => setState(() => _currentIndex = 1),
        onViewMedication: () => setState(() => _currentIndex = 2),
        onOpenAiChat: () => setState(() => _currentIndex = 3),
        onOpenSos: _openSos,
        onViewProfile: () => setState(() => _currentIndex = 5),
        onViewHydration: _openHydration,
        onViewExercise: _openExercise,
        onOpenCarePlan: _openCarePlan,
      ),
      VitalsScreen(apiClient: widget.apiClient, elderId: elderId),
      MedicationsScreen(apiClient: widget.apiClient, elderId: elderId),
      AiChatScreen(apiClient: widget.apiClient, elderId: elderId),
      CareCircleScreen(apiClient: widget.apiClient),
      ProfileScreen(apiClient: widget.apiClient, onLogout: widget.onLogout),
    ];
  }

  void _openSos() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ElderSosScreen(apiClient: widget.apiClient, elderId: _elderId ?? ''),
    ));
  }

  void _openHydration() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HydrationScreen(apiClient: widget.apiClient, elderId: _elderId ?? ''),
    ));
  }

  void _openExercise() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ExerciseScreen(apiClient: widget.apiClient, elderId: _elderId ?? ''),
    ));
  }

  void _openCarePlan() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CarePlanScreen(
        apiClient: widget.apiClient,
        elderId: _elderId ?? '',
        elderName: _userName ?? '',
        canManage: false,
        showJournal: false,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _screens == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: CCError(message: _error!, onRetry: _loadUser),
      );
    }
    if (_screens == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: CCLoading(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens!,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.teal.withValues(alpha: 0.12),
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, size: 26),
            selectedIcon: Icon(Icons.home, size: 26),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined, size: 26),
            selectedIcon: Icon(Icons.monitor_heart, size: 26),
            label: 'Health',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined, size: 26),
            selectedIcon: Icon(Icons.medication, size: 26),
            label: 'Medicine',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined, size: 26),
            selectedIcon: Icon(Icons.smart_toy, size: 26),
            label: 'AI Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined, size: 26),
            selectedIcon: Icon(Icons.groups, size: 26),
            label: 'Circle',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, size: 26),
            selectedIcon: Icon(Icons.person, size: 26),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ElderSosScreen extends StatefulWidget {
  const _ElderSosScreen({required this.apiClient, required this.elderId});

  final ApiClient apiClient;
  final String elderId;

  @override
  State<_ElderSosScreen> createState() => _ElderSosScreenState();
}

class _ElderSosScreenState extends State<_ElderSosScreen> {
  bool _triggering = false;
  int _countdown = 5;
  bool _countdownActive = false;

  Future<void> _triggerSos() async {
    setState(() {
      _countdownActive = true;
      _countdown = 5;
    });

    for (int i = 5; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
    }

    setState(() {
      _countdownActive = false;
      _triggering = true;
    });

    try {
      await widget.apiClient.triggerSos(elderId: widget.elderId, location: 'Mobile app');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS alert sent. Your CareCircle has been notified.'),
            backgroundColor: AppTheme.sosRed,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send SOS: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.sosRed,
          ),
        );
        setState(() => _triggering = false);
      }
    }
  }

  void _cancel() {
    setState(() {
      _countdownActive = false;
      _countdown = 5;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _countdownActive ? AppTheme.sosRedLight : AppTheme.background,
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        foregroundColor: AppTheme.sosRed,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_countdownActive) ...[
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppTheme.sosRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$_countdown',
                      style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: AppTheme.sosRed),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Sending SOS alert...',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.sosRed),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your CareCircle will be notified.',
                  style: TextStyle(fontSize: 18, color: AppTheme.muted),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: OutlinedButton(
                    onPressed: _cancel,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.muted, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('CANCEL', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.muted)),
                  ),
                ),
              ] else if (_triggering) ...[
                const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(strokeWidth: 4, color: AppTheme.sosRed),
                ),
                const SizedBox(height: 24),
                const Text('Sending alert...', style: TextStyle(fontSize: 22, color: AppTheme.sosRed)),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: AppTheme.sosRedLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: AppTheme.sosRed, size: 80),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Emergency SOS',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppTheme.ink),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Press the button below to alert your CareCircle immediately.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: AppTheme.muted, height: 1.4),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: ElevatedButton(
                    onPressed: _triggerSos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.sosRed,
                      foregroundColor: AppTheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 4,
                    ),
                    child: const Text(
                      'TRIGGER SOS',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
