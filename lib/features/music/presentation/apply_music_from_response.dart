import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game_master/domain/game_master_response.dart';
import '../domain/music_mood.dart';
import 'music_controller.dart';

void applyMusicFromResponse({
  required WidgetRef ref,
  required GameMasterResponse response,
}) {
  final music = ref.read(musicControllerProvider.notifier);
  var startCombat = false;
  var endCombat = false;
  MusicMood? narrativeMood;

  for (final action in response.actions) {
    switch (action.type) {
      case GameMasterActionType.startCombat:
        startCombat = true;
      case GameMasterActionType.endCombat:
        endCombat = true;
      case GameMasterActionType.setMusicMood:
        narrativeMood = MusicMood.tryParse(action.payload['mood']);
      default:
        break;
    }
  }

  if (startCombat) {
    music.enterCombat();
    return;
  }
  if (endCombat) {
    music.leaveCombat();
    return;
  }
  if (narrativeMood != null) {
    music.setMood(narrativeMood);
  }
}
