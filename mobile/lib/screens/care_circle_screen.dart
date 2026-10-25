import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';

class CareCircleScreen extends StatefulWidget {
  const CareCircleScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<CareCircleScreen> createState() => _CareCircleScreenState();
}

class _CareCircleScreenState extends State<CareCircleScreen> {
  List<dynamic> _circles = [];
  bool _isLoading = true;
  String? _error;
  String? _myUserId;

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
        widget.apiClient.myCareCircles(),
        widget.apiClient.me(),
      ]);
      if (!mounted) return;
      _circles = (results[0]['circles'] as List<dynamic>? ?? const []);
      _myUserId = results[1]['user']?['id']?.toString();
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
        title: const Text('Care Circle'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const CCLoading()
          : _error != null
              ? CCError(message: _error!, onRetry: _load)
              : _circles.isEmpty
                  ? _buildNoCircle()
                  : _buildCircleDetails(),
    );
  }

  Widget _buildNoCircle() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingXxl),
              decoration: BoxDecoration(
                color: AppTheme.tealLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group_add, color: AppTheme.teal, size: 64),
            ),
            const SizedBox(height: AppTheme.spacingXxl),
            const Text(
              'No Care Circle Yet',
              style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w800, color: AppTheme.ink),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            const Text(
              'Create your Care Circle to invite family members and caregivers to support your health journey.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeLg, height: 1.4),
            ),
            const SizedBox(height: AppTheme.spacingXxl2),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _createCircle,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.teal,
                  foregroundColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
                ),
                child: const Text('Create Care Circle', style: TextStyle(fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleDetails() {
    final circle = _circles.first;
    final members = (circle['members'] as List<dynamic>? ?? const []);
    final inviteCode = circle['inviteCode']?.toString() ?? '';
    final circleName = circle['name']?.toString() ?? 'Care Circle';
    // Circle management (invite/remove) is reserved for the owning elder;
    // the backend enforces this independently of the UI.
    final canManage = _myUserId != null && _myUserId == circle['elderId']?.toString();
    final pending = (circle['pendingInvitations'] as List<dynamic>? ?? const []);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        children: [
          _buildCircleHeader(circleName, inviteCode),
          const SizedBox(height: AppTheme.spacingXxl),
          if (canManage) ...[
            _buildInviteSection(),
            const SizedBox(height: AppTheme.spacingXxl),
          ],
          if (canManage && pending.isNotEmpty) ...[
            _buildPendingSection(pending),
            const SizedBox(height: AppTheme.spacingXxl),
          ],
          const Text('Members', style: TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
          const SizedBox(height: AppTheme.spacingXs),
          Text('${members.length} member${members.length == 1 ? '' : 's'}', style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: AppTheme.spacingLg),
          ...members.map((m) => _buildMemberCard(m, circle['id']?.toString() ?? '', canManage: canManage)),
        ],
      ),
    );
  }

  Widget _buildPendingSection(List<dynamic> pending) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pending Invitations',
            style: TextStyle(fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        const SizedBox(height: AppTheme.spacingSm),
        ...pending.map((inv) {
          final email = inv['email']?.toString() ?? '';
          final relation = inv['relation']?.toString() ?? '';
          final label = relation == 'caregiver' ? 'Caregiver' : 'Family';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.amberLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: AppTheme.amber),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: AppTheme.muted, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$email — invited as $label (pending acceptance)',
                    style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCircleHeader(String name, String inviteCode) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXxl),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.3)),
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
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: AppTheme.tealLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: const Icon(Icons.groups, color: AppTheme.teal, size: 28),
              ),
              const SizedBox(width: AppTheme.spacingLg),
              Expanded(
                child: Text(name, style: const TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXl),
          const Text('Invite Code', style: TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeSm, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spacingSm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    inviteCode,
                    style: const TextStyle(fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.w800, color: AppTheme.teal, letterSpacing: 1.5),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied to clipboard')),
                    );
                  },
                  icon: const Icon(Icons.copy, color: AppTheme.teal, size: 20),
                  tooltip: 'Copy invite code',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          const Text(
            'Share this code with family members or caregivers so they can join your Care Circle.',
            style: TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeSm, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteSection() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _openInviteDialog,
        icon: const Icon(Icons.person_add, size: 20),
        label: const Text('Invite Member', style: TextStyle(fontSize: AppTheme.fontSizeLg, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.teal,
          side: const BorderSide(color: AppTheme.teal, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        ),
      ),
    );
  }

  Widget _buildMemberCard(dynamic member, String circleId, {required bool canManage}) {
    final name = member['name']?.toString() ?? 'Unknown';
    final relation = member['relation']?.toString() ?? 'other';
    final userId = member['userId']?.toString() ?? '';

    final isElder = relation == 'elder';
    final Color chipColor;
    final String chipLabel;
    switch (relation) {
      case 'elder':
        chipColor = AppTheme.teal;
        chipLabel = 'Elder';
        break;
      case 'family':
        chipColor = AppTheme.coral;
        chipLabel = 'Family';
        break;
      case 'caregiver':
        chipColor = AppTheme.tealDark;
        chipLabel = 'Caregiver';
        break;
      default:
        chipColor = AppTheme.muted;
        chipLabel = relation[0].toUpperCase() + relation.substring(1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
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
          AvatarCircle(name: name, radius: 24, color: chipColor),
          const SizedBox(width: AppTheme.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: AppTheme.fontSizeLg, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                const SizedBox(height: AppTheme.spacingXs),
                StatusBadge(label: chipLabel, color: chipColor),
              ],
            ),
          ),
          if (!isElder && canManage)
            IconButton(
              onPressed: () => _confirmRemoveMember(name, userId, circleId),
              icon: const Icon(Icons.remove_circle_outline, color: AppTheme.sosRed, size: 24),
              tooltip: 'Remove member',
            ),
        ],
      ),
    );
  }

  void _createCircle() async {
    try {
      await widget.apiClient.createCareCircle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Care Circle created successfully')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create Care Circle: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.sosRed,
          ),
        );
      }
    }
  }

  void _openInviteDialog() {
    final emailController = TextEditingController();
    String selectedRelation = 'family';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Invite Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  hintText: 'member@example.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              DropdownButtonFormField<String>(
                initialValue: selectedRelation,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'family', child: Text('Family')),
                  DropdownMenuItem(value: 'caregiver', child: Text('Caregiver')),
                ],
                onChanged: (v) => setDialogState(() => selectedRelation = v ?? 'family'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty) return;
                Navigator.of(ctx).pop();
                try {
                  final circle = _circles.first;
                  await widget.apiClient.inviteToCareCircle(
                    circleId: circle['id']?.toString() ?? '',
                    email: email,
                    relation: selectedRelation,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invitation sent successfully')),
                    );
                    _load();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to invite: ${e.toString().replaceFirst('Exception: ', '')}'),
                        backgroundColor: AppTheme.sosRed,
                      ),
                    );
                  }
                }
              },
              child: const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveMember(String name, String userId, String circleId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove $name from your Care Circle? They will lose access to your health data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await widget.apiClient.removeMember(circleId: circleId, userId: userId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$name removed from Care Circle')),
                  );
                  _load();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to remove: ${e.toString().replaceFirst('Exception: ', '')}'),
                      backgroundColor: AppTheme.sosRed,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.sosRed),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
