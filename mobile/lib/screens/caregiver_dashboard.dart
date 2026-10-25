import 'package:flutter/material.dart';

import '../api_client.dart';
import '../responsive.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';
import 'accept_invitation_screen.dart';
import 'elder_medical_records_screen.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key, required this.apiClient, required this.onLogout});

  final ApiClient apiClient;
  final Future<void> Function() onLogout;

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  Map<String, dynamic>? _me;
  Map<String, dynamic>? _dashboard;
  List<dynamic> _circles = [];
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
        widget.apiClient.me(),
        widget.apiClient.dashboard(),
        widget.apiClient.myCareCircles(),
      ]);
      if (!mounted) return;
      _me = results[0];
      _dashboard = results[1];
      _circles = (results[2]['circles'] as List<dynamic>? ?? const []);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = _me?['user']?['name']?.toString() ?? '';
    final cards = (_dashboard?['cards'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    final actions = (_dashboard?['actions'] as List<dynamic>? ?? const []).cast<String>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Caregiver'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AcceptInvitationScreen(
                  apiClient: widget.apiClient,
                  onAccepted: _load,
                ),
              ));
            },
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Accept Invitation',
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _isLoading
          ? const CCLoading()
          : _error != null
              ? CCError(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                    children: [
                      _buildHeader(userName),
                      const SizedBox(height: AppTheme.spacingXl),
                      _buildOverviewCards(cards),
                      const SizedBox(height: AppTheme.spacingXxl),
                      _buildQuickActions(actions),
                      const SizedBox(height: AppTheme.spacingXxl),
                      const Text('Your Clients', style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                      const SizedBox(height: AppTheme.spacingXs),
                      const Text('Select a client to view today\'s tasks.', style: TextStyle(color: AppTheme.muted)),
                      const SizedBox(height: AppTheme.spacingLg),
                      ..._buildClientCards(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(String userName) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$greeting, $userName', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        const SizedBox(height: AppTheme.spacingXs),
        const Text('Here is your caseload overview.', style: TextStyle(color: AppTheme.muted, fontSize: 15)),
      ],
    );
  }

  Widget _buildOverviewCards(List<Map<String, dynamic>> cards) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final columns = Responsive.gridColumns(context);
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppTheme.spacingMd,
      crossAxisSpacing: AppTheme.spacingMd,
      childAspectRatio: 1.6,
      children: cards.map((card) {
        final tone = toneFromString(card['tone']?.toString() ?? 'normal');
        return Container(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: tone.withValues(alpha: 0.4)),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(card['label']?.toString() ?? '', style: TextStyle(color: tone, fontSize: AppTheme.fontSizeSm, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppTheme.spacingSm),
              Text(card['value']?.toString() ?? '', style: const TextStyle(color: AppTheme.ink, fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickActions(List<String> actions) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        const SizedBox(height: AppTheme.spacingMd),
        Wrap(
          spacing: AppTheme.spacingMd,
          runSpacing: AppTheme.spacingMd,
          children: actions.map((action) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXl, vertical: AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(color: AppTheme.surfaceBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(action, style: const TextStyle(fontSize: AppTheme.fontSizeMd, fontWeight: FontWeight.w700, color: AppTheme.ink)),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Widget> _buildClientCards() {
    final elderIds = <String>{};
    final elderNames = <String, String>{};
    for (final circle in _circles) {
      final members = (circle['members'] as List<dynamic>? ?? const []);
      for (final m in members) {
        if (m['relation']?.toString() == 'elder') {
          final id = m['userId'].toString();
          elderIds.add(id);
          elderNames[id] = m['name']?.toString() ?? 'Client';
        }
      }
    }

    if (elderIds.isEmpty) {
      return [
        CCEmpty(icon: Icons.people_outline, message: 'No clients assigned.'),
      ];
    }

    return elderIds.map((elderId) {
      final name = elderNames[elderId] ?? 'Client';
      return Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        child: Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            onTap: () => _openClientTasks(elderId, name),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingXl),
              decoration: BoxDecoration(
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
                  AvatarCircle(name: name, radius: 28, color: AppTheme.teal),
                  const SizedBox(width: AppTheme.spacingLg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                        const SizedBox(height: AppTheme.spacingXs),
                        Text(
                          "Tap to view today's tasks",
                          style: TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeMd),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.muted, size: 28),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  void _openClientTasks(String elderId, String elderName) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ClientTasksScreen(
        apiClient: widget.apiClient,
        elderId: elderId,
        elderName: elderName,
      ),
    ));
  }
}

class _ClientTasksScreen extends StatefulWidget {
  const _ClientTasksScreen({required this.apiClient, required this.elderId, required this.elderName});

  final ApiClient apiClient;
  final String elderId;
  final String elderName;

  @override
  State<_ClientTasksScreen> createState() => _ClientTasksScreenState();
}

class _ClientTasksScreenState extends State<_ClientTasksScreen> {
  Map<String, dynamic>? _vitals;
  Map<String, dynamic>? _medications;
  Map<String, dynamic>? _appointments;
  Map<String, dynamic>? _hydration;
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
        widget.apiClient.vitalsForElder(widget.elderId),
        widget.apiClient.medicationSummary(widget.elderId),
        widget.apiClient.appointmentsForElder(widget.elderId),
        widget.apiClient.hydrationSummary(widget.elderId),
      ]);
      if (!mounted) return;
      _vitals = results[0];
      _medications = results[1];
      _appointments = results[2];
      _hydration = results[3];
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
        title: Text(widget.elderName),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
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
                      _buildMedicalRecordsButton(),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildVitalsTask(),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildMedicationTask(),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildAppointmentsTask(),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildHydrationTask(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMedicalRecordsButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ElderMedicalRecordsScreen(
              apiClient: widget.apiClient,
              elderId: widget.elderId,
              elderName: widget.elderName,
            ),
          ));
        },
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.teal,
          foregroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        ),
        icon: const Icon(Icons.folder_open),
        label: const Text('Medical Records & Instructions', style: TextStyle(fontSize: AppTheme.fontSizeLg, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildVitalsTask() {
    final overview = _vitals?['overview'] as Map<String, dynamic>?;
    final status = overview?['status']?.toString() ?? 'unknown';
    final totalReadings = overview?['totalReadings'] ?? 0;

    return SectionCard(
      title: 'Vitals',
      icon: Icons.monitor_heart,
      tone: AppTheme.teal,
      trailing: StatusBadge(
        label: status,
        color: status == 'abnormal' ? AppTheme.sosRed : status == 'attention' ? AppTheme.coral : AppTheme.teal,
      ),
      children: [
        KvRow(label: 'Total Readings', value: '$totalReadings'),
        KvRow(label: 'Status', value: status.toUpperCase()),
      ],
    );
  }

  Widget _buildMedicationTask() {
    final summary = _medications?['summary'] as Map<String, dynamic>?;
    final adherence = summary?['adherencePercent'] ?? 0;
    final plans = (_medications?['plans'] as List<dynamic>? ?? const []);

    return SectionCard(
      title: 'Medication',
      icon: Icons.medication,
      tone: AppTheme.teal,
      children: [
        KvRow(label: 'Adherence', value: '$adherence%'),
        KvRow(label: 'Taken', value: '${summary?['taken'] ?? 0}'),
        KvRow(label: 'Missed', value: '${summary?['missed'] ?? 0}'),
        if (plans.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingMd),
          ...plans.take(3).map((p) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
            child: Row(
              children: [
                const Icon(Icons.medication, size: 14, color: AppTheme.muted),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    '${p['name'] ?? ''} - ${p['dosage'] ?? ''}',
                    style: const TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
        ],
        const SizedBox(height: AppTheme.spacingMd),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: plans.isEmpty ? null : () => _openMedicationLogDialog(plans),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Log Medication', style: TextStyle(fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.teal,
              side: const BorderSide(color: AppTheme.teal),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentsTask() {
    final appointments = (_appointments?['appointments'] as List<dynamic>? ?? const []);
    final now = DateTime.now();
    final upcoming = appointments.where((a) {
      final dt = DateTime.tryParse(a['dateTime']?.toString() ?? '');
      return dt != null && dt.isAfter(now);
    }).toList();

    return SectionCard(
      title: 'Appointments',
      icon: Icons.event,
      tone: AppTheme.coral,
      children: [
        if (upcoming.isEmpty)
          const Text('No upcoming appointments.', style: TextStyle(color: AppTheme.muted))
        else
          ...upcoming.take(3).map((a) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a['doctorName']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppTheme.fontSizeMd)),
                      Text(a['specialty']?.toString() ?? '', style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeSm)),
                    ],
                  ),
                ),
                Text(
                  formatDateTime(a['dateTime']?.toString() ?? ''),
                  style: const TextStyle(fontSize: AppTheme.fontSizeSm, fontWeight: FontWeight.w600, color: AppTheme.coral),
                ),
              ],
            ),
          )),
      ],
    );
  }

  Widget _buildHydrationTask() {
    final totalMl = _hydration?['totalMl'] ?? 0;
    final targetMl = _hydration?['targetMl'] ?? 2000;
    final progress = targetMl > 0 ? (totalMl / targetMl * 100).clamp(0, 100).toInt() : 0;

    return SectionCard(
      title: 'Hydration',
      icon: Icons.water_drop,
      tone: AppTheme.teal,
      children: [
        KvRow(label: 'Total', value: '$totalMl ml'),
        KvRow(label: 'Target', value: '$targetMl ml'),
        KvRow(label: 'Progress', value: '$progress%'),
        const SizedBox(height: AppTheme.spacingMd),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _openHydrationLogDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Log Hydration', style: TextStyle(fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.teal,
              side: const BorderSide(color: AppTheme.teal),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
            ),
          ),
        ),
      ],
    );
  }

  void _openMedicationLogDialog(List<dynamic> plans) {
    String? selectedPlanId;
    String selectedStatus = 'taken';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Log Medication'),
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
                            const SnackBar(content: Text('Medication logged')),
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
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.teal,
                foregroundColor: AppTheme.surface,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _openHydrationLogDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Hydration'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Amount in ml',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final ml = double.tryParse(controller.text) ?? 250;
                await widget.apiClient.logHydration(elderId: widget.elderId, amountMl: ml);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hydration logged')),
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
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.teal,
              foregroundColor: AppTheme.surface,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
