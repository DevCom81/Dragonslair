import 'package:dragons_lair/features/enemies/domain/enemy.dart';
import 'package:dragons_lair/features/enemies/presentation/enemy_token.dart';
import 'package:dragons_lair/features/game_master/domain/game_master_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/responsive_harness.dart';

Enemy _goblin({int hp = 8, String status = 'active'}) {
  return Enemy(
    id: 'e1',
    roomId: 'r1',
    name: 'Gobelin',
    enemyType: 'goblin',
    positionX: 0.5,
    positionY: 0.5,
    hp: hp,
    maxHp: 12,
    status: EnemyStatusJson.fromJson(status),
  );
}

void main() {
  testWidgets('enemy token shows name and is not a player figurine',
      (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(390, 844),
      child: Center(child: EnemyToken(enemy: _goblin(), size: 48)),
    );

    expect(find.text('Gobelin'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('Vaincu'), findsNothing);
  });

  testWidgets('defeated enemy shows defeated label', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(390, 844),
      child: Center(
        child: EnemyToken(
          enemy: _goblin(hp: 0, status: 'defeated'),
          size: 48,
        ),
      ),
    );

    expect(find.text('Vaincu'), findsOneWidget);
  });

  test('parses new enemy combat action types', () {
    final response = GameMasterResponse.fromJson({
      'narration': 'Le gobelin surgit.',
      'actions': [
        {
          'type': 'spawn_enemy',
          'payload': {'name': 'Gobelin', 'hp': 12},
        },
        {
          'type': 'damage_enemy',
          'payload': {'name': 'Gobelin', 'amount': 4},
        },
        {
          'type': 'defeat_enemy',
          'payload': {'name': 'Gobelin'},
        },
      ],
      'choices': [],
    });

    expect(response.actions[0].type, GameMasterActionType.spawnEnemy);
    expect(response.actions[1].type, GameMasterActionType.damageEnemy);
    expect(response.actions[2].type, GameMasterActionType.defeatEnemy);
  });
}
