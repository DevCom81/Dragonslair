import 'package:dragons_lair/features/events/domain/game_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses game event from Supabase row', () {
    final event = GameEvent.fromJson({
      'id': 'event-id',
      'room_id': 'room-id',
      'player_id': null,
      'type': 'narration',
      'content': 'La porte grince dans la penombre.',
      'created_at': '2026-08-26T12:00:00Z',
    });

    expect(event.type, GameEventType.narration);
    expect(event.playerId, isNull);
    expect(event.content, contains('porte'));
  });

  test('rejects unknown event type', () {
    expect(() => GameEventType.fromJson('loot'), throwsA(isA<ArgumentError>()));
  });
}
