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
    expect(player.classId, isNull);
    expect(player.stats.strength, 10);
  });

  test('parses class snapshot and character stats', () {
    final player = Player.fromJson({
      'id': 'player-id',
      'room_id': 'room-id',
      'user_id': 'user-id',
      'figurine_id': 7,
      'figurine_name': 'Squelette',
      'position_x': 0.25,
      'position_y': 0.75,
      'hp': 80,
      'inventory': [],
      'joined_at': '2026-08-26T12:00:00Z',
      'class_id': 'healer',
      'strength': 12,
      'dexterity': 11,
      'constitution': 14,
      'intelligence': 9,
      'wisdom': 16,
      'charisma': 8,
    });

    expect(player.classId, 'healer');
    expect(player.stats.wisdom, 16);
    expect(player.stats.charisma, 8);
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
