import 'character_stats.dart';

class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.displayName,
    required this.createdAt,
    required this.stats,
    required this.sheetConfirmed,
    this.classId,
    this.avatarFigurineId,
  });

  final String id;
  final String displayName;
  final DateTime createdAt;
  final CharacterStats stats;
  final bool sheetConfirmed;
  final String? classId;
  final int? avatarFigurineId;

  bool get isReadyToPlay => sheetConfirmed && classId != null;

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      stats: CharacterStats.fromJson(json),
      sheetConfirmed: json['sheet_confirmed'] as bool? ?? false,
      classId: json['class_id'] as String?,
      avatarFigurineId: _avatarId(json['avatar_figurine_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'created_at': createdAt.toIso8601String(),
      'sheet_confirmed': sheetConfirmed,
      'class_id': classId,
      'avatar_figurine_id': avatarFigurineId,
      ...stats.toJson(),
    };
  }

  static int? _avatarId(Object? value) {
    if (value is! num) {
      return null;
    }
    final id = value.toInt();
    if (id < 0 || id > 39) {
      return null;
    }
    return id;
  }
}
