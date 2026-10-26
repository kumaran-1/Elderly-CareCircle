import 'package:flutter/material.dart';

import '../api_client.dart';
import '../responsive.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';

class ElderHomeScreen extends StatefulWidget {
  const ElderHomeScreen({super.key, required this.apiClient, required this.userName, required this.onViewHealth, required this.onViewMedication, required this.onOpenAiChat, required this.onOpenSos, required this.onViewProfile, required this.onViewHydration, required this.onViewExercise, required this.onOpenCarePlan});

  final ApiClient apiClient;
  final String userName;
  final VoidCallback onViewHealth;
  final VoidCallback onViewMedication;
  final VoidCallback onOpenAiChat;
  final VoidCallback onOpenSos;
  final VoidCallback onViewProfile;
  final VoidCallback onViewHydration;
  final VoidCallback onViewExercise;
  final VoidCallback onOpenCarePlan;

  @override
  State<ElderHomeScreen> createState() => _ElderHomeScreenState();
}

class _ElderHomeScreenState extends State<ElderHomeScreen> {
  Map<String, dynamic>? _dashboard;
  List<dynamic> _instructions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.apiClient.dashboard(),
        widget.apiClient.myInstructions(),
      ]);
      _dashboard = results[0];
      _instructions = (results[1]['instructions'] as List<dynamic>? ?? const []);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final cards = (_dashboard?['cards'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    final latestVital = cards.where((c) => c['label']?.toString().toLowerCase().contains('vital') == true).firstOrNull;
    final medication = cards.where((c) => c['label']?.toString().toLowerCase().contains('medication') == true).firstOrNull;
    final hydration = cards.where((c) => c['label']?.toString().toLowerCase().contains('hydration') == true).firstOrNull;
    final sosCount = cards.where((c) => c['label']?.toString().toLowerCase().contains('sos') == true).firstOrNull;

    return RefreshIndicator(
      onRefresh: _load,
      child: _isLoading
          ? const CCLoading()
          : _error != null
              ? CCError(message: _error!, onRetry: _load)
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    Responsive.horizontalPadding(context),
                    AppTheme.spacingXxl,
                    Responsive.horizontalPadding(context),
                    AppTheme.spacingXxl2,
                  ),
                  children: [
                    _buildGreeting(),
                    const SizedBox(height: AppTheme.spacingXxl),
                    _buildSosButton(),
                    const SizedBox(height: AppTheme.spacingXxl),
                    _buildTodaySummary(latestVital, medication, hydration, sosCount),
                    if (_instructions.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spacingXl),
                      _buildInstructionsSection(),
                    ],
                    const SizedBox(height: AppTheme.spacingXl),
                    _buildQuickActions(),
                  ],
                ),
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_greeting()},',
          style: const TextStyle(fontSize: AppTheme.fontSizeHero, fontWeight: FontWeight.w700, color: AppTheme.ink, height: 1.2),
        ),
        const SizedBox(height: AppTheme.spacingXs),
        Text(
          widget.userName,
          style: const TextStyle(fontSize: AppTheme.fontSizeDisplay, fontWeight: FontWeight.w900, color: AppTheme.ink, height: 1.1),
        ),
      ],
    );
  }

  Widget _buildSosButton() {
    return SizedBox(
      width: double.infinity,
      height: 80,
      child: ElevatedButton(
        onPressed: widget.onOpenSos,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.sosRed,
          foregroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXLarge)),
          elevation: 4,
          shadowColor: AppTheme.sosRed.withValues(alpha: 0.4),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 36),
            SizedBox(width: AppTheme.spacingMd),
            Text(
              'EMERGENCY SOS',
              style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySummary(Map<String, dynamic>? latestVital, Map<String, dynamic>? medication, Map<String, dynamic>? hydration, Map<String, dynamic>? sosCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Today's Summary", style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        const SizedBox(height: AppTheme.spacingLg),
        _summaryRow(
          icon: Icons.monitor_heart,
          label: 'Latest Vital',
          value: latestVital?['value']?.toString() ?? 'No readings yet',
          tone: toneFromString(latestVital?['tone']?.toString() ?? 'normal'),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _summaryRow(
          icon: Icons.medication,
          label: 'Medication',
          value: medication?['value']?.toString() ?? 'No data',
          tone: toneFromString(medication?['tone']?.toString() ?? 'normal'),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _summaryRow(
          icon: Icons.water_drop,
          label: 'Hydration',
          value: hydration?['value']?.toString() ?? 'No data',
          tone: toneFromString(hydration?['tone']?.toString() ?? 'normal'),
        ),
        if (sosCount != null && (int.tryParse(sosCount['value']?.toString() ?? '0') ?? 0) > 0) ...[
          const SizedBox(height: AppTheme.spacingMd),
          _summaryRow(
            icon: Icons.error,
            label: 'Active Alerts',
            value: sosCount['value']?.toString() ?? '0',
            tone: AppTheme.sosRed,
          ),
        ],
      ],
    );
  }

  Widget _summaryRow({required IconData icon, required String label, required String value, required Color tone}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXl, vertical: AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: tone.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: tone, size: 28),
          const SizedBox(width: AppTheme.spacingLg),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: AppTheme.fontSizeXl, color: AppTheme.ink, fontWeight: FontWeight.w600)),
          ),
          Text(value, style: TextStyle(fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.w800, color: tone)),
        ],
      ),
    );
  }

  Widget _buildInstructionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Care Instructions', style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        const SizedBox(height: AppTheme.spacingLg),
        ..._instructions.take(3).map((i) => Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: AppTheme.teal.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        i['title']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppTheme.fontSizeLg, color: AppTheme.ink),
                      ),
                    ),
                    PriorityBadge(priority: i['priority']?.toString() ?? 'low'),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  i['message']?.toString() ?? '',
                  style: const TextStyle(fontSize: AppTheme.fontSizeMd, color: AppTheme.muted),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  formatDateTime(i['createdAt']?.toString() ?? ''),
                  style: const TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.subtle),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        const SizedBox(height: AppTheme.spacingLg),
        Row(
          children: [
            Expanded(child: _actionButton(icon: Icons.monitor_heart, label: 'Health', onTap: widget.onViewHealth)),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(child: _actionButton(icon: Icons.medication, label: 'Medicine', onTap: widget.onViewMedication)),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Row(
          children: [
            Expanded(child: _actionButton(icon: Icons.water_drop, label: 'Hydration', onTap: widget.onViewHydration)),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(child: _actionButton(icon: Icons.fitness_center, label: 'Exercise', onTap: widget.onViewExercise)),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Row(
          children: [
            Expanded(child: _actionButton(icon: Icons.smart_toy, label: 'Ask AI', onTap: widget.onOpenAiChat)),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(child: _actionButton(icon: Icons.assignment_turned_in, label: 'Care Plan', onTap: widget.onOpenCarePlan)),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),
        SizedBox(
          width: double.infinity,
          child: _actionButton(icon: Icons.person, label: 'Profile', onTap: widget.onViewProfile),
        ),
      ],
    );
  }

  Widget _actionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return SizedBox(
      height: 80,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.surface,
          foregroundColor: AppTheme.teal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            side: const BorderSide(color: AppTheme.surfaceBorder),
          ),
          elevation: 0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: AppTheme.spacingSm),
            Text(label, style: const TextStyle(fontSize: AppTheme.fontSizeLg, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
