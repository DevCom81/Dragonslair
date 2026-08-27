import '../../scenarios/domain/world_state.dart';
import 'game_ending.dart';
import 'room_locale.dart';

enum RoomStatus {
  waiting,
  playing,
  paused,
  finished;

  static RoomStatus fromJson(Object? value) {
    return switch (value) {
      'waiting' => RoomStatus.waiting,
      'playing' => RoomStatus.playing,
      'paused' => RoomStatus.paused,
      'finished' => RoomStatus.finished,
      _ => throw ArgumentError('Unknown room status: $value'),
    };
  }

  String toJson() => name;
}

class Room {
  const Room({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.hostId,
    required this.minPlayers,
    required this.requiredClassIds,
    this.scenario,
    this.scenarioId,
    this.joinCode,
    this.scenarioPrompt = '',
    this.worldState = const {},
    this.locale = fallbackRoomLocale,
    this.startedAt,
    this.finishedAt,
    this.ending = const GameEnding(),
  });

  final String id;
  final String name;
  final String? scenario;
  final String? scenarioId;
  final RoomStatus status;
  final DateTime createdAt;
  final String? hostId;
  final String? joinCode;
  final int minPlayers;
  final List<String> requiredClassIds;
  final String scenarioPrompt;
  final Map<String, dynamic> worldState;
  final String locale;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final GameEnding ending;

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      scenario: json['scenario'] as String?,
      scenarioId: json['scenario_id'] as String?,
      status: RoomStatus.fromJson(json['status']),
      createdAt: DateTime.parse(json['created_at'] as String),
      hostId: json['host_id'] as String?,
      joinCode: json['join_code'] as String?,
      minPlayers: (json['min_players'] as num?)?.toInt() ?? 1,
      requiredClassIds: _stringList(json['required_class_ids']),
      scenarioPrompt: json['scenario_prompt'] as String? ?? '',
      worldState: sanitizePublicWorldState(json['world_state']),
      locale: normalizeRoomLocale(json['locale']),
      startedAt: _dateTime(json['started_at']),
      finishedAt: _dateTime(json['finished_at']),
      ending: GameEnding.fromJson(json['ending']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'scenario': scenario,
      'scenario_id': scenarioId,
      'status': status.toJson(),
      'created_at': createdAt.toIso8601String(),
      'host_id': hostId,
      'join_code': joinCode,
      'min_players': minPlayers,
      'required_class_ids': requiredClassIds,
      'scenario_prompt': scenarioPrompt,
      'world_state': worldState,
      'locale': locale,
      'started_at': startedAt?.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'ending': ending.toJson(),
    };
  }

  static DateTime? _dateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value.map((item) => item.toString()).toList();
  }
}
