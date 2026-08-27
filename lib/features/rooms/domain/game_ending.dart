enum GameEndingResult {
  victory,
  defeat,
  neutral;

  static GameEndingResult fromJson(Object? value) {
    return switch (value) {
      'victory' => GameEndingResult.victory,
      'defeat' => GameEndingResult.defeat,
      _ => GameEndingResult.neutral,
    };
  }

  String toJson() => name;
}

class GameEnding {
  const GameEnding({
    this.result = GameEndingResult.neutral,
    this.summary = '',
    this.epilogue = '',
  });

  final GameEndingResult result;
  final String summary;
  final String epilogue;

  bool get hasText => summary.trim().isNotEmpty || epilogue.trim().isNotEmpty;

  factory GameEnding.fromJson(Object? value) {
    if (value is! Map) {
      return const GameEnding();
    }
    final json = Map<String, dynamic>.from(value);
    return GameEnding(
      result: GameEndingResult.fromJson(json['result']),
      summary: json['summary'] as String? ?? '',
      epilogue: json['epilogue'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'result': result.toJson(),
      'summary': summary,
      'epilogue': epilogue,
    };
  }
}
