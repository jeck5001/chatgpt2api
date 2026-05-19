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
    expect(
      find.byKey(const ValueKey('desktop-inspector-pane')),
      findsOneWidget,
    );
  });

  testWidgets(
    'compact tabs cross-fade — both pages briefly coexist during transition',
    (tester) async {
      await tester.pumpWidget(_StatefulHost(width: 390));

      expect(find.text('create-body'), findsOneWidget);
      expect(find.text('library-body'), findsNothing);

      await tester.tap(find.byIcon(Icons.photo_library_outlined));
      await tester.pump();
      // Mid-fade — both nodes should be in the tree as the AnimatedSwitcher
      // layers the outgoing and incoming page.
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('create-body'), findsOneWidget);
      expect(find.text('library-body'), findsOneWidget);

      // Past the transition — only the new page remains.
      await tester.pump(const Duration(milliseconds: 240));

      expect(find.text('create-body'), findsNothing);
      expect(find.text('library-body'), findsOneWidget);
    },
  );
}

Widget _host({required double width}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 900)),
      child: const AdaptiveShell(
        selectedIndex: 1,
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

class _StatefulHost extends StatefulWidget {
  const _StatefulHost({required this.width});
  final double width;

  @override
  State<_StatefulHost> createState() => _StatefulHostState();
}

class _StatefulHostState extends State<_StatefulHost> {
  int _index = 1;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(widget.width, 900)),
        child: AdaptiveShell(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          create: const Text('create-body'),
          library: const Text('library-body'),
          projects: const Text('projects-body'),
          settings: const Text('settings-body'),
        ),
      ),
    );
  }
}
