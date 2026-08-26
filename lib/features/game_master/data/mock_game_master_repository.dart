import '../domain/game_master_repository.dart';
import '../domain/game_master_response.dart';

class MockGameMasterRepository implements GameMasterRepository {
  const MockGameMasterRepository();

  @override
  Future<GameMasterResponse> respond(GameMasterInput input) async {
    final action = input.action.toLowerCase();

    if (action.contains('attaque')) {
      return const GameMasterResponse(
        narration:
            'Ton attaque fend l air. Une presence hostile recule dans l ombre, mais le combat commence.',
        actions: [
          GameMasterAction(
            type: GameMasterActionType.startCombat,
            payload: {'enemy_type': 'ombre'},
          ),
        ],
        choices: [
          GameMasterChoice(label: 'Maintenir la pression'),
          GameMasterChoice(label: 'Se mettre en defense'),
        ],
      );
    }

    if (action.contains('examine')) {
      return const GameMasterResponse(
        narration:
            'Tu observes les environs. Des marques anciennes griffent la pierre pres d une porte scellee.',
        actions: [
          GameMasterAction(
            type: GameMasterActionType.systemMessage,
            payload: {'message': 'Indice decouvert.'},
          ),
        ],
        choices: [
          GameMasterChoice(label: 'Lire les marques'),
          GameMasterChoice(label: 'Ouvrir la porte'),
        ],
      );
    }

    return const GameMasterResponse(
      narration:
          'Le maitre du jeu pese ton intention. Le silence de la salle laisse entendre un danger proche.',
      actions: [],
      choices: [
        GameMasterChoice(label: 'Avancer prudemment'),
        GameMasterChoice(label: 'Ecouter les bruits'),
        GameMasterChoice(label: 'Revenir en arriere'),
      ],
    );
  }
}
