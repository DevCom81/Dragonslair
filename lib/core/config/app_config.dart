class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const gameMasterMode = String.fromEnvironment(
    'GAME_MASTER_MODE',
    defaultValue: 'mock',
  );
  static const gameMasterBackendUrl = String.fromEnvironment(
    'GAME_MASTER_BACKEND_URL',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isGameMasterRemote =>
      gameMasterMode.toLowerCase() == 'remote';

  static bool get isGameMasterBackendConfigured =>
      gameMasterBackendUrl.isNotEmpty;

  static Uri get gameMasterRespondUri {
    final baseUrl = gameMasterBackendUrl.endsWith('/')
        ? gameMasterBackendUrl.substring(0, gameMasterBackendUrl.length - 1)
        : gameMasterBackendUrl;
    return Uri.parse('$baseUrl/v1/game-master/respond');
  }
}
