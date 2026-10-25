import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.apiClient, required this.onLogout});

  final ApiClient apiClient;
  final Future<void> Function() onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? dashboard;
  Map<String, dynamic>? me;
  Map<String, dynamic>? notifications;
  String? errorMessage;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final results = await Future.wait([
        widget.apiClient.me(),
        widget.apiClient.dashboard(),
        widget.apiClient.notifications(),
      ]);
      me = results[0];
      dashboard = results[1];
      notifications = results[2];
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _openAction(String action, String elderId) async {
    if (action == 'SOS') {
      final shouldTrigger = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Trigger SOS?'),
          content: const Text('This will alert the connected CareCircle. Use this for an urgent situation.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Trigger SOS')),
          ],
        ),
      );
      if (shouldTrigger == true) {
        await _runAction(() => widget.apiClient.triggerSos(elderId: elderId, location: 'Mobile app'));
      }
      return;
    }

    if (action == 'Medication') {
      await _runAction(() => widget.apiClient.medicationSummary(elderId), showSummary: true);
      return;
    }

    if (action == 'Reports') {
      await _runAction(() => widget.apiClient.reportSummary(elderId), showSummary: true);
      return;
    }

    if (action == 'Care Circle') {
      await _runAction(widget.apiClient.myCareCircles, showSummary: true);
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: action == 'Log vitals' || action == 'Hydration' || action == 'Exercise' ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            labelText: action == 'Log vitals' ? 'Systolic blood pressure' : action == 'Hydration' ? 'Amount in ml' : action == 'Exercise' ? 'Minutes exercised' : 'Question',
            hintText: action == 'Log vitals'
              ? 'Example: 128'
              : action == 'Hydration'
                ? 'Example: 250'
                : action == 'Exercise'
                  ? 'Minutes walked'
                  : action == 'Appointments'
                    ? 'Doctor | Specialty | ISO date-time'
                    : 'Describe how you feel',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Continue')),
        ],
      ),
    );
    controller.dispose();

    if (result == null || result.isEmpty) {
      return;
    }

    if (action == 'Log vitals') {
      final value = double.tryParse(result);
      if (value == null) {
        _showMessage('Enter a valid blood pressure value.');
        return;
      }
      await _runAction(() => widget.apiClient.logVital(elderId: elderId, type: 'bloodPressure', value: value, unit: 'mmHg', systolic: value));
    } else if (action == 'Hydration') {
      final amount = double.tryParse(result);
      if (amount == null) {
        _showMessage('Enter a valid hydration amount.');
        return;
      }
      await _runAction(() => widget.apiClient.logHydration(elderId: elderId, amountMl: amount));
    } else if (action == 'Exercise') {
      final minutes = double.tryParse(result);
      if (minutes == null) {
        _showMessage('Enter a valid exercise duration.');
        return;
      }
      await _runAction(() => widget.apiClient.logExercise(elderId: elderId, activityType: 'Walking', minutes: minutes));
    } else if (action == 'Appointments') {
      final fields = result.split('|').map((field) => field.trim()).toList();
      if (fields.length != 3 || DateTime.tryParse(fields[2]) == null) {
        _showMessage('Use: Doctor | Specialty | ISO date-time.');
        return;
      }
      await _runAction(() => widget.apiClient.createAppointment(
            elderId: elderId,
            doctorName: fields[0],
            specialty: fields[1],
            dateTime: DateTime.parse(fields[2]).toUtc().toIso8601String(),
          ));
    } else if (action == 'AI Assistant') {
      await _runAction(() => widget.apiClient.askAi(elderId: elderId, question: result), showResponse: true);
    }
  }

  Future<void> _runAction(Future<Map<String, dynamic>> Function() operation, {bool showResponse = false, bool showSummary = false}) async {
    try {
      final response = await operation();
      if (!mounted) {
        return;
      }
      await _load();
      if (showResponse || showSummary) {
        final conversation = response['conversation'] as Map<String, dynamic>?;
        _showMessage(conversation?['answer']?.toString() ?? response['summary']?.toString() ?? 'No summary was returned.');
      } else {
        _showMessage('CareCircle updated successfully.');
      }
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = me?['user'] as Map<String, dynamic>?;
    final cards = (dashboard?['cards'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    final actions = (dashboard?['actions'] as List<dynamic>? ?? const []).cast<String>();
    final alerts = (notifications?['notifications'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    final role = user?['role']?.toString() ?? 'guest';
    final displayName = user?['name']?.toString() ?? 'CareCircle User';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('CareCircle'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: () => widget.onLogout(), icon: const Icon(Icons.logout)),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.redAccent)))
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    _HeaderCard(displayName: displayName, role: role, subtitle: dashboard?['title']?.toString() ?? 'Role dashboard'),
                    const SizedBox(height: 16),
                    _SectionTitle(title: 'Daily Snapshot', action: TextButton(onPressed: _load, child: const Text('Refresh'))),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.55,
                      children: cards
                          .map(
                            (card) => _MetricCard(
                              label: card['label'].toString(),
                              value: card['value'].toString(),
                              tone: _toneFromString(card['tone'].toString()),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    const _SectionTitle(title: 'Available actions'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: actions
                          .map(
                            (action) => ActionChip(
                              avatar: Icon(_actionIcon(action), size: 16),
                              label: Text(action),
                              side: const BorderSide(color: Color(0xFFD7E3DD)),
                              backgroundColor: const Color(0xFFFFFFFF),
                              labelStyle: const TextStyle(color: AppTheme.ink),
                              onPressed: user?['id'] == null ? null : () => _openAction(action, user!['id'].toString()),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    const _SectionTitle(title: 'Latest notifications'),
                    const SizedBox(height: 10),
                    ...alerts.take(6).map(
                          (item) => _NotificationCard(
                            title: item['title'].toString(),
                            body: item['body'].toString(),
                            category: item['category'].toString(),
                          ),
                        ),
                  ],
                ),
    );
  }
}

IconData _actionIcon(String action) {
  switch (action) {
    case 'Log vitals':
      return Icons.monitor_heart;
    case 'Medication':
      return Icons.medication;
    case 'Hydration':
      return Icons.water_drop;
    case 'AI Assistant':
      return Icons.smart_toy;
    case 'SOS':
      return Icons.warning_amber;
    case 'Reports':
      return Icons.assessment;
    default:
      return Icons.arrow_forward;
  }
}

Color _toneFromString(String tone) {
  switch (tone) {
    case 'alert':
      return AppTheme.danger;
    case 'attention':
      return AppTheme.warning;
    default:
      return AppTheme.accent;
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.displayName, required this.role, required this.subtitle});

  final String displayName;
  final String role;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFEAF5EE)]),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Color(0xFFD7E3DD)),
        boxShadow: const [BoxShadow(color: Color(0x1A18332B), blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(displayName, style: const TextStyle(color: AppTheme.ink, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('$role • $subtitle', style: const TextStyle(color: AppTheme.muted, height: 1.3)),
          const SizedBox(height: 12),
          const Text('CareCircle surfaces the right actions for the selected role.', style: TextStyle(color: AppTheme.muted)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink))),
        if (action != null) action!,
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: tone, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: AppTheme.ink, fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.title, required this.body, required this.category});

  final String title;
  final String body;
  final String category;

  @override
  Widget build(BuildContext context) {
    final tone = category == 'sos'
        ? AppTheme.danger
        : category == 'vital' || category == 'medication'
            ? AppTheme.warning
            : AppTheme.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 12, height: 12, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: tone, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: AppTheme.muted, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(category.toUpperCase(), style: TextStyle(color: tone, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
