import '../../auth/domain/character_stats.dart';
import 'inventory_item.dart';
import 'player_effect.dart';

const equippableItemTypes = {'weapon', 'armor', 'shield', 'accessory'};
const potionItemTypes = {'potion', 'consumable'};
const playStatMin = 1;
const playStatMax = 30;
const defaultPotionHeal = 20;

bool isEquippable(InventoryItem item) => equippableItemTypes.contains(item.type);

bool isPotion(InventoryItem item) {
  return potionItemTypes.contains(item.type) || (item.heal ?? 0) > 0;
}

bool isScroll(InventoryItem item) => item.type == 'scroll';

int effectiveScore({
  required CharacterStats stats,
  required List<InventoryItem> inventory,
  required List<PlayerEffect> effects,
  required String key,
}) {
  var score = stats.scoreFor(key);
  for (final item in inventory) {
    if (item.equipped) {
      score += item.bonusFor(key);
    }
  }
  for (final effect in effects) {
    if (effect.stat == key) {
      score += effect.delta;
    }
  }
  if (score < playStatMin) {
    return playStatMin;
  }
  if (score > playStatMax) {
    return playStatMax;
  }
  return score;
}

int effectiveModifier({
  required CharacterStats stats,
  required List<InventoryItem> inventory,
  required List<PlayerEffect> effects,
  required String key,
}) {
  return (effectiveScore(
        stats: stats,
        inventory: inventory,
        effects: effects,
        key: key,
      ) -
      10) ~/
      2;
}

List<InventoryItem> setEquipped({
  required List<InventoryItem> inventory,
  required String itemId,
  required bool equipped,
}) {
  InventoryItem? target;
  for (final item in inventory) {
    if (item.id == itemId) {
      target = item;
      break;
    }
  }
  if (target == null || !isEquippable(target)) {
    return inventory;
  }

  return [
    for (final item in inventory)
      if (item.id == itemId)
        item.copyWith(equipped: equipped)
      else if (equipped && item.equipped && item.type == target.type)
        item.copyWith(equipped: false)
      else
        item,
  ];
}

({List<InventoryItem> inventory, int heal}) consumePotion({
  required List<InventoryItem> inventory,
  required String itemId,
}) {
  final next = <InventoryItem>[];
  var heal = 0;
  for (final item in inventory) {
    if (item.id != itemId || !isPotion(item) || heal > 0) {
      next.add(item);
      continue;
    }
    heal = item.heal ?? defaultPotionHeal;
    if (item.quantity > 1) {
      next.add(item.copyWith(quantity: item.quantity - 1));
    }
  }
  return (inventory: next, heal: heal);
}

({List<InventoryItem> inventory, PlayerEffect? effect}) consumeScroll({
  required List<InventoryItem> inventory,
  required String itemId,
}) {
  final next = <InventoryItem>[];
  PlayerEffect? effect;
  for (final item in inventory) {
    if (item.id != itemId || !isScroll(item) || effect != null) {
      next.add(item);
      continue;
    }
    if (item.grantedEffect == null) {
      next.add(item);
      continue;
    }
    effect = item.grantedEffect;
    if (item.quantity > 1) {
      next.add(item.copyWith(quantity: item.quantity - 1));
    }
  }
  return (inventory: next, effect: effect);
}

List<PlayerEffect> upsertEffect(
  List<PlayerEffect> effects,
  PlayerEffect incoming,
) {
  final next = <PlayerEffect>[];
  var replaced = false;
  for (final effect in effects) {
    if (effect.id == incoming.id) {
      next.add(incoming);
      replaced = true;
    } else {
      next.add(effect);
    }
  }
  if (!replaced) {
    next.add(incoming);
  }
  return next;
}
