class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.description,
    required this.quantity,
    required this.type,
  });

  final String id;
  final String name;
  final String description;
  final int quantity;
  final String type;

  factory InventoryItem.fromJsonValue(Object? value) {
    if (value is String) {
      return InventoryItem(
        id: value,
        name: value,
        description: '',
        quantity: 1,
        type: 'unknown',
      );
    }

    if (value is Map<String, dynamic>) {
      return InventoryItem(
        id: value['id'] as String? ?? value['name'] as String? ?? 'item',
        name: value['name'] as String? ?? 'Objet',
        description: value['description'] as String? ?? '',
        quantity: (value['quantity'] as num?)?.toInt() ?? 1,
        type: value['type'] as String? ?? 'unknown',
      );
    }

    throw ArgumentError('Invalid inventory item: $value');
  }

  static List<InventoryItem> listFromJson(Object? value) {
    if (value == null) {
      return const [];
    }
    if (value is! List) {
      throw ArgumentError('Inventory must be a JSON list');
    }

    return value.map(InventoryItem.fromJsonValue).toList(growable: false);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'quantity': quantity,
      'type': type,
    };
  }
}
