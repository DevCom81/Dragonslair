class DiceRoll {
  const DiceRoll({
    required this.count,
    required this.sides,
    required this.values,
  });

  final int count;
  final int sides;
  final List<int> values;

  int get total => values.fold(0, (sum, value) => sum + value);

  String get notation => '${count}d$sides';

  String get label => '$notation : ${values.join(', ')} = $total';
}
