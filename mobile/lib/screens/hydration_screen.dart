import 'package:flutter/material.dart';

import '../api_client.dart';
import '../responsive.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';

class HydrationScreen extends StatefulWidget {
  const HydrationScreen({super.key, required this.apiClient, required this.elderId});

  final ApiClient apiClient;
  final String elderId;

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen> {
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
      _summary = await widget.apiClient.hydrationSummary(widget.elderId);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logHydration(double amountMl) async {
    try {
      await widget.apiClient.logHydration(elderId: widget.elderId, amountMl: amountMl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged ${amountMl.toInt()} ml')),
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
        title: const Text('Hydration'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openLogDialog,
        backgroundColor: AppTheme.teal,
        foregroundColor: AppTheme.surface,
        icon: const Icon(Icons.add),
        label: const Text('Log Water'),
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
    final totalMl = _summary?['totalMl'] ?? 0;
    final goalMl = _summary?['goalMl'] ?? 2000;
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
          if (totalMl == 0) ...[
            const Icon(Icons.water_drop_outlined, color: AppTheme.subtle, size: 48),
            const SizedBox(height: AppTheme.spacingMd),
            const Text('No water logged today', style: TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeLg)),
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
                      progress >= 100 ? AppTheme.green : AppTheme.teal,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalMl',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppTheme.ink),
                    ),
                    const Text('ml', style: TextStyle(fontSize: AppTheme.fontSizeLg, color: AppTheme.muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text(
            'Goal: $goalMl ml',
            style: const TextStyle(fontSize: AppTheme.fontSizeLg, color: AppTheme.muted),
          ),
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            '$progress% complete',
            style: TextStyle(
              fontSize: AppTheme.fontSizeLg,
              fontWeight: FontWeight.w700,
              color: progress >= 100 ? AppTheme.green : AppTheme.teal,
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
            Expanded(child: _quickButton(150, 'Small glass')),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(child: _quickButton(250, 'Regular')),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Row(
          children: [
            Expanded(child: _quickButton(350, 'Large glass')),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(child: _quickButton(500, 'Bottle')),
          ],
        ),
      ],
    );
  }

  Widget _quickButton(int ml, String label) {
    return SizedBox(
      height: 70,
      child: ElevatedButton(
        onPressed: () => _logHydration(ml.toDouble()),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.tealLight,
          foregroundColor: AppTheme.teal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            side: const BorderSide(color: AppTheme.surfaceBorder),
          ),
          elevation: 0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.water_drop, size: 24),
            const SizedBox(height: AppTheme.spacingXs),
            Text(label, style: const TextStyle(fontSize: AppTheme.fontSizeSm, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  void _openLogDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Water Intake'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount (ml)',
            hintText: 'e.g. 250',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final ml = double.tryParse(ctrl.text.trim());
              if (ml == null || ml <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid amount')),
                );
                return;
              }
              Navigator.pop(ctx);
              _logHydration(ml);
            },
            child: const Text('Log'),
          ),
        ],
      ),
    );
  }
}
