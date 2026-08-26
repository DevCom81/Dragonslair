import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/mock_game_master_repository.dart';
import '../data/remote_game_master_repository.dart';
import '../domain/game_master_repository.dart';

final gameMasterRepositoryProvider = Provider<GameMasterRepository>((ref) {
  if (AppConfig.isGameMasterRemote) {
    return const RemoteGameMasterRepository();
  }

  return const MockGameMasterRepository();
});
