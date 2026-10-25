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
      final data = await widget.apiClient.notifications();
      _notifications = (data['notifications'] as List<dynamic>? ?? const []);
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
                  child: _notifications.isEmpty
                      ? CCEmpty(icon: Icons.notifications_none, message: 'No notifications yet.')
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppTheme.spacingXl),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final item = _notifications[index];
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
                          },
                        ),
                ),
    );
  }
}
