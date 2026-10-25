import 'package:flutter/material.dart';

import '../api_client.dart';
import '../api_config.dart';
import '../theme.dart';
import '../widgets/cc_components.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.apiClient, required this.onLogout});

  final ApiClient apiClient;
  final Future<void> Function() onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _dashboard;
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
        widget.apiClient.me(),
        widget.apiClient.dashboard(),
      ]);
      _user = results[0]['user'] as Map<String, dynamic>?;
      _dashboard = results[1];
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
        title: const Text('Profile'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _openEditProfile, icon: const Icon(Icons.edit)),
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
                      _buildProfileHeader(),
                      const SizedBox(height: AppTheme.spacingXl),
                      _buildInfoSection(),
                      const SizedBox(height: AppTheme.spacingXl),
                      _buildRoleSection(),
                      const SizedBox(height: AppTheme.spacingXl),
                      _buildServerSection(),
                      const SizedBox(height: AppTheme.spacingXxl),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openChangePassword,
                          icon: const Icon(Icons.lock_outline),
                          label: const Text('Change Password'),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Sign Out'),
                                content: const Text('Are you sure you want to sign out?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: FilledButton.styleFrom(backgroundColor: AppTheme.sosRed),
                                    child: const Text('Sign Out'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) widget.onLogout();
                          },
                          icon: const Icon(Icons.logout, color: AppTheme.sosRed),
                          label: const Text('Sign Out', style: TextStyle(color: AppTheme.sosRed)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.sosRed),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    final name = _user?['name']?.toString() ?? 'User';
    final email = _user?['email']?.toString() ?? '';
    final role = _user?['role']?.toString() ?? 'unknown';
    final verified = _user?['verified'] == true;

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
          AvatarCircle(name: name, radius: 40, color: AppTheme.teal),
          const SizedBox(height: AppTheme.spacingLg),
          Text(name, style: const TextStyle(fontSize: AppTheme.fontSizeXxl, fontWeight: FontWeight.w900, color: AppTheme.ink)),
          const SizedBox(height: AppTheme.spacingXs),
          Text(email, style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: AppTheme.spacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StatusBadge(label: role.toUpperCase(), color: _roleColor(role)),
              const SizedBox(width: AppTheme.spacingSm),
              StatusBadge(
                label: verified ? 'VERIFIED' : 'UNVERIFIED',
                color: verified ? AppTheme.green : AppTheme.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    final profile = _user?['profile'] as Map<String, dynamic>? ?? {};
    final items = [
      if (profile['dateOfBirth'] != null) _InfoItem('Date of Birth', profile['dateOfBirth'].toString()),
      if (profile['contactNumber'] != null) _InfoItem('Contact', profile['contactNumber'].toString()),
      if (profile['medicalConditions'] != null)
        _InfoItem('Medical Conditions', (profile['medicalConditions'] as List<dynamic>).join(', ')),
      if (profile['allergies'] != null)
        _InfoItem('Allergies', (profile['allergies'] as List<dynamic>).join(', ')),
      _InfoItem('Account Created', _user?['createdAt']?.toString() ?? ''),
    ];

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
          const Text('Personal Information', style: TextStyle(fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
          const SizedBox(height: AppTheme.spacingLg),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      flex: 2,
                      child: Text(item.label, style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeMd)),
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    Expanded(
                      flex: 3,
                      child: Text(item.value, style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w600, fontSize: AppTheme.fontSizeMd)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildRoleSection() {
    final role = _user?['role']?.toString() ?? 'unknown';
    final title = _dashboard?['title']?.toString() ?? '';
    final actions = (_dashboard?['actions'] as List<dynamic>? ?? const []).cast<String>();

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
          const Text('Your Role', style: TextStyle(fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
          const SizedBox(height: AppTheme.spacingMd),
          Row(
            children: [
              Icon(_roleIcon(role), color: _roleColor(role), size: 24),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(child: Text(title, style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w600))),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingLg),
            const Text('Available Actions', style: TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeSm)),
            const SizedBox(height: AppTheme.spacingSm),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              children: actions.map((a) => Chip(
                    label: Text(a, style: const TextStyle(fontSize: AppTheme.fontSizeSm)),
                    backgroundColor: AppTheme.tealLight,
                    side: BorderSide.none,
                  )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServerSection() {
    final urlController = TextEditingController();
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Server', style: TextStyle(fontSize: AppTheme.fontSizeXl, fontWeight: FontWeight.w800, color: AppTheme.ink)),
          const SizedBox(height: AppTheme.spacingSm),
          Text('Current: ${widget.apiClient.baseUrl}',
              style: const TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeSm)),
          const SizedBox(height: AppTheme.spacingMd),
          const Text('Set a custom server URL (https) to switch environments. Restart the app to apply.',
              style: TextStyle(color: AppTheme.muted, fontSize: AppTheme.fontSizeSm)),
          const SizedBox(height: AppTheme.spacingMd),
          TextField(
            controller: urlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'https://api.example.com',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    try {
                      await ApiEndpointStore().saveOverride(urlController.text);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Server saved. Restart the app to apply.')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed: ${e.toString().replaceFirst('Exception: ', '').replaceFirst('Invalid argument(s): ', '')}'),
                            backgroundColor: AppTheme.sosRed,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save Server'),
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              TextButton(
                onPressed: () async {
                  await ApiEndpointStore().clearOverride();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Server reset. Restart the app to apply.')),
                    );
                  }
                },
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'elder':
        return AppTheme.teal;
      case 'family':
        return AppTheme.coral;
      case 'caregiver':
        return AppTheme.tealDark;
      default:
        return AppTheme.muted;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'elder':
        return Icons.elderly;
      case 'family':
        return Icons.family_restroom;
      case 'caregiver':
        return Icons.medical_services;
      default:
        return Icons.person;
    }
  }

  void _openEditProfile() {
    final profile = _user?['profile'] as Map<String, dynamic>? ?? {};
    final nameController = TextEditingController(text: _user?['name']?.toString() ?? '');
    final contactController = TextEditingController(text: profile['contactNumber']?.toString() ?? '');
    final dobController = TextEditingController(text: profile['dateOfBirth']?.toString() ?? '');
    final conditionsController = TextEditingController(
      text: (profile['medicalConditions'] as List<dynamic>?)?.join(', ') ?? '',
    );
    final allergiesController = TextEditingController(
      text: (profile['allergies'] as List<dynamic>?)?.join(', ') ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              TextField(
                controller: contactController,
                decoration: const InputDecoration(labelText: 'Contact Number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              TextField(
                controller: dobController,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  hintText: 'YYYY-MM-DD',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              TextField(
                controller: conditionsController,
                decoration: const InputDecoration(
                  labelText: 'Medical Conditions',
                  hintText: 'Comma-separated',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              TextField(
                controller: allergiesController,
                decoration: const InputDecoration(
                  labelText: 'Allergies',
                  hintText: 'Comma-separated',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name is required')),
                );
                return;
              }

              final conditions = conditionsController.text.trim();
              final allergies = allergiesController.text.trim();

              Navigator.of(ctx).pop();
              try {
                await widget.apiClient.updateProfile(
                  name: name,
                  profile: {
                    'contactNumber': contactController.text.trim().isNotEmpty ? contactController.text.trim() : null,
                    'dateOfBirth': dobController.text.trim().isNotEmpty ? dobController.text.trim() : null,
                    'medicalConditions': conditions.isNotEmpty
                        ? conditions.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
                        : null,
                    'allergies': allergies.isNotEmpty
                        ? allergies.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
                        : null,
                  },
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated')),
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
    );
  }

  void _openChangePassword() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                TextField(
                  controller: newCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                TextField(
                  controller: confirmCtrl,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final current = currentCtrl.text;
                final newPwd = newCtrl.text;
                final confirm = confirmCtrl.text;

                if (current.isEmpty || newPwd.isEmpty || confirm.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All fields are required')),
                  );
                  return;
                }
                if (newPwd.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New password must be at least 8 characters')),
                  );
                  return;
                }
                if (newPwd != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New passwords do not match')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                try {
                  await widget.apiClient.changePassword(
                    currentPassword: current,
                    newPassword: newPwd,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password changed successfully')),
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
                }
              },
              child: const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem {
  const _InfoItem(this.label, this.value);
  final String label;
  final String value;
}
