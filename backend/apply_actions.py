from typing import Any

from models import GameMasterAction
from state_effects import (
    MUTATING_TYPES,
    apply_damage,
    apply_heal,
    as_int,
    give_item,
    has_request_roll,
    normalize_effect,
    player_id_from_payload,
    remove_effect,
    remove_item,
    tick_effects,
    upsert_effect,
)
from supabase_admin import fetch_room_player, fetch_room_players, patch_room_player


def _inventory(row: dict[str, Any]) -> list[dict[str, Any]]:
    value = row.get("inventory")
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]


def _effects(row: dict[str, Any]) -> list[dict[str, Any]]:
    value = row.get("effects")
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]


async def apply_game_master_actions(
    *,
    room_id: str,
    actions: list[GameMasterAction],
) -> list[str]:
    if has_request_roll(actions):
        return ["Jet demande : aucun effet applique avant le resultat."]

    summaries: list[str] = []
    for action in actions:
        if action.type not in MUTATING_TYPES:
            continue
        summary = await _apply_one(room_id=room_id, action=action)
        if summary:
            summaries.append(summary)
    summaries.extend(await _tick_room_effects(room_id=room_id))
    return summaries


async def _apply_one(*, room_id: str, action: GameMasterAction) -> str | None:
    payload = action.payload
    player_id = player_id_from_payload(payload)
    if player_id is None:
        return None

    row = await fetch_room_player(room_id=room_id, player_id=player_id)
    if row is None:
        return None

    name = str(row.get("figurine_name") or "Aventurier")
    hp = as_int(row.get("hp"), 0)
    inventory = _inventory(row)
    effects = _effects(row)

    if action.type == "damage_player":
        amount = max(0, as_int(payload.get("amount", payload.get("damage")), 0))
        if amount <= 0:
            return None
        next_hp = apply_damage(hp, amount)
        await patch_room_player(
            room_id=room_id,
            player_id=player_id,
            fields={"hp": next_hp},
        )
        return f"{name} perd {amount} PV ({hp} -> {next_hp})."

    if action.type == "heal_player":
        amount = max(0, as_int(payload.get("amount", payload.get("heal")), 0))
        if amount <= 0:
            return None
        next_hp = apply_heal(hp, amount)
        await patch_room_player(
            room_id=room_id,
            player_id=player_id,
            fields={"hp": next_hp},
        )
        return f"{name} recupere {amount} PV ({hp} -> {next_hp})."

    if action.type == "give_item":
        item = payload.get("item")
        if not isinstance(item, dict):
            name_value = payload.get("name")
            if not isinstance(name_value, str) or not name_value.strip():
                return None
            item = {
                "id": payload.get("id") or name_value,
                "name": name_value,
                "description": payload.get("description") or "",
                "quantity": payload.get("quantity") or 1,
                "type": payload.get("item_type") or payload.get("type") or "unknown",
                "bonuses": payload.get("bonuses"),
                "heal": payload.get("heal"),
                "effect": payload.get("effect"),
            }
        next_inventory = give_item(inventory, item)
        await patch_room_player(
            room_id=room_id,
            player_id=player_id,
            fields={"inventory": next_inventory},
        )
        return f"{name} obtient {item.get('name', 'un objet')}."

    if action.type == "remove_item":
        item_ref = payload.get("item_id") or payload.get("name") or payload.get("item")
        if isinstance(item_ref, dict):
            item_ref = item_ref.get("id") or item_ref.get("name")
        if not isinstance(item_ref, str) or not item_ref.strip():
            return None
        quantity = as_int(payload.get("quantity"), 1)
        next_inventory = remove_item(inventory, item_ref.strip(), quantity)
        await patch_room_player(
            room_id=room_id,
            player_id=player_id,
            fields={"inventory": next_inventory},
        )
        return f"{name} perd {item_ref}."

    if action.type == "apply_effect":
        incoming = normalize_effect(payload.get("effect") or payload)
        if incoming is None:
            return None
        next_effects = upsert_effect(effects, incoming)
        await patch_room_player(
            room_id=room_id,
            player_id=player_id,
            fields={"effects": next_effects},
        )
        return f"{name} recoit {incoming['name']}."

    if action.type == "remove_effect":
        effect_id = payload.get("effect_id") or payload.get("id") or payload.get("name")
        if not isinstance(effect_id, str) or not effect_id.strip():
            return None
        next_effects = remove_effect(effects, effect_id.strip())
        await patch_room_player(
            room_id=room_id,
            player_id=player_id,
            fields={"effects": next_effects},
        )
        return f"{name} perd l effet {effect_id}."

    return None


async def _tick_room_effects(*, room_id: str) -> list[str]:
    summaries: list[str] = []
    rows = await fetch_room_players(room_id=room_id)
    for row in rows:
        player_id = row.get("id")
        if not isinstance(player_id, str) or not player_id:
            continue
        current = _effects(row)
        next_effects, expired = tick_effects(current)
        if not expired and next_effects == current:
            continue
        await patch_room_player(
            room_id=room_id,
            player_id=player_id,
            fields={"effects": next_effects},
        )
        name = str(row.get("figurine_name") or "Aventurier")
        for effect in expired:
            summaries.append(
                f"{name} : {effect.get('name', 'effet')} se dissipe."
            )
    return summaries
