import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/models/auth_state.dart';
import 'package:antra/providers/auth_provider.dart';
import 'package:antra/screens/settings/account_settings_screen.dart';
import 'package:antra/screens/settings/appearance_settings_screen.dart';
import 'package:antra/screens/settings/notifications_settings_screen.dart';
import 'package:antra/screens/settings/privacy_settings_screen.dart';
import 'package:antra/screens/settings/sync_settings_screen.dart';
import 'package:antra/screens/settings/about_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);
    final authState = authAsync.valueOrNull;
    final email = authState is Authenticated ? authState.email : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SettingsSection(
            children: [
              _SettingsRow(
                icon: Icons.person_outline_rounded,
                title: 'Account',
                subtitle: email,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountSettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
          _SettingsSection(
            children: [
              _SettingsRow(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsSettingsScreen(),
                  ),
                ),
              ),
              _SettingsRow(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AppearanceSettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
          _SettingsSection(
            children: [
              _SettingsRow(
                icon: Icons.sync_outlined,
                title: 'Sync & Data',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SyncSettingsScreen(),
                  ),
                ),
              ),
              _SettingsRow(
                icon: Icons.lock_outline_rounded,
                title: 'Privacy & Security',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacySettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
          _SettingsSection(
            children: [
              _SettingsRow(
                icon: Icons.info_outline_rounded,
                title: 'About',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AboutScreen(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Section wrapper ─────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final List<Widget> children;
  const _SettingsSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: List.generate(children.length * 2 - 1, (i) {
            if (i.isOdd) {
              return const Divider(indent: 52, endIndent: 0, height: 0);
            }
            return children[i ~/ 2];
          }),
        ),
      ),
    );
  }
}

// ─── Row tile ────────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.onSurfaceVariant),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: cs.onSurfaceVariant,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
