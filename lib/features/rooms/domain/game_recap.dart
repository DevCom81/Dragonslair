import '../../enemies/domain/enemy.dart';
import '../../events/domain/game_event.dart';
import '../../game/presentation/pending_ability_roll.dart';
import '../../players/domain/player.dart';
import 'game_ending.dart';
import 'room.dart';

const notableEventLimit = 8;

class RecapCharacter {
  const RecapCharacter({required this.name, this.classId});

  final String name;
  final String? classId;
}

class GameRecap {
  const GameRecap({
    required this.title,
    required this.result,
    required this.summary,
    required this.epilogue,
    required this.characters,
    required this.notableEvents,
    required this.defeatedEnemies,
    required this.items,
    required this.criticalRolls,
    this.duration,
    this.isDemo = false,
  });

  final String title;
  final Duration? duration;
  final GameEndingResult result;
  final String summary;
  final String epilogue;
  final List<RecapCharacter> characters;
  final List<String> notableEvents;
  final List<String> defeatedEnemies;
  final List<String> items;
  final List<String> criticalRolls;
  final bool isDemo;
}

GameRecap buildGameRecap({
  required Room room,
  required List<Player> players,
  required List<Enemy> enemies,
  required List<GameEvent> events,
  required List<PendingAbilityRoll> rolls,
}) {
  final title = _title(room);
  final start = room.startedAt ?? room.createdAt;
  final end = room.finishedAt;
  Duration? duration;
  if (end != null) {
    duration = end.difference(start);
    if (duration.isNegative) {
      duration = Duration.zero;
    }
  }
  final narrations = events
      .where((event) => event.type == GameEventType.narration)
      .toList();
  final notable = narrations.length <= notableEventLimit
      ? narrations
      : narrations.sublist(narrations.length - notableEventLimit);

  final items = <String>{};
  for (final player in players) {
    for (final item in player.inventory) {
      final name = item.name.trim();
      if (name.isNotEmpty) {
        items.add(name);
      }
    }
  }

  return GameRecap(
    title: title,
    duration: duration,
    result: room.ending.result,
    summary: room.ending.summary.trim(),
    epilogue: room.ending.epilogue.trim(),
    characters: [
      for (final player in players)
        RecapCharacter(name: player.figurineName, classId: player.classId),
    ],
    notableEvents: [
      for (final event in notable) event.content.trim(),
    ].where((line) => line.isNotEmpty).toList(),
    defeatedEnemies: [
      for (final enemy in enemies)
        if (enemy.isDefeated) enemy.name,
    ],
    items: items.toList()..sort(),
    criticalRolls: [
      for (final roll in rolls)
        if (roll.status == PendingRollStatus.resolved &&
            (roll.result == 1 || roll.result == 20))
          '${roll.abilityKey} ${roll.result}',
    ],
    isDemo: room.status == RoomStatus.demoFinished,
  );
}

String _title(Room room) {
  final fromWorld = room.worldState['title']?.toString().trim() ?? '';
  if (fromWorld.isNotEmpty) {
    return fromWorld;
  }
  final scenario = room.scenario?.trim() ?? '';
  if (scenario.isNotEmpty) {
    return scenario;
  }
  return room.name;
}
