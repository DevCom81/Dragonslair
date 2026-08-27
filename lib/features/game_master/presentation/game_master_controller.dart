import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../access/domain/demo_ending.dart';
import '../../access/domain/entitlement_repository.dart';
import '../../access/domain/game_access.dart';
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
    await submit(GameMasterInput(action: action));
  }

  Future<GameMasterResponse> submit(GameMasterInput input) async {
    final trimmedAction = input.action.trim();
    if (trimmedAction.isEmpty) {
      throw const GameException('Action vide.');
    }

    state = const AsyncLoading();
    final response = await AsyncValue.guard(() async {
      final ended = await _mockDemoEnding(input.roomId, input.locale);
      if (ended != null) {
        return ended;
      }
      return ref.read(gameMasterRepositoryProvider).respond(input);
    });
    state = response;
    return response.requireValue;
  }

  Future<GameMasterResponse> resolveRoll(ResolveRollInput input) async {
    state = const AsyncLoading();
    final response = await AsyncValue.guard(() {
      return ref.read(gameMasterRepositoryProvider).resolveRoll(input);
    });
    state = response;
    return response.requireValue;
  }

  Future<GameMasterResponse?> _mockDemoEnding(
    String? roomId,
    String locale,
  ) async {
    if (AppConfig.isGameMasterRemote || roomId == null || roomId.isEmpty) {
      return null;
    }
    final result = await ref
        .read(entitlementRepositoryProvider)
        .ensureDemoPlay(roomId);
    if (result == DemoPlayResult.forbidden) {
      throw const GameException('DEMO_FORBIDDEN');
    }
    if (result == DemoPlayResult.expired || result == DemoPlayResult.closed) {
      return cannedDemoEnding(locale);
    }
    return null;
  }
}
