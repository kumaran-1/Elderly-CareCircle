import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';

class CareInstructionFormScreen extends StatefulWidget {
  const CareInstructionFormScreen({
    super.key,
    required this.apiClient,
    required this.elderId,
    required this.elderName,
  });

  final ApiClient apiClient;
  final String elderId;
  final String elderName;

  @override
  State<CareInstructionFormScreen> createState() => _CareInstructionFormScreenState();
}

class _CareInstructionFormScreenState extends State<CareInstructionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _priority = 'medium';
  String _category = 'general';
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await widget.apiClient.createCareInstruction(
        elderId: widget.elderId,
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        priority: _priority,
        category: _category,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Instruction sent successfully')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Care Instruction'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            decoration: BoxDecoration(
              color: AppTheme.tealLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Row(
              children: [
                AvatarCircle(name: widget.elderName, radius: 20, color: AppTheme.teal),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.elderName, style: const TextStyle(fontSize: AppTheme.fontSizeLg, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                      const SizedBox(height: 2),
                      const Text('Medical Records & Instructions', style: TextStyle(fontSize: AppTheme.fontSizeSm, color: AppTheme.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingXl),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Instruction Title', hintText: 'e.g., Medication reminder'),
                  validator: (v) => (v == null || v.trim().length < 2) ? 'Title must be at least 2 characters.' : null,
                ),
                const SizedBox(height: AppTheme.spacingLg),
                TextFormField(
                  controller: _messageController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Instructions / Message',
                    hintText: 'Provide detailed care instructions...',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().length < 2) ? 'Message must be at least 2 characters.' : null,
                ),
                const SizedBox(height: AppTheme.spacingLg),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                  ],
                  onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                ),
                const SizedBox(height: AppTheme.spacingLg),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('General')),
                    DropdownMenuItem(value: 'medication', child: Text('Medication')),
                    DropdownMenuItem(value: 'vitals', child: Text('Vitals')),
                    DropdownMenuItem(value: 'lifestyle', child: Text('Lifestyle')),
                    DropdownMenuItem(value: 'scheduling', child: Text('Scheduling')),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? 'general'),
                ),
                const SizedBox(height: AppTheme.spacingXxl),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: AppTheme.sosRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Text(_error!, style: const TextStyle(color: AppTheme.sosRed, fontSize: AppTheme.fontSizeMd)),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                ],
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.teal,
                      foregroundColor: AppTheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.surface),
                          )
                        : const Text('Send Instruction', style: TextStyle(fontSize: AppTheme.fontSizeLg, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
