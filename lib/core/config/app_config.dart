import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../backend/backend_mode.dart';

class AppConfig {
  const AppConfig._();

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _backendMode = String.fromEnvironment('BACKEND_MODE');
  static const _convexUrl = String.fromEnvironment('CONVEX_URL');
  static const _auth0Domain = String.fromEnvironment('AUTH0_DOMAIN');
  static const _auth0ClientId = String.fromEnvironment('AUTH0_CLIENT_ID');
  static const _auth0Audience = String.fromEnvironment('AUTH0_AUDIENCE');
  static const _gameMasterMode = String.fromEnvironment(
    'GAME_MASTER_MODE',
  );
  static const _gameMasterBackendUrl = String.fromEnvironment(
    'GAME_MASTER_BACKEND_URL',
  );

  static String get supabaseUrl => _readConfig('SUPABASE_URL', _supabaseUrl);

  static String get supabaseAnonKey =>
      _readConfig('SUPABASE_ANON_KEY', _supabaseAnonKey);

  static String get convexUrl => _readConfig('CONVEX_URL', _convexUrl);

  static String get auth0Domain => _readConfig('AUTH0_DOMAIN', _auth0Domain);

  static String get auth0ClientId =>
      _readConfig('AUTH0_CLIENT_ID', _auth0ClientId);

  static String get auth0Audience =>
      _readConfig('AUTH0_AUDIENCE', _auth0Audience);

  static bool get isConvexConfigured => convexUrl.isNotEmpty;

  static bool get isAuth0Configured =>
      auth0Domain.isNotEmpty &&
      auth0ClientId.isNotEmpty &&
      auth0Audience.isNotEmpty;

  static String get gameMasterMode =>
      _readConfig('GAME_MASTER_MODE', _gameMasterMode, defaultValue: 'mock');

  static String get gameMasterBackendUrl =>
      _readConfig('GAME_MASTER_BACKEND_URL', _gameMasterBackendUrl);

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static BackendMode get backendMode =>
      parseBackendMode(_readConfig('BACKEND_MODE', _backendMode));

  /// Identity/auth is ready for the selected backend.
  /// Legacy: Supabase keys present. Convex: CONVEX_URL present.
  static bool get isIdentityConfigured {
    switch (backendMode) {
      case BackendMode.legacy:
        return isSupabaseConfigured;
      case BackendMode.convex:
        return isConvexConfigured && isAuth0Configured;
    }
  }

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

  static Uri get purchaseMeUri {
    return _backendUri('/v1/purchases/me');
  }

  static Uri get googlePlayPurchaseUri {
    return _backendUri('/v1/purchases/google');
  }

  static Uri get windowsDownloadUri {
    return _backendUri('/v1/downloads/windows');
  }

  /// Play Console product id. Not a secret. Empty disables Android billing.
  static String get googlePlayProductId =>
      _readConfig('GOOGLE_PLAY_PRODUCT_ID', _googlePlayProductId);

  static const _googlePlayProductId = String.fromEnvironment(
    'GOOGLE_PLAY_PRODUCT_ID',
  );

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
