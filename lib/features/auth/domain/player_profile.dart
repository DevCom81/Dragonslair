class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.displayName,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final DateTime createdAt;

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
