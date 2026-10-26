import 'package:flutter/material.dart';
import '../theme.dart';

// ─── Section Card ────────────────────────────────────────────────────────────
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.tone,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Color tone;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: tone.withValues(alpha: 0.2)),
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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                ),
                child: Icon(icon, color: tone, size: 20),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.w700, color: AppTheme.ink)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),
          ...children,
        ],
      ),
    );
  }
}

// ─── Key-Value Row ───────────────────────────────────────────────────────────
class KvRow extends StatelessWidget {
  const KvRow({super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodySm),
          Text(
            value,
            style: TextStyle(
              fontSize: AppTheme.fontSizeMd,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Priority Badge ──────────────────────────────────────────────────────────
class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (priority) {
      case 'urgent':
        color = AppTheme.sosRed;
        break;
      case 'high':
        color = AppTheme.coral;
        break;
      case 'medium':
        color = AppTheme.teal;
        break;
      default:
        color = AppTheme.muted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(fontSize: AppTheme.fontSizeXs, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

// ─── Status Badge ────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: AppTheme.fontSizeSm, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

// ─── Avatar Circle ───────────────────────────────────────────────────────────
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({super.key, required this.name, this.radius = 24, this.color = AppTheme.teal});

  final String name;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.12),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

// ─── Tone Badge (for vital status etc.) ─────────────────────────────────────
class ToneBadge extends StatelessWidget {
  const ToneBadge({super.key, required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(label.toUpperCase(), style: TextStyle(fontSize: AppTheme.fontSizeSm, fontWeight: FontWeight.w800, color: tone)),
    );
  }
}

// ─── Loading Widget ──────────────────────────────────────────────────────────
class CCLoading extends StatelessWidget {
  const CCLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(color: AppTheme.teal),
      ),
    );
  }
}

// ─── Error Widget ────────────────────────────────────────────────────────────
class CCError extends StatelessWidget {
  const CCError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.sosRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: AppTheme.sosRed, size: 40),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeMd)),
            const SizedBox(height: AppTheme.spacingXl),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────
class CCEmpty extends StatelessWidget {
  const CCEmpty({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.subtle, size: 56),
            const SizedBox(height: AppTheme.spacingLg),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeMd)),
          ],
        ),
      ),
    );
  }
}

// ─── Helper Functions ────────────────────────────────────────────────────────
Color toneFromString(String tone) {
  switch (tone) {
    case 'alert':
      return AppTheme.sosRed;
    case 'attention':
      return AppTheme.coral;
    default:
      return AppTheme.teal;
  }
}

Color categoryColor(String category) {
  switch (category) {
    case 'sos':
      return AppTheme.sosRed;
    case 'vital':
    case 'medication':
      return AppTheme.amber;
    case 'careInstruction':
    case 'careTask':
      return AppTheme.teal;
    case 'careNote':
      return AppTheme.coral;
    case 'ai':
      return AppTheme.tealDark;
    default:
      return AppTheme.teal;
  }
}

IconData categoryIcon(String category) {
  switch (category) {
    case 'sos':
      return Icons.warning_amber;
    case 'vital':
      return Icons.monitor_heart;
    case 'medication':
      return Icons.medication;
    case 'careInstruction':
      return Icons.comment;
    case 'careTask':
      return Icons.checklist_rtl;
    case 'careNote':
      return Icons.menu_book;
    case 'hydration':
      return Icons.water_drop;
    case 'exercise':
      return Icons.fitness_center;
    case 'appointment':
      return Icons.calendar_month;
    case 'ai':
      return Icons.smart_toy;
    default:
      return Icons.notifications;
  }
}

String formatDateTime(String dt) {
  final parsed = DateTime.tryParse(dt);
  if (parsed == null) return dt;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
}

String formatTime(String dt) {
  final parsed = DateTime.tryParse(dt);
  if (parsed == null) return dt;
  return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
}
