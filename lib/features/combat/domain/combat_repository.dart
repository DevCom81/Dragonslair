import 'combat_session.dart';

abstract interface class CombatRepository {
  Future<CombatSession> fetchRoomCombat(String roomId);
  Stream<CombatSession> watchRoomCombat(String roomId);
}
