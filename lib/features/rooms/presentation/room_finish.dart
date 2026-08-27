import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../game_master/domain/game_master_response.dart';
import 'room_providers.dart';

Future<void> applyLocalFinishFromResponse({
  required WidgetRef ref,
  required String roomId,
  required GameMasterResponse response,
}) async {
  if (AppConfig.isGameMasterRemote) {
    return;
  }
  for (final action in response.actions) {
    if (action.type != GameMasterActionType.finishGame) {
      continue;
    }
    await ref.read(roomRepositoryProvider).finishRoom(
          roomId: roomId,
          result: action.payload['result']?.toString() ?? 'neutral',
          summary: action.payload['summary']?.toString() ?? '',
          epilogue: action.payload['epilogue']?.toString() ?? '',
        );
  }
}
