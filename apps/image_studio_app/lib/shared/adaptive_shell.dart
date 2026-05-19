import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../app/responsive.dart';

class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.create,
    required this.library,
    required this.projects,
    required this.settings,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget create;
  final Widget library;
  final Widget projects;
  final Widget settings;

  Widget _crossFadePage(Widget page) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        return FadeTransition(opacity: anim, child: child);
      },
      child: KeyedSubtree(key: ValueKey<int>(selectedIndex), child: page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [projects, create, library, settings];
    return switch (windowClassOf(context)) {
      WindowClass.compact => Scaffold(
        body: _crossFadePage(pages[selectedIndex]),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: KilnColors.hairline)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [KilnColors.ink900, KilnColors.ink950],
            ),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder_copy_outlined),
                label: 'Projects',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: 'Studio',
              ),
              NavigationDestination(
                icon: Icon(Icons.photo_library_outlined),
                selectedIcon: Icon(Icons.photo_library),
                label: 'Library',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
      WindowClass.medium => Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.folder_outlined),
                label: Text('Projects'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                label: Text('Studio'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.photo_library_outlined),
                label: Text('Library'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.tune_outlined),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _crossFadePage(pages[selectedIndex])),
        ],
      ),
      WindowClass.expanded => Row(
        children: [
          SizedBox(
            key: const ValueKey('desktop-project-pane'),
            width: 280,
            child: projects,
          ),
          const VerticalDivider(width: 1),
          Expanded(key: const ValueKey('desktop-center-pane'), child: create),
          const VerticalDivider(width: 1),
          SizedBox(
            key: const ValueKey('desktop-inspector-pane'),
            width: 340,
            child: library,
          ),
        ],
      ),
    };
  }
}
