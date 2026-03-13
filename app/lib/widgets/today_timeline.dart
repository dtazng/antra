import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:antra/models/today_interaction.dart';
import 'package:antra/widgets/glass_surface.dart';
import 'package:antra/widgets/person_identity_accent.dart';
import 'package:antra/theme/app_theme.dart';

/// Reverse-chronological list of today's person-linked interactions.
///
/// Each entry is styled as a glass chip with a PersonIdentityAccent dot.
/// New entries animate in using [AnimatedList] with a slide-from-below
/// transition using [AntraMotion.slideInsert].
///
/// Callers provide [interactions] pre-sorted newest-first.
class TodayInteractionTimeline extends StatefulWidget {
  const TodayInteractionTimeline({
    super.key,
    required this.interactions,
    required this.onTap,
  });

  final List<TodayInteraction> interactions;
  final void Function(String bulletId) onTap;

  @override
  State<TodayInteractionTimeline> createState() =>
      _TodayInteractionTimelineState();
}

class _TodayInteractionTimelineState extends State<TodayInteractionTimeline> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey();
  late List<TodayInteraction> _items;

  static final _timeFmt = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.interactions);
  }

  @override
  void didUpdateWidget(TodayInteractionTimeline old) {
    super.didUpdateWidget(old);
    // Detect newly added items (newest-first: new items appear at the front).
    if (widget.interactions.length > _items.length) {
      final newCount = widget.interactions.length - _items.length;
      for (var i = 0; i < newCount; i++) {
        _items.insert(i, widget.interactions[i]);
        _listKey.currentState?.insertItem(
          i,
          duration: AntraMotion.slideInsert,
        );
      }
    } else if (widget.interactions.length != _items.length) {
      // List shrunk or reordered — refresh without animation.
      setState(() {
        _items = List.of(widget.interactions);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, size: 16, color: Colors.white30),
            const SizedBox(width: 8),
            const Text(
              'No interactions logged yet today.',
              style: TextStyle(fontSize: 14, color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'TODAY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white38,
              letterSpacing: 1.2,
            ),
          ),
        ),
        AnimatedList(
          key: _listKey,
          initialItemCount: _items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index, animation) {
            if (index >= _items.length) return const SizedBox.shrink();
            return _buildEntry(context, _items[index], animation);
          },
        ),
      ],
    );
  }

  Widget _buildEntry(
    BuildContext context,
    TodayInteraction interaction,
    Animation<double> animation,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: AntraMotion.insertCurve,
      )),
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: GlassSurface(
            style: GlassStyle.chip,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onTap: () => widget.onTap(interaction.bulletId),
            child: Row(
              children: [
                PersonIdentityAccent(
                  personId: interaction.personId,
                  style: AccentStyle.dot,
                  size: 8,
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 40,
                  child: Text(
                    _timeFmt.format(interaction.loggedAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${interaction.interactionLabel} with ${interaction.personName}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
