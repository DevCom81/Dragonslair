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
    "spawn_enemy",
    "move_enemy",
    "damage_enemy",
    "heal_enemy",
    "defeat_enemy",
    "start_combat",
    "end_combat",
    "finish_game",
}

ENEMY_MUTATING_TYPES = {
    "spawn_enemy",
    "move_enemy",
    "damage_enemy",
    "heal_enemy",
    "defeat_enemy",
}

FINALE_TYPES = {
    "finish_game",
}

COMBAT_MUTATING_TYPES = {
    "start_combat",
    "end_combat",
}
ENEMY_HP_MAX = 500


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


PLAY_STAT_MIN = 1
PLAY_STAT_MAX = 30
DC_MIN = 5
DC_MAX = 25


def clamp_dc(value: int) -> int:
    return max(DC_MIN, min(DC_MAX, value))


def parse_request_roll(payload: dict[str, Any]) -> dict[str, Any] | None:
    player_id = player_id_from_payload(payload)
    ability = payload.get("ability") or payload.get("stat")
    if player_id is None or not isinstance(ability, str) or ability not in VALID_ABILITIES:
        return None
    if "dc" not in payload and "difficulty" not in payload:
        return None
    dc = as_int(payload.get("dc", payload.get("difficulty")), 0)
    if dc <= 0:
        return None
    reason = payload.get("reason")
    reason_text = str(reason).strip()[:240] if isinstance(reason, str) else ""
    return {
        "player_id": player_id,
        "ability": ability,
        "dc": clamp_dc(dc),
        "reason": reason_text,
    }


def effective_score_from_row(row: dict[str, Any], key: str) -> int:
    if key not in VALID_ABILITIES:
        return 10
    score = as_int(row.get(key), 10)
    inventory = row.get("inventory")
    if isinstance(inventory, list):
        for item in inventory:
            if not isinstance(item, dict) or not item.get("equipped"):
                continue
            bonuses = item.get("bonuses")
            if isinstance(bonuses, dict):
                score += as_int(bonuses.get(key), 0)
    effects = row.get("effects")
    if isinstance(effects, list):
        for effect in effects:
            if not isinstance(effect, dict):
                continue
            if effect.get("stat") == key or effect.get("ability") == key:
                score += as_int(effect.get("delta"), 0)
    return max(PLAY_STAT_MIN, min(PLAY_STAT_MAX, score))


def effective_modifier_from_row(row: dict[str, Any], key: str) -> int:
    return (effective_score_from_row(row, key) - 10) // 2


def resolve_roll_total(*, raw: int, modifier: int, dc: int) -> dict[str, Any]:
    clamped_raw = max(1, min(20, raw))
    total = clamped_raw + modifier
    return {
        "raw": clamped_raw,
        "modifier": modifier,
        "total": total,
        "success": total >= dc,
    }


COMBAT_ROUND_MAX = 999


def next_combat_state(
    *,
    current_active: bool,
    current_round: int,
    starting: bool,
    requested_round: int | None,
) -> dict[str, Any]:
    if not starting:
        return {
            "active": False,
            "round": max(0, min(COMBAT_ROUND_MAX, current_round)),
        }
    if requested_round is not None:
        return {
            "active": True,
            "round": max(1, min(COMBAT_ROUND_MAX, requested_round)),
        }
    if current_active:
        return {
            "active": True,
            "round": max(1, min(COMBAT_ROUND_MAX, current_round + 1)),
        }
    return {"active": True, "round": 1}


def combat_context_from_row(row: dict[str, Any] | None) -> dict[str, Any]:
    if not isinstance(row, dict):
        return {"active": False, "round": 0}
    return {
        "active": bool(row.get("active")),
        "round": max(0, min(COMBAT_ROUND_MAX, as_int(row.get("round"), 0))),
    }


def can_resolve_pending_roll(
    *,
    status: str,
    roll_player_id: str,
    actor_player_id: str,
) -> bool:
    return status == "pending" and roll_player_id == actor_player_id


def clamp_enemy_hp(value: int, max_hp: int) -> int:
    ceiling = max(1, min(ENEMY_HP_MAX, max_hp))
    return max(HP_MIN, min(ceiling, value))


def enemy_status_for_hp(hp: int, current_status: str = "active") -> str:
    if hp <= 0:
        return "defeated"
    if current_status == "escaped":
        return "escaped"
    return "active"


def apply_enemy_damage(hp: int, amount: int, max_hp: int) -> int:
    return clamp_enemy_hp(hp - max(0, amount), max_hp)


def apply_enemy_heal(hp: int, amount: int, max_hp: int) -> int:
    return clamp_enemy_hp(hp + max(0, amount), max_hp)


def flatten_position_payload(payload: dict[str, Any]) -> dict[str, Any]:
    data = dict(payload)
    position = data.get("position")
    if isinstance(position, dict):
        if "x" not in data and position.get("x") is not None:
            data["x"] = position.get("x")
        if "y" not in data and position.get("y") is not None:
            data["y"] = position.get("y")
    if not data.get("enemy_type"):
        type_value = data.get("type")
        if isinstance(type_value, str) and type_value.strip():
            data["enemy_type"] = type_value.strip()
    amount = data.get("amount", data.get("damage", data.get("heal")))
    if amount is not None:
        data["amount"] = amount
    enemy_id = data.get("enemy_id") or data.get("id") or data.get("target_id")
    if isinstance(enemy_id, str) and enemy_id.strip():
        data["enemy_id"] = enemy_id.strip()
    name = data.get("name") or data.get("enemy_name")
    if isinstance(name, str) and name.strip():
        data["name"] = name.strip()
    return data
