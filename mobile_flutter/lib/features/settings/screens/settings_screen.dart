import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart' show PackageInfo;
import '../../../core/router/app_router.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/colors.dart';
import '../../home/screens/home_screen.dart' show UserProfile;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

// Demo-mode credential sets — one per role
const _demoCredentials = [
  {'role': 'Owner',         'email': 'kannan@demo.orderlanepro.dev',  'password': 'demo1234'},
  {'role': 'Admin',         'email': 'priya@demo.orderlanepro.dev',   'password': 'demo1234'},
  {'role': 'Manager',       'email': 'senthil@demo.orderlanepro.dev', 'password': 'demo1234'},
  {'role': 'Sales Rep',     'email': 'rajan@demo.orderlanepro.dev',   'password': 'demo1234'},
  {'role': 'Warehouse',     'email': 'kumar@demo.orderlanepro.dev',   'password': 'demo1234'},
  {'role': 'Accountant',    'email': 'lakshmi@demo.orderlanepro.dev', 'password': 'demo1234'},
  {'role': 'Driver',        'email': 'muthu@demo.orderlanepro.dev',   'password': 'demo1234'},
];

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  UserProfile? _user;
  String _version = '';

  // Demo-mode easter egg
  int  _versionTapCount = 0;
  bool _demoModeHintVisible = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = ref.read(secureStorageProvider);
    final userJson = await storage.getUserJson();
    UserProfile? user;
    if (userJson != null) {
      try {
        user = UserProfile.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {}
    }

    String version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version} (${info.buildNumber})';
    } catch (_) {
      version = '—';
    }

    if (mounted) {
      setState(() {
        _user    = user;
        _version = version;
      });
    }
  }

  void _showDemoModeSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DemoModeSheet(
        onCredentialSelected: (cred) {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Demo credentials copied for ${cred['role']}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Navigate to login pre-filled
          context.go(
            AppRoutes.login,
            extra: {'email': cred['email'], 'password': cred['password']},
          );
        },
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:    const Text('Sign out?'),
        content:  const Text('You will be redirected to the login screen.'),
        actions:  [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign out', style: TextStyle(color: OlColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final storage = ref.read(secureStorageProvider);
    await storage.clearAll();
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Profile')),
      body: ListView(
        children: [
          // ── Profile card ───────────────────────────────────────────
          if (_user != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: OlColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: OlColors.primary,
                    radius: 28,
                    child: Text(
                      _user!.firstName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _user!.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: OlColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _user!.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: OlColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _Tag(label: _user!.role.replaceAll('_', ' ')),
                            if (_user!.branchName != null) ...[
                              const SizedBox(width: 6),
                              _Tag(label: _user!.branchName!),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ── Settings items ──────────────────────────────────────────
          _SectionHeader(title: 'Account'),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.sync_outlined,
            label: 'Sync & Data',
            onTap: () {},
          ),

          _SectionHeader(title: 'Support'),
          _SettingsTile(
            icon: Icons.help_outline,
            label: 'Help & FAQs',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.bug_report_outlined,
            label: 'Report an Issue',
            onTap: () {},
          ),

          _SectionHeader(title: 'App'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            trailing: Text(
              _version.isEmpty ? '…' : _version,
              style: theme.textTheme.bodySmall?.copyWith(color: OlColors.textSecondary),
            ),
            onTap: () {
              setState(() {
                _versionTapCount++;
                if (_versionTapCount >= 5) {
                  _versionTapCount = 0;
                  _demoModeHintVisible = false;
                  _showDemoModeSheet();
                } else if (_versionTapCount >= 2) {
                  _demoModeHintVisible = true;
                }
              });
              if (_demoModeHintVisible && _versionTapCount < 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${5 - _versionTapCount} more taps to enter demo mode'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 8),

          // ── Logout ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: Icon(Icons.logout, color: OlColors.error),
              label: Text('Sign out', style: TextStyle(color: OlColors.error)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: OlColors.error.withOpacity(0.5)),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: OlColors.textSecondary,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: OlColors.textSecondary),
        title:   Text(label),
        trailing: const Icon(Icons.chevron_right, size: 16),
        onTap: onTap,
      );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: OlColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: OlColors.primary,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Demo Mode Bottom Sheet
// ---------------------------------------------------------------------------

class _DemoModeSheet extends StatelessWidget {
  const _DemoModeSheet({required this.onCredentialSelected});

  final void Function(Map<String, String> cred) onCredentialSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: OlColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: OlColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'DEMO MODE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: OlColors.warning,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Kannan Rice Distributors',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Select a role to log in with demo credentials (password: demo1234)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: OlColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            // Role list
            ..._demoCredentials.map(
              (cred) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: OlColors.primaryLight,
                  child: Text(
                    cred['role']![0],
                    style: TextStyle(
                      color: OlColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                title: Text(
                  cred['role']!,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  cred['email']!,
                  style: TextStyle(color: OlColors.textSecondary, fontSize: 12),
                ),
                trailing: const Icon(Icons.login, size: 16),
                onTap: () => onCredentialSelected(
                  Map<String, String>.from(cred),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
