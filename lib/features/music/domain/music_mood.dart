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

  String get jsonValue => name;

  static const jsonValues = {
    'tavern',
    'exploration',
    'mystery',
    'tension',
    'combat',
  };

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
