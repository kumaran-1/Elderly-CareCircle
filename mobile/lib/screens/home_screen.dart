import 'package:flutter/material.dart';

import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.loginBuilder});

  final WidgetBuilder loginBuilder;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedRole = 'Elder';

  @override
  Widget build(BuildContext context) {
    final role = _roleDetails(selectedRole);
    final isWide = MediaQuery.of(context).size.width >= 650;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F8F6), Color(0xFFE4F1EA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                children: [
                  const Text('CareCircle', style: TextStyle(color: AppTheme.ink, fontSize: 38, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('Care that stays connected.', style: TextStyle(color: AppTheme.muted, fontSize: 19)),
                  const SizedBox(height: 30),
                  const Text('Choose your view', style: TextStyle(color: AppTheme.ink, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: isWide ? 1.55 : 1.3,
                    children: _roles.map((item) => _RoleCard(
                          label: item,
                          selected: selectedRole == item,
                          details: _roleDetails(item),
                          onTap: () => setState(() => selectedRole = item),
                        )).toList(),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: role.color.withValues(alpha: 0.7), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(role.icon, color: role.color, size: 30),
                            const SizedBox(width: 12),
                            Expanded(child: Text(role.title, style: const TextStyle(color: AppTheme.ink, fontSize: 23, fontWeight: FontWeight.w800))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(role.description, style: const TextStyle(color: AppTheme.muted, fontSize: 16, height: 1.4)),
                        const SizedBox(height: 16),
                        ...role.priorities.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: role.color, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(item, style: const TextStyle(color: AppTheme.ink, fontSize: 16))),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: widget.loginBuilder)),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text('Continue as $selectedRole'),
                      style: FilledButton.styleFrom(
                        backgroundColor: role.color,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Your health information is shared only with your CareCircle.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _roles = ['Elder', 'Family', 'Caregiver', 'Admin'];

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.label, required this.selected, required this.details, required this.onTap});

  final String label;
  final bool selected;
  final _RoleDetails details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label role',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? details.color.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? details.color : Color(0xFFD7E3DD), width: selected ? 2 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(details.icon, color: selected ? details.color : AppTheme.muted, size: 30),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: selected ? AppTheme.ink : AppTheme.muted, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleDetails {
  const _RoleDetails({required this.title, required this.description, required this.priorities, required this.icon, required this.color});

  final String title;
  final String description;
  final List<String> priorities;
  final IconData icon;
  final Color color;
}

_RoleDetails _roleDetails(String role) {
  switch (role) {
    case 'Family':
      return const _RoleDetails(
        title: 'Stay close, even from far away.',
        description: 'Follow linked elders, alerts, reports, and care updates.',
        priorities: ['View linked elder status', 'Review important alerts', 'Open health reports'],
        icon: Icons.family_restroom,
        color: AppTheme.warning,
      );
    case 'Caregiver':
      return const _RoleDetails(
        title: 'Every task, in one place.',
        description: 'Move through client tasks quickly and record care accurately.',
        priorities: ['Choose a client', 'Complete today\'s tasks', 'Keep the CareCircle updated'],
        icon: Icons.medical_services,
        color: Color(0xFF7DD3FC),
      );
    case 'Admin':
      return const _RoleDetails(
        title: 'Clear oversight, protected privacy.',
        description: 'Monitor platform operations without accessing private health details.',
        priorities: ['Review platform activity', 'Manage accounts', 'Protect elder privacy'],
        icon: Icons.admin_panel_settings,
        color: Color(0xFFC4B5FD),
      );
    default:
      return const _RoleDetails(
        title: 'Your daily care, made simple.',
        description: 'See what matters today with clear, comfortable controls.',
        priorities: ['Log a health reading', 'Check medication', 'Get help quickly with SOS'],
        icon: Icons.elderly,
        color: AppTheme.accent,
      );
  }
}
