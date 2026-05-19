import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/library/library_screen.dart';
import 'package:image_studio_app/studio/studio_models.dart';

StudioFavorite _fav(
  String id,
  String prompt, {
  DateTime? createdAt,
  String? imagePath,
}) {
  return StudioFavorite(
    id: id,
    imagePath: imagePath ?? 'images/$id.png',
    sourceTurnId: 't-$id',
    createdAt: createdAt ?? DateTime(2026, 5, 1),
    prompt: prompt,
  );
}

StudioAsset _asset(
  String path,
  String prompt, {
  DateTime? createdAt,
  List<String> tags = const [],
  String model = 'gpt-image-2',
  String projectName = 'Campaign',
}) {
  return StudioAsset(
    path: path,
    name: path.split('/').last,
    date: '2026-05-19',
    sizeBytes: 4096,
    createdAt: createdAt ?? DateTime(2026, 5, 19),
    url: Uri.parse('http://localhost:8000/images/$path'),
    thumbnailUrl: Uri.parse('http://localhost:8000/image-thumbnails/$path'),
    tags: tags,
    prompt: prompt,
    model: model,
    projectName: projectName,
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

Future<void> _pumpAssetLibrary(
  WidgetTester tester, {
  required List<StudioAsset> assets,
  List<StudioFavorite> favorites = const [],
  ValueChanged<StudioAsset>? onContinueEditAsset,
  ValueChanged<StudioAsset>? onGenerateVariant,
  ValueChanged<StudioAsset>? onDownloadAsset,
  ValueChanged<StudioAsset>? onShareAsset,
  ValueChanged<StudioAsset>? onSaveRecipeAsset,
  ValueChanged<List<StudioAsset>>? onBatchDownload,
  ValueChanged<List<StudioAsset>>? onBatchTag,
  ValueChanged<List<StudioAsset>>? onBatchDelete,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LibraryScreen(
        assets: assets,
        favorites: favorites,
        onContinueEditAsset: onContinueEditAsset,
        onGenerateVariant: onGenerateVariant,
        onDownloadAsset: onDownloadAsset,
        onShareAsset: onShareAsset,
        onSaveRecipeAsset: onSaveRecipeAsset,
        onBatchDownload: onBatchDownload,
        onBatchTag: onBatchTag,
        onBatchDelete: onBatchDelete,
      ),
    ),
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

  testWidgets('asset library exposes all, favorites, recent and tagged views', (
    tester,
  ) async {
    final assets = [
      _asset('2026/05/19/orange.png', 'orange product photo', tags: ['海报']),
      _asset('2026/05/18/blue.png', 'blue sky landscape'),
    ];
    final favorites = [
      _fav(
        'favorite-1',
        'orange product photo',
        imagePath: '2026/05/19/orange.png',
      ),
    ];

    await _pumpAssetLibrary(tester, assets: assets, favorites: favorites);

    expect(find.text('全部'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('最近'), findsOneWidget);
    expect(find.text('已标记'), findsOneWidget);
    expect(find.textContaining('2 张作品'), findsOneWidget);

    await tester.tap(find.text('收藏'));
    await tester.pump();
    expect(find.textContaining('命中 1 / 2'), findsOneWidget);

    await tester.tap(find.text('已标记'));
    await tester.pump();
    expect(find.textContaining('命中 1 / 2'), findsOneWidget);
  });

  testWidgets('asset search matches prompt, project, model and tags', (
    tester,
  ) async {
    final assets = [
      _asset(
        '2026/05/19/orange.png',
        'orange product photo',
        tags: ['海报'],
        model: 'gpt-image-2',
        projectName: 'Spring Campaign',
      ),
      _asset(
        '2026/05/18/blue.png',
        'blue sky landscape',
        tags: ['风景'],
        model: 'gpt-image-1',
        projectName: 'Winter Campaign',
      ),
    ];

    await _pumpAssetLibrary(tester, assets: assets);

    await tester.enterText(find.byType(TextField), 'Winter');
    await tester.pump();
    expect(find.textContaining('命中 1 / 2'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'gpt-image-1');
    await tester.pump();
    expect(find.textContaining('命中 1 / 2'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '海报');
    await tester.pump();
    expect(find.textContaining('命中 1 / 2'), findsOneWidget);
  });

  testWidgets(
    'asset tile action buttons call continue, variant, download and share callbacks',
    (tester) async {
      final asset = _asset('2026/05/19/orange.png', 'orange product photo');
      final actions = <String>[];

      await _pumpAssetLibrary(
        tester,
        assets: [asset],
        onContinueEditAsset: (asset) => actions.add('continue:${asset.path}'),
        onGenerateVariant: (asset) => actions.add('variant:${asset.path}'),
        onDownloadAsset: (asset) => actions.add('download:${asset.path}'),
        onShareAsset: (asset) => actions.add('share:${asset.path}'),
      );

      await tester.tap(find.byTooltip('继续编辑'));
      await tester.tap(find.byTooltip('生成变体'));
      await tester.tap(find.byTooltip('下载'));
      await tester.tap(find.byTooltip('分享'));

      expect(actions, [
        'continue:2026/05/19/orange.png',
        'variant:2026/05/19/orange.png',
        'download:2026/05/19/orange.png',
        'share:2026/05/19/orange.png',
      ]);
    },
  );

  testWidgets('asset tile save recipe button calls the recipe callback', (
    tester,
  ) async {
    final asset = _asset('2026/05/19/orange.png', 'orange product photo');
    final actions = <String>[];

    await _pumpAssetLibrary(
      tester,
      assets: [asset],
      onSaveRecipeAsset: (asset) => actions.add('recipe:${asset.path}'),
    );

    await tester.tap(find.byTooltip('保存配方'));
    await tester.pump();

    expect(actions, ['recipe:2026/05/19/orange.png']);
  });

  testWidgets('batch mode selects assets and invokes bulk actions', (
    tester,
  ) async {
    final assets = [
      _asset('2026/05/19/orange.png', 'orange product photo'),
      _asset('2026/05/18/blue.png', 'blue sky landscape'),
    ];
    final bulkActions = <String>[];

    await _pumpAssetLibrary(
      tester,
      assets: assets,
      onBatchDownload: (assets) => bulkActions.add('download:${assets.length}'),
      onBatchTag: (assets) => bulkActions.add('tag:${assets.length}'),
      onBatchDelete: (assets) => bulkActions.add('delete:${assets.length}'),
    );

    await tester.tap(find.text('选择'));
    await tester.pump();
    await tester.tap(find.byTooltip('选择 orange.png'));
    await tester.tap(find.byTooltip('选择 blue.png'));
    await tester.pump();

    expect(find.text('已选择 2 张'), findsOneWidget);

    await tester.tap(find.text('下载 zip'));
    await tester.tap(find.text('批量打标签'));
    await tester.tap(find.text('批量删除'));

    expect(bulkActions, ['download:2', 'tag:2', 'delete:2']);
  });
}
