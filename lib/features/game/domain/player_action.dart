enum PlayerActionType {
  examine('Examiner'),
  interact('Interagir'),
  attack('Attaquer'),
  defend('Defendre'),
  useItem('Utiliser un objet'),
  free('Action libre');

  const PlayerActionType(this.label);

  final String label;

  String format(String detail) {
    final trimmed = detail.trim();
    if (this == PlayerActionType.free) {
      return trimmed;
    }
    if (trimmed.isEmpty) {
      return label;
    }
    return '$label : $trimmed';
  }
}
