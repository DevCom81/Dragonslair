enum MusicMood {
  tavern,
  exploration,
  mystery,
  tension,
  combat;

  String get assetPath => switch (this) {
    MusicMood.tavern => 'Assets/sound/Auberge.mp3',
    MusicMood.exploration => 'Assets/sound/Exploration.mp3',
    MusicMood.mystery => 'Assets/sound/Mystere.mp3',
    MusicMood.tension => 'Assets/sound/Tension.mp3',
    MusicMood.combat => 'Assets/sound/Combat.mp3',
  };

  bool get isNarrative => this != MusicMood.combat;

  String get jsonValue => name;

  static const narrativeJsonValues = {
    'tavern',
    'exploration',
    'mystery',
    'tension',
  };

  static const jsonValues = {
    ...narrativeJsonValues,
    'combat',
  };

  static MusicMood parseNarrative(Object? value) {
    return tryParseNarrative(value) ?? MusicMood.exploration;
  }

  static MusicMood? tryParseNarrative(Object? value) {
    final mood = tryParse(value);
    if (mood == null || !mood.isNarrative) {
      return null;
    }
    return mood;
  }

  static MusicMood? tryParse(Object? value) {
    if (value == null) {
      return null;
    }
    final raw = value.toString().trim().toLowerCase();
    return switch (raw) {
      'tavern' => MusicMood.tavern,
      'exploration' => MusicMood.exploration,
      'mystery' => MusicMood.mystery,
      'tension' => MusicMood.tension,
      'combat' => MusicMood.combat,
      _ => null,
    };
  }
}
