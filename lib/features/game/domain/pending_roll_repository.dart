import '../presentation/pending_ability_roll.dart';

abstract interface class PendingRollRepository {
  Future<List<PendingAbilityRoll>> fetchRoomRolls(String roomId);
  Stream<List<PendingAbilityRoll>> watchRoomRolls(String roomId);
}
