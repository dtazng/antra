import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/database/app_database.dart';
import 'package:antra/models/timeline_entry.dart';
import 'package:antra/providers/person_relationship_provider.dart';
import 'package:antra/screens/daily_log/bullet_detail_screen.dart';
import 'package:antra/theme/app_theme.dart';
import 'package:antra/widgets/glass_surface.dart';

/// Full relationship timeline for a person.
///
/// Displays log entries and completion events linked to [person], grouped by
/// day with sticky date headers — matching the main TimelineScreen pattern.
class PersonFullTimelineScreen extends ConsumerWidget {
  final PeopleData person;
  const PersonFullTimelineScreen({super.key, required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync =
        ref.watch(personRelationshipTimelineProvider(person.id));

    return Scaffold(
      backgroundColor: AntraColors.auroraDeepNavy,
      appBar: AppBar(
        backgroundColor: AntraColors.auroraNavy,
        foregroundColor: Colors.white,
        title: Text(
          "${person.name}'s Timeline",
          style: const TextStyle(color: Colors.white, fontSize: 17),
        ),
      ),
      body: timelineAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white38),
        ),
        error: (e, _) => const Center(
          child: Text('Something went wrong.',
              style: TextStyle(color: Colors.white54)),
        ),
        data: (days) {
          if (days.isEmpty) {
            return Center(
              child: Text(
                'No interactions yet with ${person.name}.',
                style:
                    const TextStyle(fontSize: 15, color: Colors.white38),
                textAlign: TextAlign.center,
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              for (final day in days) ...[
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyDateHeaderDelegate(day.label),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = day.entries[index];
                      return _RelationshipEntryCard(
                        entry: entry,
                        onTap: () {
                          final bulletId = switch (entry) {
                            LogEntryItem e => e.bulletId,
                            CompletionEventItem e => e.bulletId,
                          };
                          // ignore: discarded_futures
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  BulletDetailScreen(bulletId: bulletId),
                            ),
                          );
                        },
                      );
                    },
                    childCount: day.entries.length,
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky date header delegate
// ---------------------------------------------------------------------------

class _StickyDateHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StickyDateHeaderDelegate(this.label);

  final String label;

  @override
  double get minExtent => 36.0;

  @override
  double get maxExtent => 36.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AntraColors.auroraNavy,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white38,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyDateHeaderDelegate oldDelegate) =>
      oldDelegate.label != label;
}

// ---------------------------------------------------------------------------
// Entry card
// ---------------------------------------------------------------------------

class _RelationshipEntryCard extends StatelessWidget {
  const _RelationshipEntryCard({
    required this.entry,
    required this.onTap,
  });

  final TimelineEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCompletion = entry is CompletionEventItem;
    final content = switch (entry) {
      LogEntryItem e => e.content,
      CompletionEventItem e => e.content,
    };
    final createdAt = switch (entry) {
      LogEntryItem e => e.createdAt,
      CompletionEventItem e => e.createdAt,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: GlassSurface(
          borderOpacityOverride: AntraColors.chipGlassBorderOpacity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 12),
                  child: isCompletion
                      ? const Icon(Icons.check_circle_outline,
                          size: 14, color: Colors.white38)
                      : Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white38,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
                Expanded(
                  child: Text(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      color: isCompletion ? Colors.white54 : Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('h:mm a').format(createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white24,
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
