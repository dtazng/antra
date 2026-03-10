import 'package:flutter/material.dart';

/// A generic empty-state widget with an icon, title, and optional subtitle.
///
/// Used across all screens to provide contextual guidance when there is no
/// content to display.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  // ---------------------------------------------------------------------------
  // Pre-built variants for common screens
  // ---------------------------------------------------------------------------

  /// Shown on the daily log when the user has no bullets yet.
  factory EmptyState.dailyLog() => const EmptyState(
        icon: Icons.edit_note,
        title: 'Start your day',
        subtitle: 'Capture your first bullet below — task, note, or event.',
      );

  /// Shown on the people tab when no people have been created.
  factory EmptyState.people() => const EmptyState(
        icon: Icons.people_outline,
        title: 'Add the people in your life',
        subtitle: 'Tap + to create a person and link bullets to them.',
      );

  /// Shown on the search screen when no results match the active query.
  factory EmptyState.searchNoResults() => const EmptyState(
        icon: Icons.search_off,
        title: 'No results found',
        subtitle: 'Try different keywords, or remove some filters.',
      );

  /// Shown on a collection detail screen when no bullets match its rules.
  factory EmptyState.emptyCollection() => const EmptyState(
        icon: Icons.filter_list_off,
        title: 'No matching bullets yet',
        subtitle:
            'Bullets that match this collection\'s filter rules will appear here automatically.',
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface.withOpacity(0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(0.4),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
