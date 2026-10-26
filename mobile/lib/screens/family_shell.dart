import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import 'care_circle_screen.dart';
import 'family_dashboard.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class FamilyShell extends StatefulWidget {
  const FamilyShell({super.key, required this.apiClient, required this.onLogout});

  final ApiClient apiClient;
  final Future<void> Function() onLogout;

  @override
  State<FamilyShell> createState() => _FamilyShellState();
}

class _FamilyShellState extends State<FamilyShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          FamilyDashboard(apiClient: widget.apiClient, onLogout: widget.onLogout),
          CareCircleScreen(apiClient: widget.apiClient),
          NotificationsScreen(apiClient: widget.apiClient),
          ProfileScreen(apiClient: widget.apiClient, onLogout: widget.onLogout),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
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
            icon: Icon(Icons.groups_outlined, size: 26),
            selectedIcon: Icon(Icons.groups, size: 26),
            label: 'Circle',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined, size: 26),
            selectedIcon: Icon(Icons.notifications, size: 26),
            label: 'Alerts',
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
