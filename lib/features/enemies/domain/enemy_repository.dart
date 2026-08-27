import 'enemy.dart';

abstract interface class EnemyRepository {
  Future<List<Enemy>> fetchRoomEnemies(String roomId);
  Stream<List<Enemy>> watchRoomEnemies(String roomId);
}
