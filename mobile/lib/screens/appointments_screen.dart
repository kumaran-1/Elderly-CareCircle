import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen(
      {super.key, required this.apiClient, required this.elderId});

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
    final nameCtrl =
        TextEditingController(text: existing?['doctorName']?.toString() ?? '');
    final specCtrl =
        TextEditingController(text: existing?['specialty']?.toString() ?? '');
    final notesCtrl =
        TextEditingController(text: existing?['notes']?.toString() ?? '');
    final followUpNotesCtrl = TextEditingController(
        text: existing?['followUpNotes']?.toString() ?? '');
    void disposeControllers() {
      nameCtrl.dispose();
      specCtrl.dispose();
      notesCtrl.dispose();
      followUpNotesCtrl.dispose();
    }

    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    DateTime? followUpDate;
    TimeOfDay? followUpTime;
    final existingDt =
        DateTime.tryParse(existing?['dateTime']?.toString() ?? '');
    if (existingDt != null) {
      selectedDate =
          DateTime(existingDt.year, existingDt.month, existingDt.day);
      selectedTime =
          TimeOfDay(hour: existingDt.hour, minute: existingDt.minute);
    }
    final existingFollowUp =
        DateTime.tryParse(existing?['followUpAt']?.toString() ?? '');
    if (existingFollowUp != null) {
      followUpDate = DateTime(
          existingFollowUp.year, existingFollowUp.month, existingFollowUp.day);
      followUpTime = TimeOfDay(
          hour: existingFollowUp.hour, minute: existingFollowUp.minute);
    }

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
              existing == null ? 'New Appointment' : 'Reschedule Appointment'),
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
                    final today = DateUtils.dateOnly(DateTime.now());
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate:
                          selectedDate != null && !selectedDate!.isBefore(today)
                              ? selectedDate!
                              : today,
                      firstDate: today,
                      lastDate:
                          DateTime(today.year + 1, today.month, today.day),
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
                        color: selectedDate != null
                            ? AppTheme.ink
                            : AppTheme.muted,
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
                        color: selectedTime != null
                            ? AppTheme.ink
                            : AppTheme.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                TextField(
                  controller: notesCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Notes (optional)'),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Follow-up visit (optional)',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: AppTheme.fontSizeMd,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                InkWell(
                  onTap: () async {
                    final today = DateUtils.dateOnly(DateTime.now());
                    final suggested =
                        DateTime(today.year, today.month, today.day + 7);
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate:
                          followUpDate != null && !followUpDate!.isBefore(today)
                              ? followUpDate!
                              : suggested,
                      firstDate: today,
                      lastDate:
                          DateTime(today.year + 2, today.month, today.day),
                    );
                    if (date != null) setDialogState(() => followUpDate = date);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Follow-up date',
                      suffixIcon: Icon(Icons.event_repeat),
                    ),
                    child: Text(
                      followUpDate != null
                          ? '${followUpDate!.day}/${followUpDate!.month}/${followUpDate!.year}'
                          : 'Not scheduled',
                      style: TextStyle(
                        color: followUpDate != null
                            ? AppTheme.ink
                            : AppTheme.muted,
                      ),
                    ),
                  ),
                ),
                if (followUpDate != null) ...[
                  const SizedBox(height: AppTheme.spacingSm),
                  InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime:
                            followUpTime ?? const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (time != null) {
                        setDialogState(() => followUpTime = time);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Follow-up time',
                        suffixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(
                        followUpTime != null
                            ? '${followUpTime!.hour.toString().padLeft(2, '0')}:${followUpTime!.minute.toString().padLeft(2, '0')}'
                            : '09:00',
                        style: const TextStyle(color: AppTheme.ink),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.spacingSm),
                TextField(
                  controller: followUpNotesCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Follow-up notes (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(existing == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (created != true) {
      disposeControllers();
      return;
    }

    if (selectedDate == null ||
        nameCtrl.text.trim().isEmpty ||
        specCtrl.text.trim().isEmpty) {
      disposeControllers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Please fill in doctor name, specialty, and select a date.')),
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
    final followUpAt = followUpDate == null
        ? null
        : DateTime(
            followUpDate!.year,
            followUpDate!.month,
            followUpDate!.day,
            followUpTime?.hour ?? 9,
            followUpTime?.minute ?? 0,
          ).toUtc().toIso8601String();
    final notes = notesCtrl.text.trim();
    final followUpNotes = followUpNotesCtrl.text.trim();

    try {
      if (existing == null) {
        await widget.apiClient.createAppointment(
          elderId: widget.elderId,
          doctorName: nameCtrl.text.trim(),
          specialty: specCtrl.text.trim(),
          dateTime: dt.toUtc().toIso8601String(),
          notes: notes.isEmpty ? null : notes,
          followUpAt: followUpAt,
          followUpNotes: followUpAt == null || followUpNotes.isEmpty
              ? null
              : followUpNotes,
        );
      } else {
        await widget.apiClient.updateAppointment(
          appointmentId: existing['id']?.toString() ?? '',
          elderId: widget.elderId,
          doctorName: nameCtrl.text.trim(),
          specialty: specCtrl.text.trim(),
          dateTime: dt.toUtc().toIso8601String(),
          notes: notes,
          followUpAt: followUpAt,
          followUpNotes: followUpAt == null ? null : followUpNotes,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(existing == null
                  ? 'Appointment created.'
                  : 'Appointment updated.')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      disposeControllers();
    }
  }

  String _followUpLabel(String value) {
    final dt = DateTime.tryParse(value);
    if (dt == null) return 'Follow-up scheduled';
    return 'Follow-up: ${dt.day}/${dt.month}/${dt.year} at '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
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
            content:
                Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'),
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
                      ? const CCEmpty(
                          icon: Icons.calendar_month,
                          message:
                              'No appointments yet.\nTap the button below to schedule one.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(AppTheme.spacingXl,
                              AppTheme.spacingXl, AppTheme.spacingXl, 100),
                          itemCount: _appointments.length,
                          itemBuilder: (context, index) {
                            final appt = _appointments[index];
                            final dt = DateTime.tryParse(
                                appt['dateTime']?.toString() ?? '');
                            final isPast =
                                dt != null && dt.isBefore(DateTime.now());
                            final isCancelled =
                                appt['status']?.toString() == 'cancelled';
                            final dimmed = isPast || isCancelled;
                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: AppTheme.spacingMd),
                              padding: const EdgeInsets.all(AppTheme.spacingXl),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusLarge),
                                border: Border.all(
                                  color: dimmed
                                      ? AppTheme.surfaceBorder
                                      : AppTheme.teal.withValues(alpha: 0.3),
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
                                    padding: const EdgeInsets.all(
                                        AppTheme.spacingMd),
                                    decoration: BoxDecoration(
                                      color: (dimmed
                                              ? AppTheme.muted
                                              : AppTheme.teal)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusMedium),
                                    ),
                                    child: Icon(
                                      Icons.calendar_month,
                                      color: dimmed
                                          ? AppTheme.muted
                                          : AppTheme.teal,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingLg),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (isCancelled) ...[
                                          const Text('CANCELLED',
                                              style: TextStyle(
                                                  color: AppTheme.sosRed,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize:
                                                      AppTheme.fontSizeSm)),
                                          const SizedBox(
                                              height: AppTheme.spacingXs),
                                        ],
                                        Text(
                                            appt['doctorName']?.toString() ??
                                                '',
                                            style: const TextStyle(
                                                color: AppTheme.ink,
                                                fontWeight: FontWeight.w800,
                                                fontSize: AppTheme.fontSizeLg)),
                                        const SizedBox(
                                            height: AppTheme.spacingXs),
                                        Text(
                                            appt['specialty']?.toString() ?? '',
                                            style: const TextStyle(
                                                color: AppTheme.teal,
                                                fontSize: AppTheme.fontSizeMd)),
                                        const SizedBox(
                                            height: AppTheme.spacingSm),
                                        Text(
                                          dt != null
                                              ? '${dt.day}/${dt.month}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}'
                                              : appt['dateTime']?.toString() ??
                                                  '',
                                          style: const TextStyle(
                                              color: AppTheme.muted,
                                              fontSize: AppTheme.fontSizeSm),
                                        ),
                                        if (appt['notes'] != null &&
                                            appt['notes']
                                                .toString()
                                                .isNotEmpty) ...[
                                          const SizedBox(
                                              height: AppTheme.spacingSm),
                                          Text(appt['notes'].toString(),
                                              style: const TextStyle(
                                                  color: AppTheme.muted,
                                                  fontSize:
                                                      AppTheme.fontSizeSm)),
                                        ],
                                        if (appt['followUpAt'] != null &&
                                            appt['followUpAt']
                                                .toString()
                                                .isNotEmpty) ...[
                                          const SizedBox(
                                              height: AppTheme.spacingSm),
                                          Container(
                                            padding: const EdgeInsets.all(
                                                AppTheme.spacingSm),
                                            decoration: BoxDecoration(
                                              color: AppTheme.warning
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppTheme.radiusSmall),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _followUpLabel(
                                                      appt['followUpAt']
                                                          .toString()),
                                                  style: const TextStyle(
                                                    color: AppTheme.ink,
                                                    fontSize:
                                                        AppTheme.fontSizeSm,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                if (appt['followUpNotes'] !=
                                                        null &&
                                                    appt['followUpNotes']
                                                        .toString()
                                                        .isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: AppTheme
                                                                .spacingXs),
                                                    child: Text(
                                                      appt['followUpNotes']
                                                          .toString(),
                                                      style: const TextStyle(
                                                        color: AppTheme.muted,
                                                        fontSize:
                                                            AppTheme.fontSizeSm,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (!isCancelled)
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () =>
                                              _openAppointmentDialog(
                                                  existing: appt),
                                          icon: const Icon(Icons.edit_outlined,
                                              color: AppTheme.teal),
                                          tooltip: 'Reschedule',
                                        ),
                                        IconButton(
                                          onPressed: () => _confirmCancel(appt),
                                          icon: const Icon(
                                              Icons.cancel_outlined,
                                              color: AppTheme.sosRed),
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
