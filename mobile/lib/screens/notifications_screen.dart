import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  List<dynamic> _sosEvents = [];
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
        widget.apiClient.notifications(),
        widget.apiClient.sosEvents(),
      ]);
      if (!mounted) return;
      setState(() {
        _notifications = (results[0]['notifications'] as List<dynamic>? ?? const []);
        _sosEvents = (results[1]['events'] as List<dynamic>? ?? const []);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSos(String eventId, {required bool acknowledge}) async {
    try {
      if (acknowledge) {
        await widget.apiClient.acknowledgeSos(eventId);
      } else {
        await widget.apiClient.resolveSos(eventId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(acknowledge ? 'SOS acknowledged' : 'SOS resolved')),
        );
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update SOS: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: AppTheme.sosRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSos = _sosEvents.where((event) => event['status']?.toString() != 'resolved').toList();
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Notifications'),
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
                  child: activeSos.isEmpty && _notifications.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            CCEmpty(icon: Icons.notifications_none, message: 'No notifications yet.'),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.all(AppTheme.spacingXl),
                          children: [
                            if (activeSos.isNotEmpty) ...[
                              _buildSosSection(activeSos),
                              const SizedBox(height: AppTheme.spacingXl),
                            ],
                            ..._notifications.map((item) => _buildNotification(item)),
                          ],
                        ),
                ),
    );
  }

  Widget _buildSosSection(List<dynamic> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.sosRed, size: 24),
            SizedBox(width: AppTheme.spacingSm),
            Text('Active SOS', style: TextStyle(fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.w800, color: AppTheme.sosRed)),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),
        ...events.map((event) {
          final eventId = event['id']?.toString() ?? '';
          final acknowledged = event['status']?.toString() == 'acknowledged';
          return Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            decoration: BoxDecoration(
              color: AppTheme.sosRedLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: AppTheme.sosRed.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sos, color: AppTheme.sosRed, size: 28),
                    const SizedBox(width: AppTheme.spacingMd),
                    Expanded(
                      child: Text(
                        acknowledged ? 'SOS acknowledged' : 'SOS needs attention',
                        style: const TextStyle(color: AppTheme.sosRed, fontWeight: FontWeight.w800, fontSize: AppTheme.fontSizeLg),
                      ),
                    ),
                    StatusBadge(
                      label: event['status']?.toString() ?? 'active',
                      color: AppTheme.sosRed,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  '${event['location']?.toString() ?? 'Location unavailable'} · ${formatDateTime(event['createdAt']?.toString() ?? '')}',
                  style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeSm),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Row(
                  children: [
                    if (!acknowledged)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: eventId.isEmpty ? null : () => _updateSos(eventId, acknowledge: true),
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('Acknowledge'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.sosRed,
                            side: const BorderSide(color: AppTheme.sosRed),
                          ),
                        ),
                      ),
                    if (!acknowledged) const SizedBox(width: AppTheme.spacingMd),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: eventId.isEmpty ? null : () => _updateSos(eventId, acknowledge: false),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Resolve'),
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.sosRed, foregroundColor: AppTheme.surface),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNotification(dynamic item) {
    final category = item['category']?.toString() ?? 'system';
    final tone = categoryColor(category);
    final icon = categoryIcon(category);
    final isRead = item['readAt'] != null;
    final id = item['id']?.toString();
    return GestureDetector(
      onTap: isRead || id == null
          ? null
          : () async {
              try {
                await widget.apiClient.markNotificationRead(id);
                if (mounted) {
                  setState(() {
                    item['readAt'] = DateTime.now().toIso8601String();
                  });
                }
              } catch (_) {}
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: isRead ? AppTheme.surface : tone.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: isRead ? AppTheme.surfaceBorder : tone.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingSm),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusXs),
              ),
              child: Icon(icon, color: tone, size: 20),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['title']?.toString() ?? '',
                          style: TextStyle(
                            color: AppTheme.ink,
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingXs),
                  Text(
                    item['body']?.toString() ?? '',
                    style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeSm, height: 1.35),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    category.toUpperCase(),
                    style: TextStyle(color: tone, fontSize: AppTheme.fontSizeXs, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
