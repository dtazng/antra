import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/providers/theme_provider.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(themeNotifierProvider);
    final current = themeAsync.valueOrNull ?? ThemeMode.system;

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Card(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Text(
                      'Theme',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  _ThemeOption(
                    label: 'System default',
                    icon: Icons.brightness_auto_outlined,
                    mode: ThemeMode.system,
                    selected: current == ThemeMode.system,
                    onTap: () => ref
                        .read(themeNotifierProvider.notifier)
                        .setTheme(ThemeMode.system),
                  ),
                  const Divider(indent: 52, height: 0),
                  _ThemeOption(
                    label: 'Light',
                    icon: Icons.light_mode_outlined,
                    mode: ThemeMode.light,
                    selected: current == ThemeMode.light,
                    onTap: () => ref
                        .read(themeNotifierProvider.notifier)
                        .setTheme(ThemeMode.light),
                  ),
                  const Divider(indent: 52, height: 0),
                  _ThemeOption(
                    label: 'Dark',
                    icon: Icons.dark_mode_outlined,
                    mode: ThemeMode.dark,
                    selected: current == ThemeMode.dark,
                    onTap: () => ref
                        .read(themeNotifierProvider.notifier)
                        .setTheme(ThemeMode.dark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? cs.primary : cs.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? cs.primary : null,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_rounded, color: cs.primary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
