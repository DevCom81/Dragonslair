import 'scenario_definition.dart';

class RoomStartRules {
  const RoomStartRules._();

  static List<String> blockingReasons({
    required int playerCount,
    required int minPlayers,
    required List<String> requiredClassIds,
    required Iterable<String?> takenClassIds,
  }) {
    final reasons = <String>[];
    if (playerCount < minPlayers) {
      reasons.add('Joueurs insuffisants ($playerCount / $minPlayers).');
    }

    final taken = takenClassIds.whereType<String>().toSet();
    for (final classId in requiredClassIds) {
      if (!taken.contains(classId)) {
        final label = CharacterClassCatalog.byId(classId).label;
        reasons.add('Classe obligatoire manquante : $label.');
      }
    }

    return reasons;
  }
}
