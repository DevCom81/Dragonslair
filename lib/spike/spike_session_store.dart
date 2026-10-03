import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Spike-only persistence. Not a production session store.
class SpikeSessionStore {
  const SpikeSessionStore._();

  static const _accessKey = 'spike.workos.access';
  static const _refreshKey = 'spike.workos.refresh';

  static Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, accessToken);
    await prefs.setString(_refreshKey, refreshToken);
  }

  static Future<String?> readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  static Future<String?> readRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  static Future<bool> hasRefreshToken() async {
    final token = await readRefreshToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  static bool accessTokenStillValid(String accessToken) {
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) {
        return false;
      }
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) {
        return false;
      }
      final exp = payload['exp'];
      if (exp is! num) {
        return false;
      }
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return exp.toInt() - 30 > nowSeconds;
    } catch (_) {
      return false;
    }
  }
}
