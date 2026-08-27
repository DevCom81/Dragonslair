import 'package:dragons_lair/features/enemies/domain/enemy.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({
  double x = 0.4,
  double y = 0.6,
  int hp = 12,
  int maxHp = 12,
  String status = 'active',
}) {
  return {
    'id': 'enemy-1',
    'room_id': 'room-1',
    'name': 'Gobelin',
    'enemy_type': 'goblin',
    'position_x': x,
    'position_y': y,
    'hp': hp,
    'max_hp': maxHp,
    'status': status,
    'metadata': {'source': 'gm'},
    'created_at': '2026-08-27T08:00:00Z',
  };
}

void main() {
  test('parses a persisted enemy with normalized coordinates', () {
    final enemy = Enemy.fromJson(_row());

    expect(enemy.name, 'Gobelin');
    expect(enemy.enemyType, 'goblin');
    expect(enemy.positionX, 0.4);
    expect(enemy.positionY, 0.6);
    expect(enemy.hp, 12);
    expect(enemy.maxHp, 12);
    expect(enemy.status, EnemyStatus.active);
    expect(enemy.isDefeated, isFalse);
    expect(enemy.hpRatio, 1);
  });

  test('treats hp 0 as defeated even if status lags', () {
    final enemy = Enemy.fromJson(_row(hp: 0, status: 'active'));
    expect(enemy.isDefeated, isTrue);
    expect(enemy.hpRatio, 0);
  });

  test('parses defeated status', () {
    final enemy = Enemy.fromJson(_row(hp: 0, status: 'defeated'));
    expect(enemy.status, EnemyStatus.defeated);
    expect(enemy.isDefeated, isTrue);
  });

  test('rejects positions outside 0..1', () {
    expect(
      () => Enemy.fromJson(_row(x: 1.2)),
      throwsA(isA<ArgumentError>()),
    );
  });
}
