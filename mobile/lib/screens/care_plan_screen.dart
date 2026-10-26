import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';

class CarePlanScreen extends StatefulWidget {
  const CarePlanScreen({
    super.key,
    required this.apiClient,
    required this.elderId,
    required this.elderName,
    this.canManage = true,
    this.showJournal = true,
  });

  final ApiClient apiClient;
  final String elderId;
  final String elderName;
  final bool canManage;
  final bool showJournal;

  @override
  State<CarePlanScreen> createState() => _CarePlanScreenState();
}

class _CarePlanScreenState extends State<CarePlanScreen> {
  List<dynamic> _tasks = [];
  List<dynamic> _notes = [];
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
      final results = await Future.wait([
        widget.apiClient.careTasks(widget.elderId),
        if (widget.showJournal) widget.apiClient.careNotes(widget.elderId),
      ]);
      if (!mounted) return;
      setState(() {
        _tasks = (results[0]['tasks'] as List<dynamic>? ?? const []);
        _notes = widget.showJournal && results.length > 1
            ? (results[1]['notes'] as List<dynamic>? ?? const [])
            : const [];
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleTask(Map<String, dynamic> task) async {
    final taskId = task['id']?.toString();
    if (taskId == null) return;
    final nextStatus =
        task['status']?.toString() == 'completed' ? 'pending' : 'completed';
    try {
      await widget.apiClient.updateCareTask(
        taskId: taskId,
        elderId: widget.elderId,
        status: nextStatus,
      );
      if (mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Unable to update task: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: AppTheme.sosRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        _tasks.where((task) => task['status']?.toString() == 'pending').length;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.elderName.isEmpty
            ? 'Care Plan'
            : '${widget.elderName} Care Plan'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          if (widget.canManage)
            IconButton(
                onPressed: _openAddTask, icon: const Icon(Icons.playlist_add)),
        ],
      ),
      body: _isLoading
          ? const CCLoading()
          : _error != null
              ? CCError(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    children: [
                      _buildHeader(pending),
                      const SizedBox(height: AppTheme.spacingLg),
                      _buildTasksSection(),
                      if (widget.showJournal) ...[
                        const SizedBox(height: AppTheme.spacingLg),
                        _buildNotesSection(),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(int pending) {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: AppTheme.tealLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: const Icon(Icons.assignment_turned_in,
                color: AppTheme.teal, size: 30),
          ),
          const SizedBox(width: AppTheme.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Shared care plan',
                    style: TextStyle(
                        fontSize: AppTheme.fontSizeXl,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink)),
                const SizedBox(height: AppTheme.spacingXs),
                Text(
                  '$pending pending task${pending == 1 ? '' : 's'} · ${_tasks.length} total',
                  style: const TextStyle(
                      color: AppTheme.muted, fontSize: AppTheme.fontSizeMd),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksSection() {
    return SectionCard(
      title: 'Care Tasks',
      icon: Icons.checklist_rtl,
      tone: AppTheme.teal,
      trailing: widget.canManage
          ? TextButton.icon(
              onPressed: _openAddTask,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            )
          : null,
      children: [
        if (_tasks.isEmpty)
          const Text('No care tasks yet.',
              style: TextStyle(
                  color: AppTheme.muted, fontSize: AppTheme.fontSizeMd))
        else
          ..._tasks.map((task) => _buildTaskTile(task as Map<String, dynamic>)),
      ],
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final completed = task['status']?.toString() == 'completed';
    final priority = task['priority']?.toString() ?? 'medium';
    final dueAt = task['dueAt']?.toString();
    final notes = task['notes']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: completed ? AppTheme.subtle : AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
            color: completed ? AppTheme.surfaceBorder : AppTheme.tealLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => _toggleTask(task),
            tooltip: completed ? 'Mark pending' : 'Mark completed',
            icon: Icon(
              completed ? Icons.check_circle : Icons.radio_button_unchecked,
              color: completed ? AppTheme.green : AppTheme.teal,
              size: 28,
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title']?.toString() ?? 'Care task',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeLg,
                    fontWeight: FontWeight.w700,
                    color: completed ? AppTheme.muted : AppTheme.ink,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingXs),
                  Text(notes,
                      style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: AppTheme.fontSizeMd)),
                ],
                const SizedBox(height: AppTheme.spacingSm),
                Wrap(
                  spacing: AppTheme.spacingSm,
                  runSpacing: AppTheme.spacingSm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PriorityBadge(priority: priority),
                    if (dueAt != null && dueAt.isNotEmpty)
                      Text(
                        'Due ${formatDateTime(dueAt)}',
                        style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: AppTheme.fontSizeSm),
                      ),
                    if (completed)
                      const StatusBadge(
                          label: 'Completed', color: AppTheme.green)
                    else
                      const StatusBadge(
                          label: 'Pending', color: AppTheme.amber),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return SectionCard(
      title: 'Care Journal & Handover',
      icon: Icons.menu_book,
      tone: AppTheme.coral,
      trailing: widget.canManage
          ? TextButton.icon(
              onPressed: _openAddNote,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            )
          : null,
      children: [
        if (_notes.isEmpty)
          const Text('No notes or handovers yet.',
              style: TextStyle(
                  color: AppTheme.muted, fontSize: AppTheme.fontSizeMd))
        else
          ..._notes.map((note) => _buildNoteTile(note as Map<String, dynamic>)),
      ],
    );
  }

  Widget _buildNoteTile(Map<String, dynamic> note) {
    final isHandover = note['type']?.toString() == 'handover';
    final shift = note['shift']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isHandover ? Icons.swap_horiz : Icons.sticky_note_2_outlined,
                  size: 20, color: AppTheme.coral),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Text(
                  note['title']?.toString() ??
                      (isHandover ? 'Handover' : 'Care note'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: AppTheme.fontSizeLg,
                      color: AppTheme.ink),
                ),
              ),
              if (isHandover)
                StatusBadge(label: shift ?? 'handover', color: AppTheme.coral)
              else
                const StatusBadge(label: 'note', color: AppTheme.teal),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(note['body']?.toString() ?? '',
              style: const TextStyle(
                  color: AppTheme.muted, fontSize: AppTheme.fontSizeMd)),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            formatDateTime(note['createdAt']?.toString() ?? ''),
            style: const TextStyle(
                color: AppTheme.subtle, fontSize: AppTheme.fontSizeSm),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddTask() async {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    var priority = 'medium';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add care task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Task', border: OutlineInputBorder()),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(
                      labelText: 'Priority', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => priority = value ?? 'medium'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().length < 2) return;
                Navigator.of(ctx).pop(true);
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.teal),
              child: const Text('Add task'),
            ),
          ],
        ),
      ),
    );
    if (result != true) {
      titleController.dispose();
      notesController.dispose();
      return;
    }
    try {
      await widget.apiClient.createCareTask(
        elderId: widget.elderId,
        title: titleController.text.trim(),
        notes: notesController.text.trim(),
        priority: priority,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Care task added')));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Unable to add task: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.sosRed,
          ),
        );
      }
    } finally {
      titleController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _openAddNote() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    var type = 'note';
    var shift = 'afternoon';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add care note'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(
                      labelText: 'Entry type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'note', child: Text('Care note')),
                    DropdownMenuItem(
                        value: 'handover', child: Text('Shift handover')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => type = value ?? 'note'),
                ),
                if (type == 'handover') ...[
                  const SizedBox(height: AppTheme.spacingMd),
                  DropdownButtonFormField<String>(
                    initialValue: shift,
                    decoration: const InputDecoration(
                        labelText: 'Shift', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(
                          value: 'morning', child: Text('Morning')),
                      DropdownMenuItem(
                          value: 'afternoon', child: Text('Afternoon')),
                      DropdownMenuItem(
                          value: 'evening', child: Text('Evening')),
                      DropdownMenuItem(value: 'night', child: Text('Night')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => shift = value ?? 'afternoon'),
                  ),
                ],
                const SizedBox(height: AppTheme.spacingMd),
                TextField(
                  controller: titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                TextField(
                  controller: bodyController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: 'Details', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().length < 2 ||
                    bodyController.text.trim().length < 2) {
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.teal),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result != true) {
      titleController.dispose();
      bodyController.dispose();
      return;
    }
    try {
      await widget.apiClient.createCareNote(
        elderId: widget.elderId,
        type: type,
        title: titleController.text.trim(),
        body: bodyController.text.trim(),
        shift: type == 'handover' ? shift : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Care note added')));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Unable to add note: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.sosRed,
          ),
        );
      }
    } finally {
      titleController.dispose();
      bodyController.dispose();
    }
  }
}
