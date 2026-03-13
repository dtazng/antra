import 'package:flutter/material.dart';

import 'package:antra/models/suggestion.dart';
import 'package:antra/theme/app_theme.dart';
import 'package:antra/widgets/glass_surface.dart';
import 'package:antra/widgets/person_avatar.dart';
import 'package:antra/widgets/person_identity_accent.dart';

/// An expandable suggestion card in the Day View feed.
///
/// Collapsed: shows PersonAvatar, person name, type chip, signal text, and a
///   PersonIdentityAccent ring.
/// Expanded: adds PersonIdentityAccent edgeGlow + notes + contextual actions.
/// Animation: spring expand/collapse via AnimatedSize using AntraMotion tokens.
/// Dismiss: fade out via AnimatedOpacity.
class SuggestionCard extends StatefulWidget {
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
  State<SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<SuggestionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _dismissController;
  late Animation<double> _dismissAnim;

  @override
  void initState() {
    super.initState();
    _dismissController = AnimationController(
      vsync: this,
      duration: AntraMotion.fadeDismiss,
      value: 1.0,
    );
    _dismissAnim = CurvedAnimation(
      parent: _dismissController,
      curve: AntraMotion.dismissCurve,
    );
  }

  @override
  void dispose() {
    _dismissController.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    await _dismissController.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _dismissAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: GlassSurface(
          style: GlassStyle.card,
          padding: EdgeInsets.zero,
          onTap: widget.onTap,
          child: AnimatedSize(
            duration: widget.expanded
                ? AntraMotion.springExpand
                : AntraMotion.springCollapse,
            curve: widget.expanded
                ? AntraMotion.expandCurve
                : AntraMotion.collapseCurve,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Collapsed header (always visible) ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      PersonAvatar(
                        personId: widget.suggestion.personId,
                        displayName: widget.suggestion.personName,
                        radius: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.suggestion.personName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _TypeChip(widget.suggestion.type),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.suggestion.signalText,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white54,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Identity ring accent in collapsed state.
                      if (!widget.expanded)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: PersonIdentityAccent(
                            personId: widget.suggestion.personId,
                            style: AccentStyle.ring,
                            size: 14,
                          ),
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white38,
                        ),
                        onPressed: _handleDismiss,
                      ),
                    ],
                  ),
                ),

                // --- Expanded content ---
                if (widget.expanded) ...[
                  // Edge glow accent on the left of the expanded card.
                  SizedBox(
                    height: 2,
                    child: PersonIdentityAccent(
                      personId: widget.suggestion.personId,
                      style: AccentStyle.topBar,
                      size: 20,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.suggestion.personNotes != null) ...[
                          const Text(
                            'NOTES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white38,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.suggestion.personNotes!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        _ActionRow(
                          type: widget.suggestion.type,
                          onAction: widget.onAction,
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
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
      SuggestionType.reconnect => ('Reconnect', Colors.blue.withValues(alpha: 0.25)),
      SuggestionType.birthday => ('Birthday 🎉', Colors.orange.withValues(alpha: 0.25)),
      SuggestionType.followUp => ('Follow-up', Colors.green.withValues(alpha: 0.25)),
      SuggestionType.memory => ('Memory', Colors.purple.withValues(alpha: 0.25)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.white70),
      ),
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
      runSpacing: 6,
      children: [
        for (final (action, label) in actions)
          GestureDetector(
            onTap: () => onAction(action),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 0.5,
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
