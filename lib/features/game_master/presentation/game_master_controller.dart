import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/game_master_repository.dart';
import '../domain/game_master_response.dart';
import 'game_master_providers.dart';

final gameMasterControllerProvider =
    AsyncNotifierProvider<GameMasterController, GameMasterResponse?>(
  GameMasterController.new,
);

class GameMasterController extends AsyncNotifier<GameMasterResponse?> {
  @override
  GameMasterResponse? build() {
    return null;
  }

  Future<void> submitAction(String action) async {
    final trimmedAction = action.trim();
    if (trimmedAction.isEmpty) {
      throw const GameException('Action vide.');
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(gameMasterRepositoryProvider).respond(
            GameMasterInput(action: trimmedAction),
          );
    });
  }
}
