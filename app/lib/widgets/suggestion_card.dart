import 'package:flutter/material.dart';

import 'package:antra/models/suggestion.dart';

/// An expandable suggestion card in the Day View feed.
///
/// Collapsed: shows person name, type chip, signal text.
/// Expanded: adds notes (if any) + contextual action buttons.
/// Animation: [AnimatedSize] with 250ms ease-in-out.
class SuggestionCard extends StatelessWidget {
  const SuggestionCard({
    super.key,
    required this.suggestion,
    required this.expanded,
    required this.onTap,
    required this.onAction,
    required this.onDismiss,
  });

  final Suggestion suggestion;
  final bool expanded;
  final VoidCallback onTap;
  final void Function(SuggestionAction) onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Collapsed header (always visible) ---
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion.personName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _TypeChip(suggestion.type),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  suggestion.signalText,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.black38),
                      onPressed: onDismiss,
                    ),
                  ],
                ),
              ),
            ),

            // --- Expanded content ---
            if (expanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (suggestion.personNotes != null) ...[
                      const Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        suggestion.personNotes!,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _ActionRow(
                      type: suggestion.type,
                      onAction: onAction,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Type chip
// ---------------------------------------------------------------------------

class _TypeChip extends StatelessWidget {
  const _TypeChip(this.type);
  final SuggestionType type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      SuggestionType.reconnect => ('Reconnect', Colors.blue.shade100),
      SuggestionType.birthday => ('Birthday 🎉', Colors.orange.shade100),
      SuggestionType.followUp => ('Follow-up', Colors.green.shade100),
      SuggestionType.memory => ('Memory', Colors.purple.shade100),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

// ---------------------------------------------------------------------------
// Action row — buttons differ per card type
// ---------------------------------------------------------------------------

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.type, required this.onAction});
  final SuggestionType type;
  final void Function(SuggestionAction) onAction;

  @override
  Widget build(BuildContext context) {
    final actions = switch (type) {
      SuggestionType.reconnect => [
          (SuggestionAction.message, 'Message'),
          (SuggestionAction.call, 'Call'),
          (SuggestionAction.logMeeting, 'Log meeting'),
        ],
      SuggestionType.birthday => [
          (SuggestionAction.sendGreeting, 'Send greeting'),
          (SuggestionAction.logCall, 'Log call'),
        ],
      SuggestionType.followUp => [
          (SuggestionAction.followUp, 'Follow up'),
          (SuggestionAction.scheduleLater, 'Schedule later'),
          (SuggestionAction.markDone, 'Mark done'),
        ],
      SuggestionType.memory => [
          (SuggestionAction.logNote, 'Log note'),
          (SuggestionAction.message, 'Message'),
        ],
    };

    return Wrap(
      spacing: 8,
      children: [
        for (final (action, label) in actions)
          FilledButton.tonal(
            onPressed: () => onAction(action),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: Size.zero,
            ),
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
      ],
    );
  }
}
