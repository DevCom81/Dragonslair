import '../../game_master/domain/game_master_response.dart';

GameMasterResponse cannedDemoEnding(String locale) {
  return switch (locale) {
    'fr' => const GameMasterResponse(
        narration:
            'Le souffle du wyrm s engouffre dans la cave. La porte de pierre se referme a demi, et l aventure s interrompt au seuil du secret.',
        actions: [
          GameMasterAction(
            type: GameMasterActionType.finishGame,
            payload: {
              'result': 'neutral',
              'summary': 'La demo s acheve au moment ou le danger se revele.',
              'epilogue': 'L aventure ne fait que commencer.',
            },
          ),
        ],
        choices: [GameMasterChoice(label: 'Revenir a la taverne')],
      ),
    'de' => const GameMasterResponse(
        narration:
            'Der Atem des Wyrms fuellt den Keller. Die Steintuer schliesst sich halb, und das Abenteuer stockt an der Schwelle des Geheimnisses.',
        actions: [
          GameMasterAction(
            type: GameMasterActionType.finishGame,
            payload: {
              'result': 'neutral',
              'summary': 'Die Demo endet, als die Gefahr sichtbar wird.',
              'epilogue': 'Das Abenteuer hat gerade erst begonnen.',
            },
          ),
        ],
        choices: [GameMasterChoice(label: 'Zurueck zur Taverne')],
      ),
    'es' => const GameMasterResponse(
        narration:
            'El aliento del wyrm llena la bodega. La puerta de piedra se cierra a medias y la aventura se detiene al borde del secreto.',
        actions: [
          GameMasterAction(
            type: GameMasterActionType.finishGame,
            payload: {
              'result': 'neutral',
              'summary': 'La demo termina cuando el peligro se revela.',
              'epilogue': 'La aventura no ha hecho mas que empezar.',
            },
          ),
        ],
        choices: [GameMasterChoice(label: 'Volver a la taberna')],
      ),
    _ => const GameMasterResponse(
        narration:
            'The wyrm\'s breath floods the cellar. The stone door closes halfway, and the adventure halts at the threshold of the secret.',
        actions: [
          GameMasterAction(
            type: GameMasterActionType.finishGame,
            payload: {
              'result': 'neutral',
              'summary': 'The demo ends just as the danger reveals itself.',
              'epilogue': 'The adventure is only beginning.',
            },
          ),
        ],
        choices: [GameMasterChoice(label: 'Return to the tavern')],
      ),
  };
}
