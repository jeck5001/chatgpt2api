import 'package:shared_preferences/shared_preferences.dart';

const String _kPrefModel = 'studio.default_model';
const String _kPrefSize = 'studio.default_size';
const String _kPrefCount = 'studio.default_count';
const String _kPrefAutoFavorite = 'studio.auto_favorite';

class StudioPreferences {
  const StudioPreferences({
    this.defaultModel = 'gpt-image-2',
    this.defaultSize = '1024x1024',
    this.defaultCount = 1,
    this.autoFavorite = false,
  });

  final String defaultModel;
  final String defaultSize;
  final int defaultCount;
  final bool autoFavorite;

  StudioPreferences copyWith({
    String? defaultModel,
    String? defaultSize,
    int? defaultCount,
    bool? autoFavorite,
  }) {
    return StudioPreferences(
      defaultModel: defaultModel ?? this.defaultModel,
      defaultSize: defaultSize ?? this.defaultSize,
      defaultCount: defaultCount ?? this.defaultCount,
      autoFavorite: autoFavorite ?? this.autoFavorite,
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
    return StudioPreferences(
      defaultModel:
          _prefs.getString(_kPrefModel) ??
          const StudioPreferences().defaultModel,
      defaultSize:
          _prefs.getString(_kPrefSize) ?? const StudioPreferences().defaultSize,
      defaultCount:
          _prefs.getInt(_kPrefCount) ?? const StudioPreferences().defaultCount,
      autoFavorite: _prefs.getBool(_kPrefAutoFavorite) ?? false,
    );
  }

  @override
  Future<void> write(StudioPreferences preferences) async {
    await Future.wait([
      _prefs.setString(_kPrefModel, preferences.defaultModel),
      _prefs.setString(_kPrefSize, preferences.defaultSize),
      _prefs.setInt(_kPrefCount, preferences.defaultCount),
      _prefs.setBool(_kPrefAutoFavorite, preferences.autoFavorite),
    ]);
  }
}
