import 'package:flutter/material.dart';

import '../api_client.dart';
import '../responsive.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';
import 'accept_invitation_screen.dart';

class FamilyDashboard extends StatefulWidget {
  const FamilyDashboard({super.key, required this.apiClient, required this.onLogout});

  final ApiClient apiClient;
  final Future<void> Function() onLogout;

  @override
  State<FamilyDashboard> createState() => _FamilyDashboardState();
}

class _FamilyDashboardState extends State<FamilyDashboard> {
  Map<String, dynamic>? _me;
  Map<String, dynamic>? _dashboard;
  List<dynamic> _circles = [];
  List<dynamic> _notifications = [];
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
        widget.apiClient.notifications(),
      ]);
      if (!mounted) return;
      _me = results[0];
      _dashboard = results[1];
      _circles = (results[2]['circles'] as List<dynamic>? ?? const []);
      _notifications = (results[3]['notifications'] as List<dynamic>? ?? const []);
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
    final unreadAlerts = _notifications.where((n) => n['readAt'] == null).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('CareCircle'),
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
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              if (unreadAlerts > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppTheme.sosRed, shape: BoxShape.circle),
                    child: Text('$unreadAlerts', style: const TextStyle(color: AppTheme.surface, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
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
                      const Text('Your Linked Elders', style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                      const SizedBox(height: AppTheme.spacingXs),
                      const Text('Select an elder to view their health summary.', style: TextStyle(color: AppTheme.muted)),
                      const SizedBox(height: AppTheme.spacingLg),
                      ..._buildElderCards(),
                      const SizedBox(height: AppTheme.spacingXxl),
                      if (_notifications.isNotEmpty) ...[
                        const Text('Recent Alerts', style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                        const SizedBox(height: AppTheme.spacingMd),
                        ..._notifications.take(5).map((n) => _buildNotificationTile(n)),
                      ],
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
        const Text('Here is the latest on your linked elders.', style: TextStyle(color: AppTheme.muted, fontSize: 15)),
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

  List<Widget> _buildElderCards() {
    final elderIds = <String>{};
    for (final circle in _circles) {
      final members = (circle['members'] as List<dynamic>? ?? const []);
      for (final m in members) {
        if (m['relation']?.toString() == 'elder') {
          elderIds.add(m['userId'].toString());
        }
      }
    }

    if (elderIds.isEmpty) {
      return [
        CCEmpty(icon: Icons.elderly, message: 'No linked elders found.'),
      ];
    }

    return elderIds.map((elderId) {
      final circle = _circles.firstWhere(
        (c) => (c['members'] as List<dynamic>).any((m) => m['userId']?.toString() == elderId),
        orElse: () => _circles.first,
      );
      final elderName = _findMemberName(elderId, circle);

      return Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        child: Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            onTap: () => _openElderSummary(elderId, elderName),
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
                  AvatarCircle(name: elderName, radius: 28, color: AppTheme.coral),
                  const SizedBox(width: AppTheme.spacingLg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(elderName, style: const TextStyle(fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                        const SizedBox(height: AppTheme.spacingXs),
                        Text(
                          'Tap to view health summary',
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

  String _findMemberName(String userId, dynamic circle) {
    final members = (circle['members'] as List<dynamic>? ?? const []);
    for (final m in members) {
      if (m['userId']?.toString() == userId) {
        return m['name']?.toString() ?? 'Elder';
      }
    }
    return 'Elder';
  }

  void _openElderSummary(String elderId, String elderName) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ElderSummaryScreen(
        apiClient: widget.apiClient,
        elderId: elderId,
        elderName: elderName,
      ),
    ));
  }

  Widget _buildNotificationTile(Map<String, dynamic> n) {
    final category = n['category']?.toString() ?? 'system';
    final tone = categoryColor(category);
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
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
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: tone, shape: BoxShape.circle)),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppTheme.fontSizeMd)),
                const SizedBox(height: 2),
                Text(n['body']?.toString() ?? '', style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeSm), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ElderSummaryScreen extends StatefulWidget {
  const _ElderSummaryScreen({required this.apiClient, required this.elderId, required this.elderName});

  final ApiClient apiClient;
  final String elderId;
  final String elderName;

  @override
  State<_ElderSummaryScreen> createState() => _ElderSummaryScreenState();
}

class _ElderSummaryScreenState extends State<_ElderSummaryScreen> {
  Map<String, dynamic>? _vitals;
  Map<String, dynamic>? _medications;
  Map<String, dynamic>? _report;
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
        widget.apiClient.vitalsForElder(widget.elderId),
        widget.apiClient.medicationSummary(widget.elderId),
        widget.apiClient.reportSummary(widget.elderId),
        widget.apiClient.elderInstructions(widget.elderId),
      ]);
      if (!mounted) return;
      _vitals = results[0];
      _medications = results[1];
      _report = results[2];
      _instructions = (results[3]['instructions'] as List<dynamic>? ?? const []);
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
                      _buildVitalsSection(),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildMedicationSection(),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildReportSection(),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildInstructionsSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildVitalsSection() {
    final overview = _vitals?['overview'] as Map<String, dynamic>?;
    final latest = overview?['latest'] as Map<String, dynamic>?;
    final status = overview?['status']?.toString() ?? 'unknown';
    final abnormalCount = overview?['abnormalCount'] ?? 0;

    return SectionCard(
      title: 'Vitals',
      icon: Icons.monitor_heart,
      tone: status == 'abnormal' ? AppTheme.sosRed : AppTheme.teal,
      children: [
        if (latest != null) ...[
          KvRow(label: 'Latest', value: '${latest['type']}: ${latest['value']} ${latest['unit']}'),
          if (latest['systolic'] != null)
            KvRow(label: 'Blood Pressure', value: '${latest['systolic']}/${latest['diastolic']} mmHg'),
          const SizedBox(height: AppTheme.spacingSm),
        ],
        KvRow(label: 'Total Readings', value: '${overview?['totalReadings'] ?? 0}'),
        KvRow(label: 'Abnormal', value: '$abnormalCount'),
        KvRow(label: 'Status', value: status.toUpperCase(), valueColor: status == 'abnormal' ? AppTheme.sosRed : AppTheme.teal),
      ],
    );
  }

  Widget _buildMedicationSection() {
    final summary = _medications?['summary'] as Map<String, dynamic>?;
    final plans = (_medications?['plans'] as List<dynamic>? ?? const []);

    return SectionCard(
      title: 'Medication',
      icon: Icons.medication,
      tone: AppTheme.teal,
      children: [
        KvRow(label: 'Adherence', value: '${summary?['adherencePercent'] ?? 0}%'),
        KvRow(label: 'Taken', value: '${summary?['taken'] ?? 0}'),
        KvRow(label: 'Missed', value: '${summary?['missed'] ?? 0}'),
        const SizedBox(height: AppTheme.spacingSm),
        if (plans.isNotEmpty)
          ...plans.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingXs),
            child: Text('${p['name']} - ${p['dosage']}', style: const TextStyle(fontSize: AppTheme.fontSizeMd)),
          )),
      ],
    );
  }

  Widget _buildReportSection() {
    return SectionCard(
      title: 'Weekly Report',
      icon: Icons.assessment,
      tone: AppTheme.coral,
      children: [
        KvRow(label: 'Vital Readings', value: '${_report?['vitalsCount'] ?? 0}'),
        KvRow(label: 'Abnormal', value: '${_report?['abnormalVitalsCount'] ?? 0}'),
        KvRow(label: 'Hydration', value: '${_report?['hydrationMl'] ?? 0} ml'),
        KvRow(label: 'Exercise', value: '${_report?['exerciseMinutes'] ?? 0} min'),
        KvRow(label: 'Appointments', value: '${_report?['appointmentCount'] ?? 0}'),
      ],
    );
  }

  Widget _buildInstructionsSection() {
    return SectionCard(
      title: 'Care Instructions',
      icon: Icons.comment,
      tone: AppTheme.teal,
      children: [
        if (_instructions.isEmpty)
          const Text('No instructions yet.', style: TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeMd))
        else
          ..._instructions.map((i) => Padding(
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
}
