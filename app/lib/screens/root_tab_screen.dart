import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/theme/app_theme.dart';
import 'package:antra/screens/timeline/timeline_screen.dart';
import 'package:antra/screens/people/people_screen.dart';

class RootTabScreen extends ConsumerStatefulWidget {
  const RootTabScreen({super.key});

  @override
  ConsumerState<RootTabScreen> createState() => _RootTabScreenState();
}

class _RootTabScreenState extends ConsumerState<RootTabScreen> {
  int _selectedIndex = 0;

  static const _screens = <Widget>[
    TimelineScreen(),
    PeopleScreen(),
  ];

  static const _tabs = [
    _TabItem(icon: Icons.timeline_outlined, label: 'Timeline'),
    _TabItem(icon: Icons.people_outline_rounded, label: 'People'),
  ];

  // Height of the floating bar: 60px container + 8px top + 12px bottom padding.
  static const _tabBarHeight = 80.0;

  @override
  Widget build(BuildContext context) {
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

class _FloatingTabBar extends StatelessWidget {
  final int selectedIndex;
  final List<_TabItem> tabs;
  final ValueChanged<int> onTap;

  const _FloatingTabBar({
    required this.selectedIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: AntraColors.auroraNavy,
            borderRadius: BorderRadius.circular(AntraRadius.tabBar),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Color.fromRGBO(
                  255, 255, 255, AntraColors.glassBorderOpacity),
              width: 0.5,
            ),
          ),
          child: Row(
            children: List.generate(tabs.length, (i) {
              return Expanded(
                child: _TabButton(
                  item: tabs[i],
                  selected: i == selectedIndex,
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
  final VoidCallback onTap;

  const _TabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Icon(
            item.icon,
            size: 22,
            color: selected ? Colors.white : Colors.white38,
          ),
        ),
      ),
    );
  }
}
