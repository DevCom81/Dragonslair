from copy import deepcopy
from typing import Any


HP_MIN = 0
HP_MAX = 100
VALID_ABILITIES = {
    "strength",
    "dexterity",
    "constitution",
    "intelligence",
    "wisdom",
    "charisma",
}
VALID_EFFECT_KINDS = {"buff", "debuff", "wound", "spell"}
MUTATING_TYPES = {
    "damage_player",
    "heal_player",
    "give_item",
    "remove_item",
    "apply_effect",
    "remove_effect",
}


def clamp_hp(value: int) -> int:
    return max(HP_MIN, min(HP_MAX, value))


def as_int(value: Any, default: int = 0) -> int:
    if isinstance(value, bool):
        return default
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str) and value.strip().lstrip("-").isdigit():
        return int(value.strip())
    return default


def player_id_from_payload(payload: dict[str, Any]) -> str | None:
    for key in ("player_id", "target_id", "target"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def apply_damage(hp: int, amount: int) -> int:
    return clamp_hp(hp - max(0, amount))


def apply_heal(hp: int, amount: int) -> int:
    return clamp_hp(hp + max(0, amount))


def give_item(
    inventory: list[dict[str, Any]],
    item: dict[str, Any],
) -> list[dict[str, Any]]:
    next_inventory = deepcopy(inventory)
    item_id = str(item.get("id") or item.get("name") or "item")
    name = str(item.get("name") or "Objet")
    quantity = max(1, as_int(item.get("quantity"), 1))
    extras = _item_extras(item)
    for existing in next_inventory:
        existing_id = str(existing.get("id") or existing.get("name") or "")
        if existing_id == item_id or existing.get("name") == name:
            existing["quantity"] = as_int(existing.get("quantity"), 1) + quantity
            return next_inventory
    next_inventory.append(
        {
            "id": item_id,
            "name": name,
            "description": str(item.get("description") or ""),
            "quantity": quantity,
            "type": str(item.get("type") or "unknown"),
            "equipped": False,
            **extras,
        }
    )
    return next_inventory


def remove_item(
    inventory: list[dict[str, Any]],
    item_ref: str,
    quantity: int = 1,
) -> list[dict[str, Any]]:
    next_inventory: list[dict[str, Any]] = []
    remaining = max(1, quantity)
    for existing in deepcopy(inventory):
        existing_id = str(existing.get("id") or "")
        existing_name = str(existing.get("name") or "")
        if remaining > 0 and item_ref in {existing_id, existing_name}:
            current_qty = as_int(existing.get("quantity"), 1)
            if current_qty > remaining:
                existing["quantity"] = current_qty - remaining
                remaining = 0
                next_inventory.append(existing)
            else:
                remaining -= current_qty
            continue
        next_inventory.append(existing)
    return next_inventory


def _item_extras(item: dict[str, Any]) -> dict[str, Any]:
    extras: dict[str, Any] = {}
    bonuses = item.get("bonuses")
    if isinstance(bonuses, dict):
        cleaned: dict[str, int] = {}
        for key, value in bonuses.items():
            if key not in VALID_ABILITIES:
                continue
            amount = as_int(value, 0)
            if amount == 0:
                continue
            cleaned[str(key)] = max(-6, min(6, amount))
        if cleaned:
            extras["bonuses"] = cleaned
    heal = as_int(item.get("heal"), 0)
    if heal > 0:
        extras["heal"] = max(1, min(50, heal))
    effect = normalize_effect(item.get("effect"))
    if effect is not None:
        extras["effect"] = effect
    return extras


def normalize_effect(raw: Any) -> dict[str, Any] | None:
    if not isinstance(raw, dict):
        return None
    effect_id = str(raw.get("id") or raw.get("name") or "").strip()
    name = str(raw.get("name") or effect_id or "Effet").strip()
    if not effect_id:
        return None
    kind = str(raw.get("kind") or raw.get("type") or "spell").strip()
    if kind not in VALID_EFFECT_KINDS:
        kind = "spell"
    stat = raw.get("stat") or raw.get("ability")
    if stat not in VALID_ABILITIES:
        stat = None
    remaining_raw = raw.get("remaining", raw.get("duration"))
    remaining = None
    if remaining_raw is not None:
        remaining = max(1, min(20, as_int(remaining_raw, 1)))
    return {
        "id": effect_id,
        "name": name,
        "kind": kind,
        "stat": stat,
        "delta": max(-6, min(6, as_int(raw.get("delta", raw.get("bonus")), 0))),
        "remaining": remaining,
        "source": str(raw.get("source") or "gm"),
    }


def upsert_effect(
    effects: list[dict[str, Any]],
    incoming: dict[str, Any],
) -> list[dict[str, Any]]:
    next_effects = deepcopy(effects)
    for index, existing in enumerate(next_effects):
        if str(existing.get("id") or "") == incoming["id"]:
            next_effects[index] = incoming
            return next_effects
    next_effects.append(incoming)
    return next_effects


def remove_effect(
    effects: list[dict[str, Any]],
    effect_id: str,
) -> list[dict[str, Any]]:
    return [
        existing
        for existing in deepcopy(effects)
        if str(existing.get("id") or "") != effect_id
    ]


def tick_effects(
    effects: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    kept: list[dict[str, Any]] = []
    expired: list[dict[str, Any]] = []
    for existing in deepcopy(effects):
        remaining = existing.get("remaining")
        if remaining is None:
            kept.append(existing)
            continue
        next_remaining = as_int(remaining, 0) - 1
        if next_remaining <= 0:
            expired.append(existing)
            continue
        existing["remaining"] = next_remaining
        kept.append(existing)
    return kept, expired


def has_request_roll(actions: list[Any]) -> bool:
    return any(getattr(action, "type", None) == "request_roll" for action in actions)
