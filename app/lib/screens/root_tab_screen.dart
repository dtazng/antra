import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/providers/task_lifecycle_provider.dart';
import 'package:antra/screens/day_view/day_view_screen.dart';
import 'package:antra/screens/people/people_screen.dart';
import 'package:antra/screens/collections/collections_screen.dart';
import 'package:antra/screens/search/search_screen.dart';
import 'package:antra/screens/review/review_screen.dart';

class RootTabScreen extends ConsumerStatefulWidget {
  const RootTabScreen({super.key});

  @override
  ConsumerState<RootTabScreen> createState() => _RootTabScreenState();
}

class _RootTabScreenState extends ConsumerState<RootTabScreen> {
  int _selectedIndex = 0;

  static const _screens = <Widget>[
    DayViewScreen(),
    PeopleScreen(),
    CollectionsScreen(),
    SearchScreen(),
    ReviewScreen(),
  ];

  static const _tabs = [
    _TabItem(icon: Icons.wb_sunny_outlined, label: 'Today'),
    _TabItem(icon: Icons.people_outline_rounded, label: 'People'),
    _TabItem(icon: Icons.folder_outlined, label: 'Collections'),
    _TabItem(icon: Icons.search_rounded, label: 'Search'),
    _TabItem(icon: Icons.auto_stories_outlined, label: 'Review'),
  ];

  // Height of the floating bar: 60px container + 8px top + 12px bottom padding.
  static const _tabBarHeight = 80.0;

  @override
  Widget build(BuildContext context) {
    final weeklyCount =
        ref.watch(weeklyReviewTasksProvider).valueOrNull?.length ?? 0;

    final mq = MediaQuery.of(context);
    // Tell all child Scaffolds that there's extra bottom inset so their FABs
    // and SafeArea widgets automatically clear the floating tab bar.
    final childMq = mq.copyWith(
      padding: mq.padding.copyWith(
        bottom: mq.padding.bottom + _tabBarHeight,
      ),
      viewPadding: mq.viewPadding.copyWith(
        bottom: mq.viewPadding.bottom + _tabBarHeight,
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          MediaQuery(
            data: childMq,
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FloatingTabBar(
              selectedIndex: _selectedIndex,
              tabs: _tabs,
              reviewBadgeCount: weeklyCount,
              onTap: (i) => setState(() => _selectedIndex = i),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data ───────────────────────────────────────────────────────────────────

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem({required this.icon, required this.label});
}

// ─── Floating pill bar ───────────────────────────────────────────────────────

// Review tab is always index 4 in the tabs list.
const _kReviewTabIndex = 4;

class _FloatingTabBar extends StatelessWidget {
  final int selectedIndex;
  final List<_TabItem> tabs;
  final int reviewBadgeCount;
  final ValueChanged<int> onTap;

  const _FloatingTabBar({
    required this.selectedIndex,
    required this.tabs,
    required this.reviewBadgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: brightness == Brightness.dark
                ? cs.surfaceContainerHigh
                : cs.surface,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            children: List.generate(tabs.length, (i) {
              return Expanded(
                child: _TabButton(
                  item: tabs[i],
                  selected: i == selectedIndex,
                  badgeCount: i == _kReviewTabIndex ? reviewBadgeCount : 0,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final _TabItem item;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  const _TabButton({
    required this.item,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? cs.primaryContainer.withValues(alpha: 0.8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Badge(
            isLabelVisible: badgeCount > 0,
            label: Text('$badgeCount'),
            child: Icon(
              item.icon,
              size: 22,
              color: selected
                  ? cs.primary
                  : cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}
