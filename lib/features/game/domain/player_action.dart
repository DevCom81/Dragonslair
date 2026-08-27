enum PlayerActionType {
  examine,
  interact,
  attack,
  defend,
  useItem,
  free;

  String get protocolLabel {
    return switch (this) {
      PlayerActionType.examine => 'Examiner',
      PlayerActionType.interact => 'Interagir',
      PlayerActionType.attack => 'Attaquer',
      PlayerActionType.defend => 'Defendre',
      PlayerActionType.useItem => 'Utiliser un objet',
      PlayerActionType.free => 'Action libre',
    };
  }

  String format(String detail) {
    final trimmed = detail.trim();
    if (this == PlayerActionType.free) {
      return trimmed;
    }
    if (trimmed.isEmpty) {
      return protocolLabel;
    }
    return '$protocolLabel : $trimmed';
  }
}
