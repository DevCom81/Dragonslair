import 'package:dragons_lair/features/auth/domain/character_stats.dart';
import 'package:dragons_lair/features/enemies/domain/enemy.dart';
import 'package:dragons_lair/features/events/domain/game_event.dart';
import 'package:dragons_lair/features/game/presentation/pending_ability_roll.dart';
import 'package:dragons_lair/features/players/domain/inventory_item.dart';
import 'package:dragons_lair/features/players/domain/player.dart';
import 'package:dragons_lair/features/rooms/domain/game_ending.dart';
import 'package:dragons_lair/features/rooms/domain/game_recap.dart';
import 'package:dragons_lair/features/rooms/domain/room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildGameRecap keeps last notable narrations and critical rolls', () {
    final recap = buildGameRecap(
      room: Room(
        id: 'r1',
        name: 'La Crypte',
        status: RoomStatus.finished,
        createdAt: DateTime.utc(2026, 8, 27, 10),
        hostId: 'h1',
        minPlayers: 1,
        requiredClassIds: const [],
        scenario: 'Donjon',
        startedAt: DateTime.utc(2026, 8, 27, 10),
        finishedAt: DateTime.utc(2026, 8, 27, 11, 20),
        ending: const GameEnding(
          result: GameEndingResult.victory,
          summary: 'Le prince est sauf.',
        ),
      ),
      players: [
        Player(
          id: 'p1',
          roomId: 'r1',
          userId: 'u1',
          figurineId: 1,
          figurineName: 'Aldric',
          positionX: 0.5,
          positionY: 0.5,
          hp: 80,
          inventory: const [
            InventoryItem(
              id: 'torch',
              name: 'Torche',
              description: '',
              quantity: 1,
              type: 'tool',
            ),
          ],
          joinedAt: DateTime.utc(2026, 8, 27, 10),
          stats: CharacterStats.defaults,
          classId: 'fighter',
        ),
      ],
      enemies: [
        Enemy(
          id: 'e1',
          roomId: 'r1',
          name: 'Gobelin',
          enemyType: 'goblin',
          positionX: 0.4,
          positionY: 0.6,
          hp: 0,
          maxHp: 12,
          status: EnemyStatus.defeated,
        ),
      ],
      events: [
        for (var index = 0; index < 10; index++)
          GameEvent(
            id: 'n$index',
            roomId: 'r1',
            playerId: null,
            type: GameEventType.narration,
            content: 'fait $index',
            createdAt: DateTime.utc(2026, 8, 27, 10, index),
          ),
      ],
      rolls: const [
        PendingAbilityRoll(
          playerId: 'p1',
          abilityKey: 'strength',
          dc: 12,
          status: PendingRollStatus.resolved,
          result: 20,
        ),
        PendingAbilityRoll(
          playerId: 'p1',
          abilityKey: 'wisdom',
          dc: 10,
          status: PendingRollStatus.resolved,
          result: 11,
        ),
      ],
    );

    expect(recap.title, 'Donjon');
    expect(recap.result, GameEndingResult.victory);
    expect(recap.duration, const Duration(hours: 1, minutes: 20));
    expect(recap.characters.single.name, 'Aldric');
    expect(recap.defeatedEnemies, ['Gobelin']);
    expect(recap.items, ['Torche']);
    expect(recap.notableEvents.first, 'fait 2');
    expect(recap.notableEvents.last, 'fait 9');
    expect(recap.criticalRolls, ['strength 20']);
  });

  test('GameEnding falls back to neutral', () {
    final ending = GameEnding.fromJson({'result': 'draw', 'summary': 'ok'});
    expect(ending.result, GameEndingResult.neutral);
    expect(ending.summary, 'ok');
  });
}
