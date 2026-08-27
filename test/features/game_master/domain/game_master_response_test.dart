import 'package:dragons_lair/features/game/presentation/pending_ability_roll.dart';
import 'package:dragons_lair/features/game_master/domain/game_master_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses request_roll without falling back to system_message', () {
    final response = GameMasterResponse.fromJson({
      'narration': 'Le rocher bloque le passage.',
      'actions': [
        {
          'type': 'request_roll',
          'payload': {
            'player_id': 'p1',
            'ability': 'strength',
            'dc': 14,
            'reason': 'soulever le rocher',
          },
        },
      ],
      'choices': [],
    });

    expect(response.actions.single.type, GameMasterActionType.requestRoll);
    final pending = pendingRollFromResponse(response);
    expect(pending?.playerId, 'p1');
    expect(pending?.abilityKey, 'strength');
    expect(pending?.dc, 14);
  });

  test('ignores campaign_summary if present on a GM payload', () {
    final response = GameMasterResponse.fromJson({
      'narration': 'La taverne est calme.',
      'actions': <Map<String, dynamic>>[],
      'choices': <Map<String, dynamic>>[],
      'campaign_summary': 'Le prince est un usurateur.',
      'gm_secrets': <String>['ne pas afficher'],
    });

    expect(response.narration, 'La taverne est calme.');
    expect(response.toJson().containsKey('campaign_summary'), isFalse);
    expect(response.toJson().containsKey('gm_secrets'), isFalse);
  });

  test('clamps parsed DC between 5 and 25', () {
    expect(
      PendingAbilityRoll.tryParse({
        'player_id': 'p1',
        'ability': 'wisdom',
        'dc': 2,
      })?.dc,
      5,
    );
    expect(
      PendingAbilityRoll.tryParse({
        'player_id': 'p1',
        'ability': 'wisdom',
        'dc': 40,
      })?.dc,
      25,
    );
  });
}
