import 'package:dragons_lair/features/players/domain/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses player with structured inventory', () {
    final player = Player.fromJson({
      'id': 'player-id',
      'room_id': 'room-id',
      'user_id': 'user-id',
      'figurine_id': 7,
      'figurine_name': 'Squelette',
      'position_x': 0.25,
      'position_y': 0.75,
      'hp': 80,
      'inventory': [
        {
          'id': 'torch',
          'name': 'Torche',
          'description': 'Eclaire les tunnels',
          'quantity': 2,
          'type': 'tool',
        },
      ],
      'joined_at': '2026-08-26T12:00:00Z',
    });

    expect(player.figurineId, 7);
    expect(player.positionX, 0.25);
    expect(player.inventory.single.name, 'Torche');
  });

  test('keeps compatibility with string inventory values', () {
    final player = Player.fromJson({
      'id': 'player-id',
      'room_id': 'room-id',
      'user_id': null,
      'figurine_id': 1,
      'figurine_name': 'Chevalier',
      'position_x': 0.5,
      'position_y': 0.5,
      'hp': 100,
      'inventory': ['Potion'],
      'joined_at': '2026-08-26T12:00:00Z',
    });

    expect(player.inventory.single.name, 'Potion');
  });

  test('rejects positions outside normalized board coordinates', () {
    expect(
      () => Player.fromJson({
        'id': 'player-id',
        'room_id': 'room-id',
        'user_id': null,
        'figurine_id': 1,
        'figurine_name': 'Chevalier',
        'position_x': 1.2,
        'position_y': 0.5,
        'hp': 100,
        'inventory': [],
        'joined_at': '2026-08-26T12:00:00Z',
      }),
      throwsA(isA<ArgumentError>()),
    );
  });
}
