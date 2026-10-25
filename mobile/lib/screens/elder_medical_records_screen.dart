import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';
import 'care_instruction_form_screen.dart';

class ElderMedicalRecordsScreen extends StatefulWidget {
  const ElderMedicalRecordsScreen({
    super.key,
    required this.apiClient,
    required this.elderId,
    required this.elderName,
  });

  final ApiClient apiClient;
  final String elderId;
  final String elderName;

  @override
  State<ElderMedicalRecordsScreen> createState() => _ElderMedicalRecordsScreenState();
}

class _ElderMedicalRecordsScreenState extends State<ElderMedicalRecordsScreen> {
  Map<String, dynamic>? _records;
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
      final result = await widget.apiClient.elderMedicalRecords(widget.elderId);
      if (!mounted) return;
      setState(() => _records = result);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('${widget.elderName} Records'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => CareInstructionFormScreen(
                apiClient: widget.apiClient,
                elderId: widget.elderId,
                elderName: widget.elderName,
              ),
            ),
          );
          if (result == true) _load();
        },
        backgroundColor: AppTheme.teal,
        foregroundColor: AppTheme.surface,
        icon: const Icon(Icons.add_comment),
        label: const Text('Provide Instruction', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const CCLoading()
          : _error != null
              ? CCError(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      _buildProfileSection(),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildVitalsSection(),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildMedicationSection(),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildHydrationSection(),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildExerciseSection(),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildAppointmentsSection(),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildInstructionsSection(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileSection() {
    final profile = _records?['profile'] as Map<String, dynamic>?;
    final conditions = (profile?['medicalConditions'] as List<dynamic>? ?? const []);
    final allergies = (profile?['allergies'] as List<dynamic>? ?? const []);

    return SectionCard(
      title: 'Patient Profile',
      icon: Icons.person,
      tone: AppTheme.teal,
      children: [
        KvRow(label: 'Name', value: profile?['name']?.toString() ?? ''),
        KvRow(label: 'DOB', value: profile?['dateOfBirth']?.toString() ?? 'Not set'),
        KvRow(label: 'Contact', value: profile?['contactNumber']?.toString() ?? 'Not set'),
        if (conditions.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingSm),
          const Text('Medical Conditions', style: TextStyle(fontSize: AppTheme.fontSizeMd, fontWeight: FontWeight.w700, color: AppTheme.ink)),
          const SizedBox(height: AppTheme.spacingXs),
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingSm,
            children: conditions.map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingXs),
              decoration: BoxDecoration(
                color: AppTheme.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Text(c.toString(), style: const TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.green, fontWeight: FontWeight.w600)),
            )).toList(),
          ),
        ],
        if (allergies.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingSm),
          const Text('Allergies', style: TextStyle(fontSize: AppTheme.fontSizeMd, fontWeight: FontWeight.w700, color: AppTheme.ink)),
          const SizedBox(height: AppTheme.spacingXs),
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingSm,
            children: allergies.map((a) => Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingXs),
              decoration: BoxDecoration(
                color: AppTheme.coral.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Text(a.toString(), style: const TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.coral, fontWeight: FontWeight.w600)),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildVitalsSection() {
    final vitals = (_records?['vitals'] as List<dynamic>? ?? const []);
    final overview = _computeVitalsOverview(vitals);

    return SectionCard(
      title: 'Vital Signs',
      icon: Icons.monitor_heart,
      tone: AppTheme.teal,
      children: [
        KvRow(label: 'Total Readings', value: '${vitals.length}'),
        KvRow(label: 'Abnormal', value: '${overview['abnormalCount']}'),
        KvRow(label: 'Status', value: overview['status'].toString().toUpperCase()),
        if (vitals.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingMd),
          const Text('Recent Readings', style: TextStyle(fontSize: AppTheme.fontSizeMd, fontWeight: FontWeight.w700, color: AppTheme.ink)),
          const SizedBox(height: AppTheme.spacingSm),
          ...vitals.take(5).map((v) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: v['status'] == 'abnormal' ? AppTheme.sosRed : AppTheme.teal,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    '${_vitalTypeLabel(v['type']?.toString() ?? '')}: ${v['value']} ${v['unit'] ?? ''}',
                    style: const TextStyle(fontSize: AppTheme.fontSizeSm),
                  ),
                ),
                Text(
                  formatTime(v['createdAt']?.toString() ?? ''),
                  style: const TextStyle(fontSize: AppTheme.fontSizeXs, color: AppTheme.muted),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildMedicationSection() {
    final plans = (_records?['medicationPlans'] as List<dynamic>? ?? const []);
    final logs = (_records?['medicationLogs'] as List<dynamic>? ?? const []);

    return SectionCard(
      title: 'Medications',
      icon: Icons.medication,
      tone: AppTheme.teal,
      children: [
        KvRow(label: 'Active Plans', value: '${plans.length}'),
        KvRow(label: 'Total Logs', value: '${logs.length}'),
        if (plans.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingMd),
          ...plans.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
            child: Row(
              children: [
                const Icon(Icons.medication, size: 14, color: AppTheme.teal),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    '${p['name'] ?? ''} - ${p['dosage'] ?? ''} (${p['frequency'] ?? ''})',
                    style: const TextStyle(fontSize: AppTheme.fontSizeSm),
                  ),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildHydrationSection() {
    final logs = (_records?['hydrationLogs'] as List<dynamic>? ?? const []);
    final totalMl = logs.fold<int>(0, (sum, l) => sum + ((l['amountMl'] as num?)?.toInt() ?? 0));

    return SectionCard(
      title: 'Hydration',
      icon: Icons.water_drop,
      tone: AppTheme.teal,
      children: [
        KvRow(label: 'Total Entries', value: '${logs.length}'),
        KvRow(label: 'Total Volume', value: '$totalMl ml'),
      ],
    );
  }

  Widget _buildExerciseSection() {
    final logs = (_records?['exerciseLogs'] as List<dynamic>? ?? const []);
    final totalMinutes = logs.fold<int>(0, (sum, l) => sum + ((l['minutes'] as num?)?.toInt() ?? 0));

    return SectionCard(
      title: 'Exercise',
      icon: Icons.fitness_center,
      tone: AppTheme.coral,
      children: [
        KvRow(label: 'Total Sessions', value: '${logs.length}'),
        KvRow(label: 'Total Minutes', value: '$totalMinutes min'),
        if (logs.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingSm),
          ...logs.take(3).map((l) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingXs),
            child: Text(
              '${l['activityType'] ?? ''} - ${l['minutes'] ?? 0} min',
              style: const TextStyle(fontSize: AppTheme.fontSizeSm),
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildAppointmentsSection() {
    final appointments = (_records?['appointments'] as List<dynamic>? ?? const []);

    return SectionCard(
      title: 'Appointments',
      icon: Icons.event,
      tone: AppTheme.amber,
      children: [
        KvRow(label: 'Total', value: '${appointments.length}'),
        if (appointments.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingSm),
          ...appointments.take(3).map((a) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
            child: Row(
              children: [
                const Icon(Icons.event, size: 14, color: AppTheme.amber),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    '${a['doctorName'] ?? ''} - ${a['specialty'] ?? ''}',
                    style: const TextStyle(fontSize: AppTheme.fontSizeSm),
                  ),
                ),
                Text(
                  formatDateTime(a['dateTime']?.toString() ?? ''),
                  style: const TextStyle(fontSize: AppTheme.fontSizeXs, color: AppTheme.amber, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildInstructionsSection() {
    final instructions = (_records?['instructions'] as List<dynamic>? ?? const []);

    return SectionCard(
      title: 'Care Instructions',
      icon: Icons.comment,
      tone: AppTheme.teal,
      children: [
        if (instructions.isEmpty)
          const Text('No instructions yet.', style: TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeMd))
        else
          ...instructions.map((i) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          i['title']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppTheme.fontSizeMd),
                        ),
                      ),
                      PriorityBadge(priority: i['priority']?.toString() ?? 'low'),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingXs),
                  Text(
                    i['message']?.toString() ?? '',
                    style: const TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.muted),
                  ),
                  const SizedBox(height: AppTheme.spacingXs),
                  Text(
                    formatDateTime(i['createdAt']?.toString() ?? ''),
                    style: const TextStyle(fontSize: AppTheme.fontSizeXs, color: AppTheme.subtle),
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }

  Map<String, dynamic> _computeVitalsOverview(List<dynamic> vitals) {
    int abnormalCount = 0;
    for (final v in vitals) {
      if (v['status']?.toString() == 'abnormal') abnormalCount++;
    }
    return {
      'abnormalCount': abnormalCount,
      // Same vocabulary as the backend overview and stored reading status.
      'status': abnormalCount > 0 ? 'abnormal' : 'normal',
    };
  }

  String _vitalTypeLabel(String type) {
    switch (type) {
      case 'bloodPressure': return 'Blood Pressure';
      case 'bloodSugar': return 'Blood Sugar';
      case 'heartRate': return 'Heart Rate';
      case 'temperature': return 'Temperature';
      case 'weight': return 'Weight';
      default: return type;
    }
  }
}
