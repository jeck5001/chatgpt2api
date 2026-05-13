import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ServerProfileStore {
  const ServerProfileStore(this._preferences);

  static const _activeProfileKey = 'chatgpt2api.activeServerProfile';

  final SharedPreferences _preferences;

  Uri? readActiveBaseUrl() {
    final raw = _preferences.getString(_activeProfileKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return Uri.tryParse(raw);
  }

  Future<void> writeActiveBaseUrl(Uri baseUrl) {
    return _preferences.setString(
      _activeProfileKey,
      _normalizeBaseUrl(baseUrl).toString(),
    );
  }

  Future<void> clearActiveBaseUrl() {
    return _preferences.remove(_activeProfileKey);
  }

  static Uri _normalizeBaseUrl(Uri value) {
    final normalized = value.replace(
      path: value.path.replaceAll(RegExp(r'/+$'), ''),
    );
    return Uri.parse(jsonDecode(jsonEncode(normalized.toString())) as String);
  }
}
