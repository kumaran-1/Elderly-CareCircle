import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key, required this.apiClient, required this.elderId});

  final ApiClient apiClient;
  final String elderId;

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  Map<String, dynamic>? _data;
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
      _data = await widget.apiClient.medicationSummary(widget.elderId);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = (_data?['plans'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    final activePlans = plans.where((p) => p['active'] == true).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Medications'),
        actions: [
          IconButton(onPressed: _openAddMedicationDialog, icon: const Icon(Icons.add), tooltip: 'Add medication'),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: activePlans.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _openLogDoseDialog(activePlans),
              backgroundColor: AppTheme.teal,
              foregroundColor: AppTheme.surface,
              icon: const Icon(Icons.add),
              label: const Text('Log Dose'),
            )
          : null,
      body: _isLoading
          ? const CCLoading()
          : _error != null
              ? CCError(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppTheme.spacingXl),
                    children: [
                      _buildAdherenceCard(),
                      const SizedBox(height: AppTheme.spacingXl),
                      const Text('Medication Plans', style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                      const SizedBox(height: AppTheme.spacingMd),
                      ..._buildPlans(),
                      const SizedBox(height: AppTheme.spacingXl),
                      const Text('Recent Logs', style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                      const SizedBox(height: AppTheme.spacingMd),
                      ..._buildLogs(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildAdherenceCard() {
    final summary = _data?['summary'] as Map<String, dynamic>?;
    final adherence = summary?['adherencePercent'] ?? 0;
    final taken = summary?['taken'] ?? 0;
    final missed = summary?['missed'] ?? 0;
    final total = summary?['totalScheduled'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      decoration: BoxDecoration(
        color: AppTheme.teal,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.teal.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Medication Adherence', style: TextStyle(color: AppTheme.surface, fontSize: AppTheme.fontSizeMd)),
          const SizedBox(height: AppTheme.spacingSm),
          Text('$adherence%', style: const TextStyle(color: AppTheme.surface, fontSize: 40, fontWeight: FontWeight.w900)),
          const SizedBox(height: AppTheme.spacingMd),
          Row(
            children: [
              _adherenceStat('Taken', '$taken'),
              const SizedBox(width: AppTheme.spacingXl),
              _adherenceStat('Missed', '$missed'),
              const SizedBox(width: AppTheme.spacingXl),
              _adherenceStat('Scheduled', '$total'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _adherenceStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.surface, fontSize: AppTheme.fontSizeSm)),
        Text(value, style: const TextStyle(color: AppTheme.surface, fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.w800)),
      ],
    );
  }

  List<Widget> _buildPlans() {
    final plans = (_data?['plans'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    if (plans.isEmpty) {
      return [
        const CCEmpty(icon: Icons.medication, message: 'No medication plans.'),
      ];
    }
    return plans.map((plan) => Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.surfaceBorder),
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
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: (plan['active'] == true ? AppTheme.teal : AppTheme.muted).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(Icons.medication, color: plan['active'] == true ? AppTheme.teal : AppTheme.muted, size: 22),
          ),
          const SizedBox(width: AppTheme.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan['name'].toString(), style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w800)),
                const SizedBox(height: AppTheme.spacingXs),
                Text('${plan['dosage']} • ${plan['frequency']}',
                    style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeSm)),
                Text('Reminder: ${plan['reminderTime']}',
                    style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeSm)),
              ],
            ),
          ),
          StatusBadge(
            label: plan['active'] == true ? 'ACTIVE' : 'INACTIVE',
            color: plan['active'] == true ? AppTheme.teal : AppTheme.muted,
          ),
        ],
      ),
    )).toList();
  }

  List<Widget> _buildLogs() {
    final logs = (_data?['logs'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    if (logs.isEmpty) {
      return [
        const CCEmpty(icon: Icons.receipt_long, message: 'No medication logs yet.'),
      ];
    }
    return logs.reversed.take(10).map((log) {
      final status = log['status'].toString();
      final tone = status == 'taken'
          ? AppTheme.green
          : status == 'missed'
              ? AppTheme.sosRed
              : AppTheme.amber;
      return Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: tone.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(
              status == 'taken' ? Icons.check_circle : status == 'missed' ? Icons.cancel : Icons.schedule,
              color: tone,
              size: 20,
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status.toUpperCase(), style: TextStyle(color: tone, fontWeight: FontWeight.w700, fontSize: AppTheme.fontSizeSm)),
                  Text('Due: ${log['dueAt']}', style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeSm)),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  void _openAddMedicationDialog() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final frequencyController = TextEditingController(text: 'Once daily');
    TimeOfDay? reminder = const TimeOfDay(hour: 8, minute: 0);

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Medication'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Medication name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                TextField(
                  controller: dosageController,
                  decoration: const InputDecoration(labelText: 'Dosage (e.g. 5 mg)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                TextField(
                  controller: frequencyController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Frequency (e.g. Once daily)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: reminder ?? const TimeOfDay(hour: 8, minute: 0),
                    );
                    if (picked != null) setDialogState(() => reminder = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Reminder time', border: OutlineInputBorder()),
                    child: Text(
                      reminder == null ? 'Select time' : '${twoDigits(reminder!.hour)}:${twoDigits(reminder!.minute)}',
                      style: const TextStyle(fontSize: AppTheme.fontSizeLg, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final dosage = dosageController.text.trim();
                final frequency = frequencyController.text.trim();
                if (name.length < 2 || dosage.isEmpty || frequency.isEmpty || reminder == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill name, dosage, frequency and reminder time.')),
                  );
                  return;
                }
                final reminderTime = '${twoDigits(reminder!.hour)}:${twoDigits(reminder!.minute)}';
                Navigator.of(ctx).pop();
                try {
                  await widget.apiClient.createMedication(
                    elderId: widget.elderId,
                    name: name,
                    dosage: dosage,
                    frequency: frequency,
                    reminderTime: reminderTime,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Medication added')),
                    );
                    _load();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'),
                        backgroundColor: AppTheme.sosRed,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _openLogDoseDialog(List<Map<String, dynamic>> plans) {
    String? selectedPlanId;
    String selectedStatus = 'taken';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Log Medication Dose'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedPlanId,
                hint: const Text('Select medication'),
                items: plans.map<DropdownMenuItem<String>>((p) {
                  return DropdownMenuItem<String>(
                    value: p['id']?.toString(),
                    child: Text('${p['name'] ?? ''} - ${p['dosage'] ?? ''}', style: const TextStyle(fontSize: AppTheme.fontSizeMd)),
                  );
                }).toList(),
                onChanged: (v) => setDialogState(() => selectedPlanId = v),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                items: const [
                  DropdownMenuItem(value: 'taken', child: Text('Taken')),
                  DropdownMenuItem(value: 'snoozed', child: Text('Snooze (remind again)')),
                  DropdownMenuItem(value: 'missed', child: Text('Missed')),
                  DropdownMenuItem(value: 'skipped', child: Text('Skipped')),
                ],
                onChanged: (v) => setDialogState(() => selectedStatus = v ?? 'taken'),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: selectedPlanId == null
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      try {
                        await widget.apiClient.logMedication(
                          elderId: widget.elderId,
                          medicationId: selectedPlanId!,
                          status: selectedStatus,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Medication dose logged')),
                          );
                          _load();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'),
                              backgroundColor: AppTheme.sosRed,
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
