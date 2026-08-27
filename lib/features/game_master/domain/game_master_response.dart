enum GameMasterActionType {
  narrate('narrate'),
  spawnEnemy('spawn_enemy'),
  moveEnemy('move_enemy'),
  damageEnemy('damage_enemy'),
  healEnemy('heal_enemy'),
  defeatEnemy('defeat_enemy'),
  damagePlayer('damage_player'),
  healPlayer('heal_player'),
  giveItem('give_item'),
  removeItem('remove_item'),
  startCombat('start_combat'),
  endCombat('end_combat'),
  systemMessage('system_message'),
  requestRoll('request_roll'),
  applyEffect('apply_effect'),
  removeEffect('remove_effect'),
  finishGame('finish_game');

  const GameMasterActionType(this.value);

  final String value;

  static GameMasterActionType fromJson(Object? value) {
    return GameMasterActionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => GameMasterActionType.systemMessage,
    );
  }
}

class GameMasterAction {
  const GameMasterAction({
    required this.type,
    required this.payload,
  });

  final GameMasterActionType type;
  final Map<String, dynamic> payload;

  factory GameMasterAction.fromJson(Map<String, dynamic> json) {
    return GameMasterAction(
      type: GameMasterActionType.fromJson(json['type']),
      payload: Map<String, dynamic>.from(
        json['payload'] as Map<dynamic, dynamic>? ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'payload': payload,
    };
  }
}

class GameMasterChoice {
  const GameMasterChoice({
    required this.label,
    this.action,
  });

  final String label;
  final String? action;

  factory GameMasterChoice.fromJson(Map<String, dynamic> json) {
    return GameMasterChoice(
      label: json['label'] as String,
      action: json['action'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'action': action,
    };
  }
}

class GameMasterResponse {
  const GameMasterResponse({
    required this.narration,
    required this.actions,
    required this.choices,
  });

  final String narration;
  final List<GameMasterAction> actions;
  final List<GameMasterChoice> choices;

  factory GameMasterResponse.fromJson(Map<String, dynamic> json) {
    return GameMasterResponse(
      narration: json['narration'] as String,
      actions: (json['actions'] as List<dynamic>? ?? const [])
          .map((action) => GameMasterAction.fromJson(
                Map<String, dynamic>.from(action as Map<dynamic, dynamic>),
              ))
          .toList(),
      choices: (json['choices'] as List<dynamic>? ?? const [])
          .map((choice) => GameMasterChoice.fromJson(
                Map<String, dynamic>.from(choice as Map<dynamic, dynamic>),
              ))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'narration': narration,
      'actions': actions.map((action) => action.toJson()).toList(),
      'choices': choices.map((choice) => choice.toJson()).toList(),
    };
  }
}
