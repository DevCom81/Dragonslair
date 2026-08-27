class FigurineDefinition {
  const FigurineDefinition({
    required this.id,
    required this.name,
    required this.row,
    required this.column,
  });

  final int id;
  final String name;
  final int row;
  final int column;
}

class FigurineCatalog {
  const FigurineCatalog._();

  static const columns = 7;
  static const rows = 6;
  static const count = 40;
  static const assetPath = 'Assets/figurines.png';

  static final figurines = List<FigurineDefinition>.generate(count, (index) {
    return FigurineDefinition(
      id: index,
      name: 'Figurine ${index + 1}',
      row: index ~/ columns,
      column: index % columns,
    );
  });

  static FigurineDefinition byId(int id) {
    if (id < 0 || id >= count) {
      throw ArgumentError('Figurine id must be between 0 and 39.');
    }
    return figurines[id];
  }
}
