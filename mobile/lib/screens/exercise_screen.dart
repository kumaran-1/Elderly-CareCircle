import 'package:flutter/material.dart';

import '../api_client.dart';
import '../responsive.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key, required this.apiClient, required this.elderId});

  final ApiClient apiClient;
  final String elderId;

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  Map<String, dynamic>? _summary;
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
      _summary = await widget.apiClient.exerciseSummary(widget.elderId);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logExercise(String activityType, double minutes) async {
    try {
      await widget.apiClient.logExercise(
        elderId: widget.elderId,
        activityType: activityType,
        minutes: minutes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged ${minutes.toInt()} min of $activityType')),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Exercise'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openLogDialog,
        backgroundColor: AppTheme.coral,
        foregroundColor: AppTheme.surface,
        icon: const Icon(Icons.add),
        label: const Text('Log Exercise'),
      ),
      body: _isLoading
          ? const CCLoading()
          : _error != null
              ? CCError(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppTheme.spacingXl),
                    children: [
                      _buildProgressCard(),
                      const SizedBox(height: AppTheme.spacingXl),
                      _buildQuickLog(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProgressCard() {
    final totalMinutes = _summary?['totalMinutes'] ?? 0;
    final goalMinutes = _summary?['weeklyGoalMinutes'] ?? 150;
    final progress = _summary?['progressPercent'] ?? 0;
    final circleSize = Responsive.progressCircleSize(context);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXxl),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(color: AppTheme.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (totalMinutes == 0) ...[
            const Icon(Icons.fitness_center, color: AppTheme.subtle, size: 48),
            const SizedBox(height: AppTheme.spacingMd),
            const Text('No exercise logged this week', style: TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeLg)),
            const SizedBox(height: AppTheme.spacingXs),
            const Text('Tap a button below to start tracking', style: TextStyle(color: AppTheme.subtle, fontSize: AppTheme.fontSizeSm)),
          ] else ...[
          SizedBox(
            height: circleSize,
            width: circleSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: circleSize,
                  width: circleSize,
                  child: CircularProgressIndicator(
                    value: progress / 100,
                    strokeWidth: 12,
                    backgroundColor: AppTheme.surfaceBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 100 ? AppTheme.green : AppTheme.coral,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalMinutes',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppTheme.ink),
                    ),
                    const Text('min', style: TextStyle(fontSize: AppTheme.fontSizeLg, color: AppTheme.muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text(
            'Weekly Goal: $goalMinutes min',
            style: const TextStyle(fontSize: AppTheme.fontSizeLg, color: AppTheme.muted),
          ),
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            '$progress% complete',
            style: TextStyle(
              fontSize: AppTheme.fontSizeLg,
              fontWeight: FontWeight.w700,
              color: progress >= 100 ? AppTheme.green : AppTheme.coral,
            ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Log', style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        const SizedBox(height: AppTheme.spacingMd),
        Row(
          children: [
            Expanded(child: _quickButton(Icons.directions_walk, 'Walking', 15)),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(child: _quickButton(Icons.run_circle, 'Running', 30)),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Row(
          children: [
            Expanded(child: _quickButton(Icons.self_improvement, 'Yoga', 30)),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(child: _quickButton(Icons.fitness_center, 'Strength', 20)),
          ],
        ),
      ],
    );
  }

  Widget _quickButton(IconData icon, String label, int minutes) {
    return SizedBox(
      height: 80,
      child: ElevatedButton(
        onPressed: () => _logExercise(label.toLowerCase(), minutes.toDouble()),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.coralLight,
          foregroundColor: AppTheme.coral,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            side: const BorderSide(color: AppTheme.surfaceBorder),
          ),
          elevation: 0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: AppTheme.spacingXs),
            Text(label, style: const TextStyle(fontSize: AppTheme.fontSizeSm, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  void _openLogDialog() {
    final activityCtrl = TextEditingController();
    final minutesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Exercise'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: activityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Activity Type',
                  hintText: 'e.g. Walking',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              TextField(
                controller: minutesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (minutes)',
                  hintText: 'e.g. 30',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final activity = activityCtrl.text.trim();
              final minutes = double.tryParse(minutesCtrl.text.trim());
              if (activity.isEmpty || minutes == null || minutes <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fill in all fields')),
                );
                return;
              }
              Navigator.pop(ctx);
              _logExercise(activity, minutes);
            },
            child: const Text('Log'),
          ),
        ],
      ),
    );
  }
}
