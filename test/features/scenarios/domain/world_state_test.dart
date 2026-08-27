import 'package:dragons_lair/features/rooms/domain/room.dart';
import 'package:dragons_lair/features/scenarios/domain/custom_scenario_draft.dart';
import 'package:dragons_lair/features/scenarios/domain/world_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitizePublicWorldState drops GM secrets', () {
    final public = sanitizePublicWorldState({
      'title': 'La Route',
      'gm_secrets': ['le prince est un usurateur'],
      'gm_state': {'hidden': true},
      'secrets': ['nope'],
      'setting': 'Un royaume en guerre',
    });

    expect(public['title'], 'La Route');
    expect(public.containsKey('gm_secrets'), isFalse);
    expect(public.containsKey('gm_state'), isFalse);
    expect(public.containsKey('secrets'), isFalse);
  });

  test('Room.fromJson never keeps gm_secrets on world_state', () {
    final room = Room.fromJson({
      'id': 'room-id',
      'name': 'Escorte',
      'scenario': 'Aventure libre',
      'scenario_id': 'custom',
      'status': 'waiting',
      'created_at': '2026-08-27T12:00:00Z',
      'host_id': 'user-id',
      'world_state': {
        'title': 'Escorte',
        'gm_secrets': ['un assassin est a table'],
      },
    });

    expect(room.scenarioId, 'custom');
    expect(room.worldState['title'], 'Escorte');
    expect(room.worldState.containsKey('gm_secrets'), isFalse);
  });

  test('mock world state has no secrets', () {
    const draft = CustomScenarioDraft(
      prompt:
          'Quatre mercenaires escortent un prince a travers un royaume en guerre.',
      title: 'Escorte',
    );
    final world = draft.mockWorldState();
    expect(world['title'], 'Escorte');
    expect(world.containsKey('gm_secrets'), isFalse);
    expect(draft.hasEnoughPrompt, isTrue);
  });
}
