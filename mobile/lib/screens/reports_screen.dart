import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.apiClient, required this.elderId});

  final ApiClient apiClient;
  final String elderId;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _period = 'weekly';
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  bool _isDownloading = false;
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
      _data = await widget.apiClient.reportSummary(widget.elderId, period: _period);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadAndShare() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final bytes = await widget.apiClient.downloadReportPdf(widget.elderId, period: _period);
      if (bytes.length < 4 || String.fromCharCodes(bytes.sublist(0, 4)) != '%PDF') {
        throw Exception('Report download failed.');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${reportPdfFileName(_period, DateTime.now())}');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf', name: reportPdfFileName(_period, DateTime.now()))],
        text: 'CareCircle $_period health report',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report ready to share.')),
        );
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
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Health Report'),
        actions: [
          IconButton(
            onPressed: _isDownloading ? null : _downloadAndShare,
            icon: const Icon(Icons.share),
            tooltip: 'Download / share PDF',
          ),
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
                    padding: const EdgeInsets.all(AppTheme.spacingXl),
                    children: [
                      _buildPeriodSelector(),
                      const SizedBox(height: AppTheme.spacingXl),
                      _buildSummaryCard(),
                      const SizedBox(height: AppTheme.spacingXl),
                      const Text('Metrics', style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                      const SizedBox(height: AppTheme.spacingMd),
                      ..._buildMetrics(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXs),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _periodButton('weekly', 'Weekly'),
          ),
          Expanded(
            child: _periodButton('monthly', 'Monthly'),
          ),
        ],
      ),
    );
  }

  Widget _periodButton(String value, String label) {
    final selected = _period == value;
    return GestureDetector(
      onTap: () {
        if (_period != value) {
          setState(() => _period = value);
          _load();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
        decoration: BoxDecoration(
          color: selected ? AppTheme.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppTheme.surface : AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final summary = _data?['summary']?.toString() ?? 'No summary available.';

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assessment, color: AppTheme.teal, size: 22),
              SizedBox(width: AppTheme.spacingSm),
              Text('Summary', style: TextStyle(fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(summary, style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeMd, height: 1.5)),
          const SizedBox(height: AppTheme.spacingMd),
          Text('Generated: ${_data?['generatedAt'] ?? ''}',
              style: const TextStyle(color: AppTheme.subtle, fontSize: AppTheme.fontSizeSm)),
        ],
      ),
    );
  }

  List<Widget> _buildMetrics() {
    final metrics = [
      _MetricData('Vital Readings', '${_data?['vitalsCount'] ?? 0}', Icons.monitor_heart, AppTheme.teal),
      _MetricData('Abnormal Readings', '${_data?['abnormalVitalsCount'] ?? 0}', Icons.warning_amber, AppTheme.sosRed),
      _MetricData('Medication Adherence', '${_data?['medicationAdherencePercent'] ?? 0}%', Icons.medication, AppTheme.green),
      _MetricData('Hydration', '${_data?['hydrationMl'] ?? 0} ml', Icons.water_drop, AppTheme.teal),
      _MetricData('Exercise', '${_data?['exerciseMinutes'] ?? 0} min', Icons.fitness_center, AppTheme.coral),
      _MetricData('Appointments', '${_data?['appointmentCount'] ?? 0}', Icons.calendar_month, AppTheme.tealDark),
      _MetricData('Active SOS', '${_data?['activeSosCount'] ?? 0}', Icons.emergency, AppTheme.sosRed),
    ];

    return metrics.map((m) => Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: m.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(m.icon, color: m.color, size: 22),
          ),
          const SizedBox(width: AppTheme.spacingLg),
          Expanded(
            child: Text(m.label, style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeMd)),
          ),
          Text(m.value, style: TextStyle(color: m.color, fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.w800)),
        ],
      ),
    )).toList();
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}
