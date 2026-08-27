import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _gameMasterMode = String.fromEnvironment(
    'GAME_MASTER_MODE',
  );
  static const _gameMasterBackendUrl = String.fromEnvironment(
    'GAME_MASTER_BACKEND_URL',
  );

  static String get supabaseUrl => _readConfig('SUPABASE_URL', _supabaseUrl);

  static String get supabaseAnonKey =>
      _readConfig('SUPABASE_ANON_KEY', _supabaseAnonKey);

  static String get gameMasterMode =>
      _readConfig('GAME_MASTER_MODE', _gameMasterMode, defaultValue: 'mock');

  static String get gameMasterBackendUrl =>
      _readConfig('GAME_MASTER_BACKEND_URL', _gameMasterBackendUrl);

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isGameMasterRemote =>
      gameMasterMode.toLowerCase() == 'remote';

  static bool get isGameMasterBackendConfigured =>
      gameMasterBackendUrl.isNotEmpty;

  static String get supabaseHost => _hostFromUrl(supabaseUrl);

  static String get gameMasterBackendHost => _hostFromUrl(gameMasterBackendUrl);

  static Uri get gameMasterRespondUri {
    final baseUrl = gameMasterBackendUrl.endsWith('/')
        ? gameMasterBackendUrl.substring(0, gameMasterBackendUrl.length - 1)
        : gameMasterBackendUrl;
    return Uri.parse('$baseUrl/v1/game-master/respond');
  }

  static Uri get gameMasterResolveRollUri {
    final baseUrl = gameMasterBackendUrl.endsWith('/')
        ? gameMasterBackendUrl.substring(0, gameMasterBackendUrl.length - 1)
        : gameMasterBackendUrl;
    return Uri.parse('$baseUrl/v1/game-master/resolve-roll');
  }

  static Uri get scenarioGenerateUri {
    return _backendUri('/v1/scenarios/generate');
  }

  static Uri get purchaseOfferUri {
    return _backendUri('/v1/purchases/offer');
  }

  static Uri get purchaseCheckoutUri {
    return _backendUri('/v1/purchases/checkout');
  }

  static Uri _backendUri(String path) {
    final baseUrl = gameMasterBackendUrl.endsWith('/')
        ? gameMasterBackendUrl.substring(0, gameMasterBackendUrl.length - 1)
        : gameMasterBackendUrl;
    return Uri.parse('$baseUrl$path');
  }

  static String _readConfig(
    String key,
    String dartDefineValue, {
    String defaultValue = '',
  }) {
    final fromDartDefine = _normalizeValue(key, dartDefineValue);
    if (fromDartDefine.isNotEmpty) {
      return fromDartDefine;
    }

    try {
      final fromDotenv = _normalizeValue(key, dotenv.env[key] ?? '');
      return fromDotenv.isEmpty ? defaultValue : fromDotenv;
    } catch (_) {
      return defaultValue;
    }
  }

  static String _normalizeValue(String key, String value) {
    final trimmed = value.trim();
    final keyPrefix = '$key=';
    final prefixIndex = trimmed.indexOf(keyPrefix);

    if (prefixIndex == -1) {
      return trimmed;
    }

    return trimmed.substring(prefixIndex + keyPrefix.length).trim();
  }

  static String _hostFromUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      return 'non configure';
    }

    return uri.host;
  }
}
