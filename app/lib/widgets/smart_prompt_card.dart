import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/models/smart_prompt.dart';
import 'package:antra/providers/smart_prompt_providers.dart';
import 'package:antra/theme/app_theme.dart';
import 'package:antra/widgets/glass_surface.dart';

/// A card displayed in the Needs Attention section for a [SmartPrompt].
///
/// Supports promptTypes:
/// - `important_date` — birthday/anniversary reminder with Log / Snooze / Done
/// - `inactivity`     — (US5) haven't talked in N months
/// - `follow_up`      — (US5) post-interaction follow-up suggestion
class SmartPromptCard extends ConsumerWidget {
  const SmartPromptCard({
    super.key,
    required this.prompt,
    this.onLogInteraction,
  });

  final SmartPrompt prompt;

  /// Optional callback so caller can open the log bar pre-linked to this person.
  final void Function(String personId)? onLogInteraction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 260,
      child: GlassSurface(
        borderOpacityOverride: AntraColors.chipGlassBorderOpacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Person name
              Text(
                prompt.personName,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // Title headline
              Expanded(
                child: Text(
                  prompt.title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Body copy
              Text(
                prompt.body,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white38,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Action buttons
              Row(
                children: [
                  // Log interaction
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.add_circle_outline,
                      tooltip: 'Log interaction',
                      onTap: () => onLogInteraction?.call(prompt.personId),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Snooze
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.access_time_rounded,
                      tooltip: 'Snooze',
                      onTap: () => _showSnoozeSheet(context, ref),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Done / Dismiss
                  Expanded(
                    child: _ActionButton(
                      icon: prompt.promptType == 'important_date'
                          ? Icons.check_rounded
                          : Icons.close_rounded,
                      tooltip: prompt.promptType == 'important_date'
                          ? 'Done'
                          : 'Dismiss',
                      onTap: () => ref
                          .read(smartPromptActionsProvider.notifier)
                          .markDone(prompt),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnoozeSheet(BuildContext context, WidgetRef ref) {
    unawaited(showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Snooze until…',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: Colors.white70),
                ),
              ),
              _SnoozeOption(
                label: 'Tomorrow',
                date: DateTime.now().add(const Duration(days: 1)),
                prompt: prompt,
              ),
              _SnoozeOption(
                label: '3 days',
                date: DateTime.now().add(const Duration(days: 3)),
                prompt: prompt,
              ),
              _SnoozeOption(
                label: 'Next week',
                date: DateTime.now().add(const Duration(days: 7)),
                prompt: prompt,
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip ?? '',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: Colors.white60),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SnoozeOption extends ConsumerWidget {
  const _SnoozeOption({
    required this.label,
    required this.date,
    required this.prompt,
  });

  final String label;
  final DateTime date;
  final SmartPrompt prompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
      onTap: () {
        Navigator.of(context).pop();
        unawaited(ref
            .read(smartPromptActionsProvider.notifier)
            .snooze(prompt, date));
      },
    );
  }
}
