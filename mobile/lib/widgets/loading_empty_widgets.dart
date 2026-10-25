import 'package:flutter/material.dart';

import '../theme.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(color: AppTheme.muted, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.message,
    this.secondaryMessage,
  });

  final IconData icon;
  final String message;
  final String? secondaryMessage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 80),
            Icon(icon, color: AppTheme.muted, size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted, fontSize: 16),
            ),
            if (secondaryMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                secondaryMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
