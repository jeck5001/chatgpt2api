import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/library/library_screen.dart';
import 'package:image_studio_app/studio/studio_models.dart';

StudioFavorite _fav(String id, String prompt, {DateTime? createdAt}) {
  return StudioFavorite(
    id: id,
    imagePath: 'images/$id.png',
    sourceTurnId: 't-$id',
    createdAt: createdAt ?? DateTime(2026, 5, 1),
    prompt: prompt,
  );
}

Future<void> _pumpLibrary(
  WidgetTester tester,
  List<StudioFavorite> favorites,
) async {
  await tester.pumpWidget(
    MaterialApp(home: LibraryScreen(favorites: favorites)),
  );
  await tester.pump();
}

void main() {
  testWidgets('search filters favorites by prompt substring', (tester) async {
    final favorites = [
      _fav('1', 'orange product photo', createdAt: DateTime(2026, 5, 1)),
      _fav('2', 'blue sky landscape', createdAt: DateTime(2026, 5, 2)),
    ];

    await _pumpLibrary(tester, favorites);

    expect(find.textContaining('2 张作品'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'orange');
    await tester.pump();

    expect(find.textContaining('命中 1 / 2'), findsOneWidget);
    expect(find.textContaining('搜索 “orange”'), findsOneWidget);
  });

  testWidgets('search shows no-results empty state when nothing matches', (
    tester,
  ) async {
    final favorites = [_fav('1', 'orange product photo')];

    await _pumpLibrary(tester, favorites);

    await tester.enterText(find.byType(TextField), 'mountain');
    await tester.pump();

    expect(find.text('换个关键词试试，或清空搜索看看所有作品。'), findsOneWidget);
  });

  testWidgets('clear button resets the search and restores all items', (
    tester,
  ) async {
    final favorites = [
      _fav('1', 'orange product photo'),
      _fav('2', 'blue sky landscape'),
    ];

    await _pumpLibrary(tester, favorites);

    await tester.enterText(find.byType(TextField), 'orange');
    await tester.pump();
    expect(find.textContaining('命中 1 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('清除'));
    await tester.pump();

    expect(find.textContaining('2 张作品'), findsOneWidget);
    expect(find.byTooltip('清除'), findsNothing);
  });

  testWidgets('search is case-insensitive', (tester) async {
    final favorites = [_fav('1', 'Orange Product Photo')];

    await _pumpLibrary(tester, favorites);

    await tester.enterText(find.byType(TextField), 'orange');
    await tester.pump();

    expect(find.textContaining('命中 1 / 1'), findsOneWidget);
  });

  testWidgets('tile renders prompt caption when prompt is non-empty', (
    tester,
  ) async {
    final favorites = [_fav('1', 'orange product photo')];

    await _pumpLibrary(tester, favorites);

    expect(find.text('orange product photo'), findsOneWidget);
  });

  testWidgets('tile wraps the image in a Hero with a path-based tag', (
    tester,
  ) async {
    final favorites = [_fav('1', 'p')];

    await _pumpLibrary(tester, favorites);

    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'studio-image:images/1.png');
  });
}
