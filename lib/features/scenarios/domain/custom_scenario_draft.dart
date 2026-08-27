import 'world_state.dart';

const scenarioPromptMinLength = 20;

enum ScenarioDifficulty {
  easy,
  standard,
  hard,
}

enum ScenarioDuration {
  short,
  medium,
  long,
}

enum ScenarioOrientation {
  combat,
  exploration,
  investigation,
  roleplay,
  survival,
}

class CustomScenarioDraft {
  const CustomScenarioDraft({
    this.prompt = '',
    this.title = '',
    this.tone = '',
    this.difficulty = ScenarioDifficulty.standard,
    this.duration = ScenarioDuration.medium,
    this.orientations = const {},
    this.improvise = true,
    this.permadeath = false,
    this.pvp = false,
    this.betrayals = false,
  });

  final String prompt;
  final String title;
  final String tone;
  final ScenarioDifficulty difficulty;
  final ScenarioDuration duration;
  final Set<ScenarioOrientation> orientations;
  final bool improvise;
  final bool permadeath;
  final bool pvp;
  final bool betrayals;

  bool get hasEnoughPrompt => prompt.trim().length >= scenarioPromptMinLength;

  CustomScenarioDraft copyWith({
    String? prompt,
    String? title,
    String? tone,
    ScenarioDifficulty? difficulty,
    ScenarioDuration? duration,
    Set<ScenarioOrientation>? orientations,
    bool? improvise,
    bool? permadeath,
    bool? pvp,
    bool? betrayals,
  }) {
    return CustomScenarioDraft(
      prompt: prompt ?? this.prompt,
      title: title ?? this.title,
      tone: tone ?? this.tone,
      difficulty: difficulty ?? this.difficulty,
      duration: duration ?? this.duration,
      orientations: orientations ?? this.orientations,
      improvise: improvise ?? this.improvise,
      permadeath: permadeath ?? this.permadeath,
      pvp: pvp ?? this.pvp,
      betrayals: betrayals ?? this.betrayals,
    );
  }

  Map<String, dynamic> mockWorldState() {
    final trimmedTitle = title.trim();
    return sanitizePublicWorldState({
      'title': trimmedTitle.isEmpty ? 'Aventure' : trimmedTitle,
      'setting': prompt.trim(),
      'tone': tone.trim(),
      'public_objective': prompt.trim(),
      'starting_location': {
        'name': 'Le seuil',
        'description': 'Le point de depart de votre aventure.',
      },
      'initial_situation': prompt.trim(),
      'known_facts': <String>[],
      'starting_npcs': <Map<String, String>>[],
      'initial_threats': <Map<String, String>>[],
      'opening_narration':
          'L aventure commence. Le monde se forme autour de votre intention.',
    });
  }

  Map<String, dynamic> toGenerateJson(String roomId) {
    return {
      'room_id': roomId,
      'prompt': prompt.trim(),
      'title': title.trim(),
      'tone': tone.trim(),
      'difficulty': difficulty.name,
      'duration': duration.name,
      'orientations':
          orientations.map((item) => item.name).toList(growable: false),
      'improvise': improvise,
      'permadeath': permadeath,
      'pvp': pvp,
      'betrayals': betrayals,
    };
  }
}
