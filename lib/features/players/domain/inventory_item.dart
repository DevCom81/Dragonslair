import 'player_effect.dart';

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.description,
    required this.quantity,
    required this.type,
    this.equipped = false,
    this.bonuses = const {},
    this.heal,
    this.grantedEffect,
  });

  final String id;
  final String name;
  final String description;
  final int quantity;
  final String type;
  final bool equipped;
  final Map<String, int> bonuses;
  final int? heal;
  final PlayerEffect? grantedEffect;

  int bonusFor(String key) => bonuses[key] ?? 0;

  InventoryItem copyWith({
    String? id,
    String? name,
    String? description,
    int? quantity,
    String? type,
    bool? equipped,
    Map<String, int>? bonuses,
    int? heal,
    PlayerEffect? grantedEffect,
    bool clearHeal = false,
    bool clearGrantedEffect = false,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      type: type ?? this.type,
      equipped: equipped ?? this.equipped,
      bonuses: bonuses ?? this.bonuses,
      heal: clearHeal ? null : (heal ?? this.heal),
      grantedEffect:
          clearGrantedEffect ? null : (grantedEffect ?? this.grantedEffect),
    );
  }

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
      final healValue = (value['heal'] as num?)?.toInt();
      return InventoryItem(
        id: value['id'] as String? ?? value['name'] as String? ?? 'item',
        name: value['name'] as String? ?? 'Objet',
        description: value['description'] as String? ?? '',
        quantity: (value['quantity'] as num?)?.toInt() ?? 1,
        type: value['type'] as String? ?? 'unknown',
        equipped: value['equipped'] == true,
        bonuses: _bonuses(value['bonuses']),
        heal: healValue == null || healValue <= 0 ? null : healValue.clamp(1, 50),
        grantedEffect: PlayerEffect.tryParse(value['effect']),
      );
    }

    throw ArgumentError('Invalid inventory item: $value');
  }

  static Map<String, int> _bonuses(Object? value) {
    if (value is! Map) {
      return const {};
    }
    const keys = {
      'strength',
      'dexterity',
      'constitution',
      'intelligence',
      'wisdom',
      'charisma',
    };
    final result = <String, int>{};
    for (final entry in value.entries) {
      final key = entry.key.toString();
      if (!keys.contains(key)) {
        continue;
      }
      final amount = (entry.value as num?)?.toInt();
      if (amount == null || amount == 0) {
        continue;
      }
      result[key] = amount.clamp(-6, 6);
    }
    return result;
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
      'equipped': equipped,
      'bonuses': bonuses,
      if (heal != null) 'heal': heal,
      if (grantedEffect != null) 'effect': grantedEffect!.toJson(),
    };
  }
}
