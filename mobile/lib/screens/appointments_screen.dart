import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key, required this.apiClient, required this.elderId});

  final ApiClient apiClient;
  final String elderId;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<dynamic> _appointments = [];
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
      final data = await widget.apiClient.appointmentsForElder(widget.elderId);
      _appointments = (data['appointments'] as List<dynamic>? ?? const []);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createAppointment() => _openAppointmentDialog();

  Future<void> _openAppointmentDialog({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['doctorName']?.toString() ?? '');
    final specCtrl = TextEditingController(text: existing?['specialty']?.toString() ?? '');
    final notesCtrl = TextEditingController(text: existing?['notes']?.toString() ?? '');
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final existingDt = DateTime.tryParse(existing?['dateTime']?.toString() ?? '');
    if (existingDt != null) {
      selectedDate = DateTime(existingDt.year, existingDt.month, existingDt.day);
      selectedTime = TimeOfDay(hour: existingDt.hour, minute: existingDt.minute);
    }

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New Appointment' : 'Reschedule Appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Doctor Name'),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                TextField(
                  controller: specCtrl,
                  decoration: const InputDecoration(labelText: 'Specialty'),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setDialogState(() => selectedDate = date);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      selectedDate != null
                          ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                          : 'Select date',
                      style: TextStyle(
                        color: selectedDate != null ? AppTheme.ink : AppTheme.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                InkWell(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: selectedTime ?? TimeOfDay.now(),
                    );
                    if (time != null) setDialogState(() => selectedTime = time);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Time',
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(
                      selectedTime != null
                          ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                          : 'Select time',
                      style: TextStyle(
                        color: selectedTime != null ? AppTheme.ink : AppTheme.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (created != true) return;

    if (selectedDate == null || nameCtrl.text.trim().isEmpty || specCtrl.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in doctor name, specialty, and select a date.')),
        );
      }
      return;
    }

    final dt = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime?.hour ?? 9,
      selectedTime?.minute ?? 0,
    );

    try {
      final notes = notesCtrl.text.trim();
      if (existing == null) {
        await widget.apiClient.createAppointment(
          elderId: widget.elderId,
          doctorName: nameCtrl.text.trim(),
          specialty: specCtrl.text.trim(),
          dateTime: dt.toUtc().toIso8601String(),
          notes: notes.isEmpty ? null : notes,
        );
      } else {
        await widget.apiClient.updateAppointment(
          appointmentId: existing['id']?.toString() ?? '',
          elderId: widget.elderId,
          doctorName: nameCtrl.text.trim(),
          specialty: specCtrl.text.trim(),
          dateTime: dt.toUtc().toIso8601String(),
          notes: notes,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(existing == null ? 'Appointment created.' : 'Appointment updated.')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    }
  }

  Future<void> _confirmCancel(Map<String, dynamic> appt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: Text(
          'Cancel the appointment with ${appt['doctorName'] ?? 'this doctor'}? '
          'Future reminders for it will stop.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.sosRed),
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.apiClient.cancelAppointment(
        appointmentId: appt['id']?.toString() ?? '',
        elderId: widget.elderId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment cancelled.')),
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
        title: const Text('Appointments'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createAppointment,
        backgroundColor: AppTheme.teal,
        foregroundColor: AppTheme.surface,
        icon: const Icon(Icons.add),
        label: const Text('New Appointment'),
      ),
      body: _isLoading
          ? const CCLoading()
          : _error != null
              ? CCError(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _appointments.isEmpty
                      ? CCEmpty(
                          icon: Icons.calendar_month,
                          message: 'No appointments yet.\nTap the button below to schedule one.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(AppTheme.spacingXl, AppTheme.spacingXl, AppTheme.spacingXl, 100),
                          itemCount: _appointments.length,
                          itemBuilder: (context, index) {
                            final appt = _appointments[index];
                            final dt = DateTime.tryParse(appt['dateTime']?.toString() ?? '');
                            final isPast = dt != null && dt.isBefore(DateTime.now());
                            final isCancelled = appt['status']?.toString() == 'cancelled';
                            final dimmed = isPast || isCancelled;
                            return Container(
                              margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                              padding: const EdgeInsets.all(AppTheme.spacingXl),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                                border: Border.all(
                                  color: dimmed ? AppTheme.surfaceBorder : AppTheme.teal.withValues(alpha: 0.3),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                                    decoration: BoxDecoration(
                                      color: (dimmed ? AppTheme.muted : AppTheme.teal).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                    ),
                                    child: Icon(
                                      Icons.calendar_month,
                                      color: dimmed ? AppTheme.muted : AppTheme.teal,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingLg),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (isCancelled) ...[
                                          const Text('CANCELLED',
                                              style: TextStyle(
                                                  color: AppTheme.sosRed,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: AppTheme.fontSizeSm)),
                                          const SizedBox(height: AppTheme.spacingXs),
                                        ],
                                        Text(appt['doctorName']?.toString() ?? '',
                                            style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w800, fontSize: AppTheme.fontSizeLg)),
                                        const SizedBox(height: AppTheme.spacingXs),
                                        Text(appt['specialty']?.toString() ?? '',
                                            style: const TextStyle(color: AppTheme.teal, fontSize: AppTheme.fontSizeMd)),
                                        const SizedBox(height: AppTheme.spacingSm),
                                        Text(
                                          dt != null
                                              ? '${dt.day}/${dt.month}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}'
                                              : appt['dateTime']?.toString() ?? '',
                                          style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeSm),
                                        ),
                                        if (appt['notes'] != null && appt['notes'].toString().isNotEmpty) ...[
                                          const SizedBox(height: AppTheme.spacingSm),
                                          Text(appt['notes'].toString(),
                                              style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeSm)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (!isCancelled)
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () => _openAppointmentDialog(existing: appt),
                                          icon: const Icon(Icons.edit_outlined, color: AppTheme.teal),
                                          tooltip: 'Reschedule',
                                        ),
                                        IconButton(
                                          onPressed: () => _confirmCancel(appt),
                                          icon: const Icon(Icons.cancel_outlined, color: AppTheme.sosRed),
                                          tooltip: 'Cancel appointment',
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
