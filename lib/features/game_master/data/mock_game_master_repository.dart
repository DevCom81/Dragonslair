import '../../rooms/domain/room_locale.dart';
import '../domain/game_master_repository.dart';
import '../domain/game_master_response.dart';

class MockGameMasterRepository implements GameMasterRepository {
  const MockGameMasterRepository();

  @override
  Future<GameMasterResponse> respond(GameMasterInput input) async {
    final action = input.action.toLowerCase();
    final locale = normalizeRoomLocale(input.locale);

    if (_isAttack(action)) {
      return _attackResponse(locale);
    }

    if (_isExamine(action)) {
      return _examineResponse(locale);
    }

    return _defaultResponse(locale);
  }

  @override
  Future<GameMasterResponse> resolveRoll(ResolveRollInput input) {
    return respond(
      GameMasterInput(
        action:
            'roll_result raw=${input.raw} pending_roll_id=${input.pendingRollId}',
        playerName: input.playerName,
        players: input.players,
        enemies: input.enemies,
        recentEvents: input.recentEvents,
        combat: input.combat,
      ),
    );
  }

  bool _isAttack(String action) {
    return action.contains('attaque') ||
        action.contains('attack') ||
        action.contains('angriff') ||
        action.contains('ataca');
  }

  bool _isExamine(String action) {
    return action.contains('examine') ||
        action.contains('untersuch') ||
        action.contains('examina');
  }

  GameMasterResponse _attackResponse(String locale) {
    return switch (locale) {
      'en' => const GameMasterResponse(
        narration:
            'Your strike cuts the air. A hostile presence falls back into the shadows, and combat begins.',
        actions: [
          GameMasterAction(
            type: GameMasterActionType.startCombat,
            payload: {'enemy_type': 'ombre'},
          ),
        ],
        choices: [
          GameMasterChoice(label: 'Keep the pressure on'),
          GameMasterChoice(label: 'Take a defensive stance'),
        ],
      ),
      'de' => const GameMasterResponse(
        narration:
            'Dein Schlag zerteilt die Luft. Eine feindliche Praesenz weicht in den Schatten zurueck, und der Kampf beginnt.',
        actions: [
          GameMasterAction(
            type: GameMasterActionType.startCombat,
            payload: {'enemy_type': 'ombre'},
          ),
        ],
        choices: [
          GameMasterChoice(label: 'Den Druck aufrechterhalten'),
          GameMasterChoice(label: 'In Deckung gehen'),
        ],
      ),
      'es' => const GameMasterResponse(
        narration:
            'Tu golpe corta el aire. Una presencia hostil retrocede entre las sombras y comienza el combate.',
        actions: [
          GameMasterAction(
            type: GameMasterActionType.startCombat,
            payload: {'enemy_type': 'ombre'},
          ),
        ],
        choices: [
          GameMasterChoice(label: 'Mantener la presion'),
          GameMasterChoice(label: 'Ponerse a la defensiva'),
        ],
      ),
      _ => const GameMasterResponse(
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
      ),
    };
  }

  GameMasterResponse _examineResponse(String locale) {
    return switch (locale) {
      'en' => const GameMasterResponse(
        narration:
            'You study the surroundings. Ancient marks scar the stone near a sealed door.',
        actions: [
          GameMasterAction(
            type: GameMasterActionType.systemMessage,
            payload: {'message': 'Clue discovered.'},
          ),
        ],
        choices: [
          GameMasterChoice(label: 'Read the marks'),
          GameMasterChoice(label: 'Open the door'),
        ],
      ),
      'de' => const GameMasterResponse(
        narration:
            'Du betrachtest die Umgebung. Alte Male zerkratzen den Stein neben einer versiegelten Tuer.',
        actions: [
          GameMasterAction(
            type: GameMasterActionType.systemMessage,
            payload: {'message': 'Hinweis entdeckt.'},
          ),
        ],
        choices: [
          GameMasterChoice(label: 'Die Male lesen'),
          GameMasterChoice(label: 'Die Tuer oeffnen'),
        ],
      ),
      'es' => const GameMasterResponse(
        narration:
            'Observas los alrededores. Marcas antiguas cubren la piedra junto a una puerta sellada.',
        actions: [
          GameMasterAction(
            type: GameMasterActionType.systemMessage,
            payload: {'message': 'Pista descubierta.'},
          ),
        ],
        choices: [
          GameMasterChoice(label: 'Leer las marcas'),
          GameMasterChoice(label: 'Abrir la puerta'),
        ],
      ),
      _ => const GameMasterResponse(
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
      ),
    };
  }

  GameMasterResponse _defaultResponse(String locale) {
    return switch (locale) {
      'en' => const GameMasterResponse(
        narration:
            'The game master weighs your intent. Silence fills the hall; danger is close.',
        actions: [],
        choices: [
          GameMasterChoice(label: 'Advance carefully'),
          GameMasterChoice(label: 'Listen to the sounds'),
          GameMasterChoice(label: 'Turn back'),
        ],
      ),
      'de' => const GameMasterResponse(
        narration:
            'Der Spielleiter waegt deine Absicht. Die Stille der Halle laesst eine nahe Gefahr erahnen.',
        actions: [],
        choices: [
          GameMasterChoice(label: 'Vorsichtig vorruecken'),
          GameMasterChoice(label: 'Den Geraeuschen lauschen'),
          GameMasterChoice(label: 'Umkehren'),
        ],
      ),
      'es' => const GameMasterResponse(
        narration:
            'El maestro de juego sopesa tu intencion. El silencio de la sala anuncia un peligro cercano.',
        actions: [],
        choices: [
          GameMasterChoice(label: 'Avanzar con cautela'),
          GameMasterChoice(label: 'Escuchar los ruidos'),
          GameMasterChoice(label: 'Volver atras'),
        ],
      ),
      _ => const GameMasterResponse(
        narration:
            'Le maitre du jeu pese ton intention. Le silence de la salle laisse entendre un danger proche.',
        actions: [],
        choices: [
          GameMasterChoice(label: 'Avancer prudemment'),
          GameMasterChoice(label: 'Ecouter les bruits'),
          GameMasterChoice(label: 'Revenir en arriere'),
        ],
      ),
    };
  }
}
