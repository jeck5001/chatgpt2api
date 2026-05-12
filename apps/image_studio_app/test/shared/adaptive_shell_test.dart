import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/shared/adaptive_shell.dart';

void main() {
  testWidgets('compact width uses bottom navigation', (tester) async {
    await tester.pumpWidget(_host(width: 390));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('expanded width uses three panes', (tester) async {
    await tester.pumpWidget(_host(width: 1280));

    expect(find.byKey(const ValueKey('desktop-project-pane')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-center-pane')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-inspector-pane')), findsOneWidget);
  });
}

Widget _host({required double width}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 900)),
      child: const AdaptiveShell(
        selectedIndex: 0,
        onDestinationSelected: _ignore,
        create: Text('Create'),
        library: Text('Library'),
        projects: Text('Projects'),
        settings: Text('Settings'),
      ),
    ),
  );
}

void _ignore(int _) {}
