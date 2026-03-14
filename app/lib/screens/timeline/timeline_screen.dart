import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:antra/models/timeline_entry.dart';
import 'package:antra/providers/needs_attention_provider.dart';
import 'package:antra/providers/timeline_provider.dart';
import 'package:antra/screens/daily_log/bullet_detail_screen.dart';
import 'package:antra/theme/app_theme.dart';
import 'package:antra/widgets/aurora_background.dart';
import 'package:antra/widgets/bullet_capture_bar.dart';
import 'package:antra/widgets/glass_surface.dart';
import 'package:antra/widgets/needs_attention_section.dart';

// Height of each date section header row (in px).
const double _kHeaderH = 36.0;
// Rough per-entry card height (outer padding 4+4 + inner 12+12 + ~46px text).
const double _kEntryH = 78.0;
// Approximate height of the NeedsAttentionSection when it has items.
const double _kAttentionH = 200.0;

/// Primary home screen — an infinite-scroll life-log timeline.
///
/// Layout (bottom-up):
///   - [BulletCaptureBar] — fixed at bottom, always visible
///   - Single overlay sticky date header — replaces per-section pinned headers
///   - [CustomScrollView] with non-pinned date separators + entry slivers
///   - [NeedsAttentionSection] at the top of the scroll view
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final _scrollController = ScrollController();

  /// Label shown in the single overlay sticky header.
  /// Empty → overlay hidden (the in-list header is still on screen).
  String _stickyLabel = '';

  /// Cached day list used by the scroll listener to compute the current section.
  List<TimelineDay> _days = [];
  bool _hasAttentionItems = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateStickyLabel);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateStickyLabel);
    _scrollController.dispose();
    super.dispose();
  }

  /// Updates [_stickyLabel] based on the current scroll offset.
  ///
  /// The overlay header is hidden (label = '') while the corresponding in-list
  /// section separator is still visible in the viewport. It appears once that
  /// separator has scrolled behind the sticky zone, so the two never overlap.
  void _updateStickyLabel() {
    if (_days.isEmpty) return;
    final offset = _scrollController.offset;

    double sectionStart = _hasAttentionItems ? _kAttentionH : 0;
    for (int i = 0; i < _days.length; i++) {
      final headerEnd = sectionStart + _kHeaderH;
      final sectionEnd = sectionStart + _kHeaderH + _days[i].entries.length * _kEntryH;

      if (offset < headerEnd) {
        // In-list header is still visible → hide overlay.
        if (_stickyLabel.isNotEmpty) setState(() => _stickyLabel = '');
        return;
      }
      if (offset < sectionEnd) {
        // Inside this section's content → show its label.
        final label = _days[i].label;
        if (_stickyLabel != label) setState(() => _stickyLabel = label);
        return;
      }
      sectionStart = sectionEnd;
    }
    // Scrolled past all sections — keep last label.
    final label = _days.last.label;
    if (_stickyLabel != label) setState(() => _stickyLabel = label);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final timelineAsync = ref.watch(timelineEntriesProvider);
    final attentionAsync = ref.watch(needsAttentionItemsProvider);

    final body = timelineAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white38),
      ),
      error: (e, _) => const Center(
        child: Text(
          'Something went wrong.',
          style: TextStyle(color: Colors.white54),
        ),
      ),
      data: (days) {
        final attentionItems = attentionAsync.valueOrNull ?? [];
        final isEmpty = days.isEmpty && attentionItems.isEmpty;

        // Keep cached values in sync; defer sticky-label recalc to after build.
        _days = days;
        _hasAttentionItems = attentionItems.isNotEmpty;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateStickyLabel();
        });

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Needs Attention strip — hidden when empty
            SliverToBoxAdapter(
              child: NeedsAttentionSection(
                items: attentionItems,
                onDone: (bulletId) => ref
                    .read(needsAttentionItemsProvider.notifier)
                    .markDone(bulletId),
                onSnooze: (bulletId) => ref
                    .read(needsAttentionItemsProvider.notifier)
                    .snooze(bulletId),
                onDismiss: (bulletId) => ref
                    .read(needsAttentionItemsProvider.notifier)
                    .dismiss(bulletId),
              ),
            ),

            // Empty state
            if (isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              ),

            // Timeline: non-pinned date separator + entry list per day.
            // The overlay sticky header (in the Stack below) handles the
            // "one active header at a time" behaviour; these separators just
            // scroll with the content and disappear smoothly behind the overlay.
            for (final day in days) ...[
              SliverToBoxAdapter(
                child: _DaySeparator(label: day.label),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = day.entries[index];
                    final bulletId = switch (entry) {
                      LogEntryItem e => e.bulletId,
                      CompletionEventItem e => e.bulletId,
                    };
                    return _EntryCard(
                      entry: entry,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              BulletDetailScreen(bulletId: bulletId),
                        ),
                      ),
                    );
                  },
                  childCount: day.entries.length,
                ),
              ),
            ],

            // Bottom padding — clears the BulletCaptureBar
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        );
      },
    );

    return AuroraBackground(
      variant: AuroraVariant.dayView,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              body,

              // Single sticky date header — visible only after the in-list
              // separator for the current section has scrolled off screen.
              if (_stickyLabel.isNotEmpty)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _OverlayStickyHeader(label: _stickyLabel),
                ),

              // Fixed bottom capture bar
              Positioned(
                left: 12,
                right: 12,
                bottom: 0,
                child: BulletCaptureBar(date: today),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overlay sticky header (single, outside the scroll view)
// ---------------------------------------------------------------------------

class _OverlayStickyHeader extends StatelessWidget {
  const _OverlayStickyHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kHeaderH,
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
}

// ---------------------------------------------------------------------------
// Non-pinned in-list day separator
// ---------------------------------------------------------------------------

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kHeaderH,
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
}

// ---------------------------------------------------------------------------
// Entry card
// ---------------------------------------------------------------------------

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onTap});

  final TimelineEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCompletion = entry is CompletionEventItem;
    final content = switch (entry) {
      LogEntryItem e => e.content,
      CompletionEventItem e => e.content,
    };
    final personName = switch (entry) {
      LogEntryItem e => e.personName,
      CompletionEventItem e => e.personName,
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
                // Timeline dot / completion checkmark
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              isCompletion ? Colors.white54 : Colors.white,
                          height: 1.4,
                        ),
                      ),
                      if (personName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          personName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ],
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

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Nothing logged yet.\nStart by writing your first entry.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white38,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
