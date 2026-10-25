import 'package:flutter/material.dart';

import '../theme.dart';

class ErrorRetryWidget extends StatelessWidget {
  const ErrorRetryWidget({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline,
    this.iconSize = 48,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.danger, size: iconSize),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.danger, fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
