import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key, required this.apiClient, required this.elderId});

  final ApiClient apiClient;
  final String elderId;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  List<dynamic> _events = [];
  bool _isLoading = true;
  String? _error;
  String? _userRole;

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
        widget.apiClient.sosEvents(),
        widget.apiClient.me(),
      ]);
      if (!mounted) return;
      _events = (results[0]['events'] as List<dynamic>? ?? const []);
      _userRole = results[1]['user']?['role']?.toString();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerSos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: AppTheme.danger),
            SizedBox(width: 8),
            Text('Trigger SOS'),
          ],
        ),
        content: const Text(
          'This will immediately alert all members of your CareCircle. '
          'Use this only for genuine emergencies.',
          style: TextStyle(color: AppTheme.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Trigger SOS'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.apiClient.triggerSos(elderId: widget.elderId, location: 'Mobile app');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS alert triggered. Your CareCircle has been notified.'),
            backgroundColor: AppTheme.danger,
          ),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _acknowledge(String eventId) async {
    try {
      await widget.apiClient.acknowledgeSos(eventId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS acknowledged.')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _resolve(String eventId) async {
    try {
      await widget.apiClient.resolveSos(eventId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS resolved.')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _events.where((e) => e['status']?.toString() == 'active').toList();
    final acknowledged = _events.where((e) => e['status']?.toString() == 'acknowledged').toList();
    final resolved = _events.where((e) => e['status']?.toString() == 'resolved').toList();
    final isElder = _userRole == 'elder';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('SOS Emergency'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.danger)),
                        const SizedBox(height: 16),
                        FilledButton.tonal(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      if (isElder) ...[
                        _buildTriggerCard(),
                        const SizedBox(height: 20),
                      ],
                      const Text('Active Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                      const SizedBox(height: 12),
                      ..._buildEventList(active, isActive: true),
                      const SizedBox(height: 20),
                      const Text('Acknowledged', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                      const SizedBox(height: 12),
                      ..._buildEventList(acknowledged, isAcknowledged: true),
                      const SizedBox(height: 20),
                      const Text('Resolved', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                      const SizedBox(height: 12),
                      ..._buildEventList(resolved),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTriggerCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFD94C4C), Color(0xFFB33A3A)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          const Text('Emergency SOS', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
            'Press the button below to alert your CareCircle immediately.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _triggerSos,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.danger,
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text('TRIGGER SOS'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEventList(List<dynamic> events, {bool isActive = false, bool isAcknowledged = false}) {
    if (events.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Center(
            child: Text(
              isActive ? 'No active SOS alerts.' : isAcknowledged ? 'No acknowledged alerts.' : 'No resolved alerts.',
              style: const TextStyle(color: AppTheme.muted),
            ),
          ),
        ),
      ];
    }

    return events.map((event) {
      final location = event['location']?.toString();
      final createdAt = event['createdAt']?.toString() ?? '';
      final canAcknowledge = isActive && _userRole != 'elder';
      final canResolve = isAcknowledged && _userRole != 'elder';

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.danger.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.danger.withValues(alpha: 0.3) : AppTheme.surfaceBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.error : isAcknowledged ? Icons.info : Icons.check_circle,
                  color: isActive ? AppTheme.danger : isAcknowledged ? AppTheme.warning : AppTheme.accent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isActive ? 'Active SOS Alert' : isAcknowledged ? 'Acknowledged' : 'Resolved',
                        style: TextStyle(
                          color: isActive ? AppTheme.danger : isAcknowledged ? AppTheme.warning : AppTheme.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (location != null && location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(location, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
                      ],
                      const SizedBox(height: 4),
                      Text(_formatTime(createdAt), style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            if (canAcknowledge || canResolve) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (canAcknowledge)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _acknowledge(event['id']?.toString() ?? ''),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Acknowledge', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.warning,
                          side: const BorderSide(color: AppTheme.warning),
                        ),
                      ),
                    ),
                  if (canAcknowledge && canResolve) const SizedBox(width: 10),
                  if (canResolve)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _resolve(event['id']?.toString() ?? ''),
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('Resolve', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
