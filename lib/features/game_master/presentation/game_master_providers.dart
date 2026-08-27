import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../data/mock_game_master_repository.dart';
import '../data/remote_game_master_repository.dart';
import '../domain/game_master_repository.dart';

final gameMasterRepositoryProvider = Provider<GameMasterRepository>((ref) {
  if (AppConfig.isGameMasterRemote) {
    final accessToken =
        ref.watch(supabaseClientProvider)?.auth.currentSession?.accessToken;
    return RemoteGameMasterRepository(accessToken: accessToken);
  }

  return const MockGameMasterRepository();
});
