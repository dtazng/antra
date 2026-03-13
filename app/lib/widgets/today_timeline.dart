import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:antra/models/today_interaction.dart';
import 'package:antra/widgets/glass_surface.dart';
import 'package:antra/widgets/person_identity_accent.dart';
import 'package:antra/theme/app_theme.dart';

/// Reverse-chronological list of today's logged entries (notes, tasks,
/// and person-linked interactions).
///
/// Each entry is styled as a glass chip. Task entries show a tappable
/// completion control (hollow circle when open, filled checkmark when done).
/// Person-linked non-task entries show a [PersonIdentityAccent] dot; plain
/// notes show a small circle dot.
///
/// Completed tasks render their content at reduced opacity.
/// Cards expand vertically to show full content — no ellipsis truncation.
///
/// New entries animate in using [AnimatedList] with a slide-from-below
/// transition using [AntraMotion.slideInsert].
///
/// Swiping an entry left reveals a delete affordance. The [onDelete] callback
/// is fired with the [TodayInteraction.bulletId] when the swipe is confirmed.
///
/// Callers provide [interactions] pre-sorted newest-first.
class TodayInteractionTimeline extends StatefulWidget {
  const TodayInteractionTimeline({
    super.key,
    required this.interactions,
    required this.onTap,
    required this.onDelete,
    required this.onComplete,
  });

  final List<TodayInteraction> interactions;
  final void Function(String bulletId) onTap;
  final void Function(String bulletId) onDelete;

  /// Called when the user taps the completion control on a task entry.
  /// [complete] is true when the user wants to mark done, false to undo.
  final void Function(String bulletId, bool complete) onComplete;

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
    } else if (widget.interactions.length != _items.length ||
        !_listsEqual(widget.interactions, _items)) {
      // List shrunk, reordered, or items updated in place (e.g., completion).
      setState(() {
        _items = List.of(widget.interactions);
      });
    }
  }

  static bool _listsEqual(
      List<TodayInteraction> a, List<TodayInteraction> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].bulletId != b[i].bulletId || a[i].status != b[i].status) {
        return false;
      }
    }
    return true;
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
              'Nothing logged yet today.',
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
    TodayInteraction entry,
    Animation<double> animation,
  ) {
    final isTask = entry.type == 'task';
    final isComplete = entry.status == 'complete';

    return Dismissible(
      key: ValueKey(entry.bulletId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red.shade800,
          borderRadius: BorderRadius.circular(AntraRadius.chip),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
      onDismissed: (_) => widget.onDelete(entry.bulletId),
      child: SlideTransition(
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
              onTap: () => widget.onTap(entry.bulletId),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Leading indicator: completion control for tasks, person dot
                  // or circle for notes.
                  if (isTask)
                    GestureDetector(
                      onTap: () => widget.onComplete(
                        entry.bulletId,
                        !isComplete,
                      ),
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        isComplete
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        size: 14,
                        color: Colors.white54,
                      ),
                    )
                  else if (entry.personId != null)
                    PersonIdentityAccent(
                      personId: entry.personId!,
                      style: AccentStyle.dot,
                      size: 8,
                    )
                  else
                    const Icon(
                      Icons.circle,
                      size: 6,
                      color: Colors.white38,
                    ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 40,
                    child: Text(
                      _timeFmt.format(entry.loggedAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      entry.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: isComplete ? Colors.white38 : Colors.white,
                      ),
                    ),
                  ),
                  if (entry.personName != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      entry.personName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
