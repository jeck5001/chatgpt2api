import 'package:shared_preferences/shared_preferences.dart';

const String _kPrefModel = 'studio.default_model';
const String _kPrefSize = 'studio.default_size';
const String _kPrefCount = 'studio.default_count';
const String _kPrefAutoFavorite = 'studio.auto_favorite';
const String _kPrefAccent = 'studio.accent';
const String _kPrefLibraryNewestFirst = 'studio.library_newest_first';

const Set<String> kSupportedAccents = {'ember', 'sage', 'indigo', 'slate'};

class StudioPreferences {
  const StudioPreferences({
    this.defaultModel = 'gpt-image-2',
    this.defaultSize = '1024x1024',
    this.defaultCount = 1,
    this.autoFavorite = false,
    this.accent = 'ember',
    this.libraryNewestFirst = true,
  });

  final String defaultModel;
  final String defaultSize;
  final int defaultCount;
  final bool autoFavorite;
  final String accent;
  final bool libraryNewestFirst;

  StudioPreferences copyWith({
    String? defaultModel,
    String? defaultSize,
    int? defaultCount,
    bool? autoFavorite,
    String? accent,
    bool? libraryNewestFirst,
  }) {
    return StudioPreferences(
      defaultModel: defaultModel ?? this.defaultModel,
      defaultSize: defaultSize ?? this.defaultSize,
      defaultCount: defaultCount ?? this.defaultCount,
      autoFavorite: autoFavorite ?? this.autoFavorite,
      accent: accent ?? this.accent,
      libraryNewestFirst: libraryNewestFirst ?? this.libraryNewestFirst,
    );
  }
}

abstract interface class StudioPreferencesStore {
  Future<StudioPreferences> read();
  Future<void> write(StudioPreferences preferences);
}

class SharedPreferencesStudioPreferencesStore
    implements StudioPreferencesStore {
  SharedPreferencesStudioPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<StudioPreferences> read() async {
    final accent = _prefs.getString(_kPrefAccent);
    return StudioPreferences(
      defaultModel:
          _prefs.getString(_kPrefModel) ??
          const StudioPreferences().defaultModel,
      defaultSize:
          _prefs.getString(_kPrefSize) ?? const StudioPreferences().defaultSize,
      defaultCount:
          _prefs.getInt(_kPrefCount) ?? const StudioPreferences().defaultCount,
      autoFavorite: _prefs.getBool(_kPrefAutoFavorite) ?? false,
      accent: kSupportedAccents.contains(accent)
          ? accent!
          : const StudioPreferences().accent,
      libraryNewestFirst:
          _prefs.getBool(_kPrefLibraryNewestFirst) ??
          const StudioPreferences().libraryNewestFirst,
    );
  }

  @override
  Future<void> write(StudioPreferences preferences) async {
    await Future.wait([
      _prefs.setString(_kPrefModel, preferences.defaultModel),
      _prefs.setString(_kPrefSize, preferences.defaultSize),
      _prefs.setInt(_kPrefCount, preferences.defaultCount),
      _prefs.setBool(_kPrefAutoFavorite, preferences.autoFavorite),
      _prefs.setString(_kPrefAccent, preferences.accent),
      _prefs.setBool(_kPrefLibraryNewestFirst, preferences.libraryNewestFirst),
    ]);
  }
}
