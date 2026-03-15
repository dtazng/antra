import 'package:flutter/material.dart';

import 'package:antra/models/needs_attention_item.dart';
import 'package:antra/theme/app_theme.dart';
import 'package:antra/widgets/glass_surface.dart';

/// Horizontal-scroll strip of pending follow-up suggestion cards.
///
/// Absent (returns [SizedBox.shrink]) when [items] is empty.
class NeedsAttentionSection extends StatelessWidget {
  const NeedsAttentionSection({
    super.key,
    required this.items,
    required this.onDone,
    required this.onSnooze,
    required this.onDismiss,
  });

  final List<NeedsAttentionItem> items;
  final void Function(String bulletId) onDone;
  final void Function(String bulletId) onSnooze;
  final void Function(String bulletId) onDismiss;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Text(
              'Needs Attention',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white38,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return _SuggestionCard(
                  item: item,
                  onDone: () => onDone(item.bulletId),
                  onSnooze: () => onSnooze(item.bulletId),
                  onDismiss: () => onDismiss(item.bulletId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.item,
    required this.onDone,
    required this.onSnooze,
    required this.onDismiss,
  });

  final NeedsAttentionItem item;
  final VoidCallback onDone;
  final VoidCallback onSnooze;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: GlassSurface(
        borderOpacityOverride: AntraColors.chipGlassBorderOpacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Person name (if any)
              if (item.personName != null)
                Text(
                  item.personName!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (item.personName != null) const SizedBox(height: 2),

              // Entry content (context)
              Expanded(
                child: Text(
                  item.content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Follow-up date label
              Text(
                'Due ${item.followUpDate}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white38,
                ),
              ),

              const SizedBox(height: 8),

              // Action buttons
              Row(
                children: [
                  Expanded(child: _ActionButton(
                    icon: Icons.check_rounded,
                    onTap: onDone,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionButton(
                    icon: Icons.access_time_rounded,
                    onTap: onSnooze,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionButton(
                    icon: Icons.close_rounded,
                    onTap: onDismiss,
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: Colors.white60),
      ),
    );
  }
}
