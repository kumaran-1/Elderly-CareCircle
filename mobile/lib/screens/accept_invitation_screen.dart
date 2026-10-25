import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';

class AcceptInvitationScreen extends StatefulWidget {
  const AcceptInvitationScreen({super.key, required this.apiClient, required this.onAccepted});

  final ApiClient apiClient;
  final VoidCallback onAccepted;

  @override
  State<AcceptInvitationScreen> createState() => _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState extends State<AcceptInvitationScreen> {
  final _codeController = TextEditingController();
  String _selectedRelation = 'family';
  bool _isLoading = false;
  String? _error;
  List<dynamic> _pending = [];
  bool _isLoadingPending = true;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    try {
      final data = await widget.apiClient.myInvitations();
      if (!mounted) return;
      setState(() {
        _pending = (data['invitations'] as List<dynamic>? ?? const []);
        _isLoadingPending = false;
      });
      if (_pending.isNotEmpty) {
        _useInvitation(_pending.first);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPending = false);
    }
  }

  void _useInvitation(dynamic invitation) {
    _codeController.text = invitation['inviteCode']?.toString() ?? '';
    final relation = invitation['relation']?.toString() ?? 'family';
    setState(() {
      _selectedRelation = relation == 'caregiver' ? 'caregiver' : 'family';
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter an invite code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.apiClient.acceptInvitation(
        inviteCode: code,
        relation: _selectedRelation,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully joined Care Circle!')),
      );
      widget.onAccepted();
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Accept Invitation'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingXxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingXl),
                  decoration: BoxDecoration(
                    color: AppTheme.tealLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mail_outline, color: AppTheme.teal, size: 56),
                ),
                const SizedBox(height: AppTheme.spacingXxl),
                const Text(
                  'Join a Care Circle',
                  style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w800, color: AppTheme.ink),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                const Text(
                  'Enter the invite code shared by your elder or circle owner.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeLg, height: 1.4),
                ),
                if (!_isLoadingPending && _pending.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingXl),
                  ..._pending.map((inv) {
                    final circleName = inv['circleName']?.toString() ?? 'Care Circle';
                    final relation = inv['relation']?.toString() ?? 'family';
                    final label = relation == 'caregiver' ? 'Caregiver' : 'Family';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _useInvitation(inv),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.tealLight,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            border: Border.all(color: AppTheme.teal),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.mark_email_unread_outlined, color: AppTheme.teal),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$circleName — invited as $label. Tap to fill code.',
                                  style: const TextStyle(color: AppTheme.tealDark, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: AppTheme.spacingXxl2),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Invite Code',
                    hintText: 'CIRCLE-XXXX-000',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLg),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRelation,
                  decoration: const InputDecoration(
                    labelText: 'Your Relationship',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'family', child: Text('Family')),
                    DropdownMenuItem(value: 'caregiver', child: Text('Caregiver')),
                  ],
                  onChanged: (v) => setState(() => _selectedRelation = v ?? 'family'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppTheme.spacingLg),
                  Text(_error!, style: const TextStyle(color: AppTheme.sosRed, fontSize: AppTheme.fontSizeMd)),
                ],
                const SizedBox(height: AppTheme.spacingXxl),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _accept,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.teal,
                      foregroundColor: AppTheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.surface),
                          )
                        : const Text('Join Circle', style: TextStyle(fontSize: AppTheme.fontSizeLg, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
