import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';

class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key, required this.apiClient, required this.elderId});

  final ApiClient apiClient;
  final String elderId;

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  Map<String, dynamic>? _data;
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
      _data = await widget.apiClient.vitalsForElder(widget.elderId);
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
        title: const Text('Vitals'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openLogVitalDialog,
        backgroundColor: AppTheme.teal,
        foregroundColor: AppTheme.surface,
        icon: const Icon(Icons.add),
        label: const Text('Log Vital'),
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
                      _buildOverview(),
                      const SizedBox(height: AppTheme.spacingXl),
                      _buildTrendChart(),
                      const SizedBox(height: AppTheme.spacingXl),
                      const Text('Recent Readings', style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                      const SizedBox(height: AppTheme.spacingMd),
                      ..._buildReadings(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildOverview() {
    final overview = _data?['overview'] as Map<String, dynamic>?;
    final latest = overview?['latest'] as Map<String, dynamic>?;
    final totalReadings = overview?['totalReadings'] ?? 0;
    final abnormalCount = overview?['abnormalCount'] ?? 0;
    final status = overview?['status']?.toString() ?? 'unknown';

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
          Row(
            children: [
              Icon(Icons.monitor_heart, color: _statusColor(status), size: 24),
              const SizedBox(width: AppTheme.spacingMd),
              Text('Overview', style: TextStyle(fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.w800, color: _statusColor(status))),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),
          _overviewRow('Total readings', '$totalReadings'),
          _overviewRow('Abnormal readings', '$abnormalCount'),
          _overviewRow('Status', status.toUpperCase()),
          if (latest != null) ...[
            const SizedBox(height: AppTheme.spacingMd),
            const Divider(),
            const SizedBox(height: AppTheme.spacingSm),
            Text('Latest: ${latest['type']} = ${latest['value']} ${latest['unit']}',
                style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeMd)),
            if (latest['systolic'] != null)
              Text('BP: ${latest['systolic']}/${latest['diastolic']} mmHg',
                  style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeMd)),
          ],
        ],
      ),
    );
  }

  Widget _overviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeMd)),
          Text(value, style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w700, fontSize: AppTheme.fontSizeMd)),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    final readings = (_data?['readings'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    if (readings.isEmpty) return const SizedBox.shrink();

    final heartRate = readings
        .where((r) => r['type']?.toString() == 'heartRate')
        .toList()
        .reversed
        .toList();
    final bloodSugar = readings
        .where((r) => r['type']?.toString() == 'bloodSugar')
        .toList()
        .reversed
        .toList();

    final hasHeartRate = heartRate.length >= 2;
    final hasBloodSugar = bloodSugar.length >= 2;

    if (!hasHeartRate && !hasBloodSugar) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Health Trends', style: TextStyle(fontSize: AppTheme.fontSizeLg, fontWeight: FontWeight.w800, color: AppTheme.ink)),
          const SizedBox(height: AppTheme.spacingLg),
          if (hasHeartRate) ...[
            const Text('Heart Rate (bpm)', style: TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.muted)),
            const SizedBox(height: AppTheme.spacingSm),
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(heartRate.length, (i) {
                        return FlSpot(i.toDouble(), (heartRate[i]['value'] as num).toDouble());
                      }),
                      isCurved: true,
                      color: AppTheme.teal,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.teal.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  minY: 0,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
          ],
          if (hasBloodSugar) ...[
            const Text('Blood Sugar (mg/dL)', style: TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.muted)),
            const SizedBox(height: AppTheme.spacingSm),
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(bloodSugar.length, (i) {
                        return FlSpot(i.toDouble(), (bloodSugar[i]['value'] as num).toDouble());
                      }),
                      isCurved: true,
                      color: AppTheme.teal,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.teal.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  minY: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildReadings() {
    final readings = (_data?['readings'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    if (readings.isEmpty) {
      return [
        CCEmpty(icon: Icons.monitor_heart_outlined, message: 'No vital readings recorded yet.'),
      ];
    }
    return readings.reversed.map((reading) {
      final tone = reading['status'] == 'abnormal' ? AppTheme.sosRed : AppTheme.teal;
      return Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: tone.withValues(alpha: 0.35)),
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
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${reading['type']} — ${reading['value']} ${reading['unit']}',
                      style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w700)),
                  if (reading['systolic'] != null)
                    Text('BP: ${reading['systolic']}/${reading['diastolic']} mmHg',
                        style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeSm)),
                  const SizedBox(height: AppTheme.spacingXs),
                  Text(reading['thresholdNote']?.toString() ?? '',
                      style: TextStyle(color: tone, fontSize: AppTheme.fontSizeSm)),
                ],
              ),
            ),
            ToneBadge(label: reading['status'].toString(), tone: tone),
          ],
        ),
      );
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'normal':
        return AppTheme.green;
      case 'abnormal':
        return AppTheme.sosRed;
      default:
        return AppTheme.muted;
    }
  }

  void _openLogVitalDialog() {
    String selectedType = 'heartRate';
    final valueController = TextEditingController();
    final systolicController = TextEditingController();
    final diastolicController = TextEditingController();

    final typeUnits = {
      'heartRate': 'bpm',
      'bloodSugar': 'mg/dL',
      'weight': 'kg',
      'temperature': '\u00B0C',
      'bloodPressure': 'mmHg',
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Log Vital Reading'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  items: const [
                    DropdownMenuItem(value: 'heartRate', child: Text('Heart Rate')),
                    DropdownMenuItem(value: 'bloodSugar', child: Text('Blood Sugar')),
                    DropdownMenuItem(value: 'bloodPressure', child: Text('Blood Pressure')),
                    DropdownMenuItem(value: 'weight', child: Text('Weight')),
                    DropdownMenuItem(value: 'temperature', child: Text('Temperature')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedType = v ?? 'heartRate'),
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                if (selectedType == 'bloodPressure') ...[
                  TextField(
                    controller: systolicController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Systolic (mmHg)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  TextField(
                    controller: diastolicController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Diastolic (mmHg)', border: OutlineInputBorder()),
                  ),
                ] else ...[
                  TextField(
                    controller: valueController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Value (${typeUnits[selectedType] ?? ''})',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                double? value;
                double? systolic;
                double? diastolic;
                String unit = typeUnits[selectedType] ?? '';

                if (selectedType == 'bloodPressure') {
                  systolic = double.tryParse(systolicController.text);
                  diastolic = double.tryParse(diastolicController.text);
                  if (systolic == null || diastolic == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter both systolic and diastolic values.')),
                    );
                    return;
                  }
                  if (!systolic.isFinite || !diastolic.isFinite || systolic < 0 || diastolic < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Blood pressure values must be 0 or above.')),
                    );
                    return;
                  }
                  value = systolic;
                } else {
                  value = double.tryParse(valueController.text);
                  if (value == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid value.')),
                    );
                    return;
                  }
                  if (!value.isFinite || value < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a value of 0 or above.')),
                    );
                    return;
                  }
                }

                Navigator.of(ctx).pop();
                try {
                  await widget.apiClient.logVital(
                    elderId: widget.elderId,
                    type: selectedType,
                    value: value,
                    unit: unit,
                    systolic: systolic,
                    diastolic: diastolic,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vital reading logged')),
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
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
