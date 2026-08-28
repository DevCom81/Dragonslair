import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game_master/domain/game_master_response.dart';
import '../domain/music_mood.dart';
import 'music_controller.dart';

void applyMusicFromResponse({
  required WidgetRef ref,
  required GameMasterResponse response,
}) {
  final music = ref.read(musicControllerProvider.notifier);
  final current = ref.read(musicControllerProvider);
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
        narrativeMood = MusicMood.tryParseNarrative(action.payload['mood']);
      default:
        break;
    }
  }

  final fallbackNarrative = current.currentMood == MusicMood.combat
      ? (current.previousMood ?? MusicMood.exploration)
      : (current.currentMood ?? MusicMood.exploration);
  final narrative = narrativeMood ?? fallbackNarrative;

  if (startCombat) {
    music.syncScene(narrativeMood: narrative, combatActive: true);
    return;
  }
  if (endCombat) {
    music.syncScene(narrativeMood: narrative, combatActive: false);
    return;
  }
  if (narrativeMood != null) {
    music.setMood(narrativeMood);
  }
}
