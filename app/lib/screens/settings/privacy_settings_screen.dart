import 'package:flutter/material.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Security')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: const [
                  _InfoTile(
                    icon: Icons.storage_outlined,
                    title: 'On-device encryption',
                    body:
                        'All your data is encrypted on your device using SQLCipher AES-256.',
                  ),
                  Divider(indent: 52, height: 0),
                  _InfoTile(
                    icon: Icons.cloud_outlined,
                    title: 'Secure sync',
                    body:
                        'Sync uses your account credentials only. No third-party data sharing.',
                  ),
                  Divider(indent: 52, height: 0),
                  _InfoTile(
                    icon: Icons.visibility_off_outlined,
                    title: 'No analytics or tracking',
                    body:
                        'Antra does not collect analytics, crash reports, or behavioral data.',
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: cs.error),
                title: Text(
                  'Delete Account',
                  style: TextStyle(color: cs.error),
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Account'),
                    content: const Text(
                      'Account deletion is not yet available in-app. Please contact support to request account deletion.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.onSurfaceVariant),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(body, style: const TextStyle(fontSize: 12)),
      isThreeLine: true,
    );
  }
}
