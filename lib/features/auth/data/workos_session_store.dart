import 'package:shared_preferences/shared_preferences.dart';

abstract interface class WorkOsSessionStore {
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  });

  Future<String?> readAccessToken();

  Future<String?> readRefreshToken();

  Future<void> clear();
}

class SharedPreferencesWorkOsSessionStore implements WorkOsSessionStore {
  const SharedPreferencesWorkOsSessionStore();

  static const accessKey = 'auth.workos.access';
  static const refreshKey = 'auth.workos.refresh';

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(accessKey, accessToken);
    await prefs.setString(refreshKey, refreshToken);
  }

  @override
  Future<String?> readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(accessKey);
  }

  @override
  Future<String?> readRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(refreshKey);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(accessKey);
    await prefs.remove(refreshKey);
  }
}
