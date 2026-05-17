import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/studio/studio_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('round-trips accent through SharedPreferences', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesStudioPreferencesStore(prefs);

    await store.write(
      const StudioPreferences(
        defaultModel: 'gpt-image-2',
        defaultSize: '1024x1024',
        defaultCount: 2,
        autoFavorite: true,
        accent: 'sage',
        libraryNewestFirst: false,
      ),
    );
    final read = await store.read();

    expect(read.accent, 'sage');
    expect(read.defaultCount, 2);
    expect(read.autoFavorite, true);
    expect(read.libraryNewestFirst, false);
  });

  test('falls back to default accent when stored value is unsupported',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio.accent': 'fuchsia',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesStudioPreferencesStore(prefs);

    final read = await store.read();

    expect(read.accent, 'ember');
  });

  test('returns default accent when nothing is stored', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesStudioPreferencesStore(prefs);

    final read = await store.read();

    expect(read.accent, 'ember');
  });
}
