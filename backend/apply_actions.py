from typing import Any

from pydantic import ValidationError

from finish_game import parse_finish_game
from models import (
    DefeatEnemyPayload,
    EnemyHpPayload,
    GameMasterAction,
    MoveEnemyPayload,
    SpawnEnemyPayload,
    StartCombatPayload,
)
from state_effects import (
    COMBAT_MUTATING_TYPES,
    ENEMY_MUTATING_TYPES,
    FINALE_TYPES,
    MUTATING_TYPES,
    apply_damage,
    apply_heal,
    as_int,
    flatten_position_payload,
    give_item,
    has_request_roll,
    next_combat_state,
    normalize_effect,
    parse_request_roll,
    player_id_from_payload,
    remove_effect,
    remove_item,
    tick_effects,
    upsert_effect,
)
from supabase_admin import (
    create_enemy,
    create_pending_roll,
    damage_enemy,
    fetch_combat_session,
    fetch_room_enemy,
    fetch_room_enemy_by_name,
    fetch_room_narrative_context,
    fetch_room_player,
    fetch_room_players,
    finish_room,
    heal_enemy,
    move_enemy,
    patch_room_player,
    set_enemy_status,
    upsert_combat_session,
)


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
        summaries = await persist_request_rolls(room_id=room_id, actions=actions)
        for action in actions:
            if action.type in COMBAT_MUTATING_TYPES:
                summary = await _apply_combat(room_id=room_id, action=action)
                if summary:
                    summaries.append(summary)
            elif action.type in FINALE_TYPES:
                summary = await _apply_finish(room_id=room_id, action=action)
                if summary:
                    summaries.append(summary)
        return summaries

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
    if action.type == "finish_game":
        return await _apply_finish(room_id=room_id, action=action)
    if action.type in ENEMY_MUTATING_TYPES:
        return await _apply_enemy(room_id=room_id, action=action)
    if action.type in COMBAT_MUTATING_TYPES:
        return await _apply_combat(room_id=room_id, action=action)

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


async def _resolve_enemy_row(
    *,
    room_id: str,
    enemy_id: str | None,
    name: str | None,
) -> dict | None:
    if enemy_id:
        row = await fetch_room_enemy(room_id=room_id, enemy_id=enemy_id)
        if row is not None:
            return row
    if name:
        return await fetch_room_enemy_by_name(room_id=room_id, name=name)
    return None


async def _apply_enemy(*, room_id: str, action: GameMasterAction) -> str | None:
    try:
        data = flatten_position_payload(action.payload)
        if action.type == "spawn_enemy":
            payload = SpawnEnemyPayload.model_validate(data)
            max_hp = payload.max_hp or payload.hp
            if max_hp < payload.hp:
                max_hp = payload.hp
            row = await create_enemy(
                room_id=room_id,
                name=payload.name.strip(),
                enemy_type=payload.enemy_type.strip(),
                position_x=payload.x,
                position_y=payload.y,
                hp=payload.hp,
                max_hp=max_hp,
            )
            enemy_id = row.get("id", "")
            return (
                f"{payload.name} apparait ({payload.hp}/{max_hp} PV"
                f"{f', id {enemy_id}' if enemy_id else ''})."
            )

        if action.type == "move_enemy":
            payload = MoveEnemyPayload.model_validate(data)
            row = await _resolve_enemy_row(
                room_id=room_id,
                enemy_id=payload.enemy_id,
                name=payload.name,
            )
            if row is None:
                return None
            enemy_id = str(row["id"])
            await move_enemy(
                room_id=room_id,
                enemy_id=enemy_id,
                x=payload.x,
                y=payload.y,
            )
            return f"{row.get('name', 'Ennemi')} se deplace."

        if action.type == "damage_enemy":
            payload = EnemyHpPayload.model_validate(data)
            if payload.amount <= 0:
                return None
            row = await _resolve_enemy_row(
                room_id=room_id,
                enemy_id=payload.enemy_id,
                name=payload.name,
            )
            if row is None:
                return None
            result = await damage_enemy(
                room_id=room_id,
                enemy_id=str(row["id"]),
                amount=payload.amount,
            )
            if result is None:
                return None
            suffix = " Vaincu." if result["status"] == "defeated" else ""
            return (
                f"{result['name']} perd {payload.amount} PV "
                f"({result['hp']} -> {result['next_hp']}).{suffix}"
            )

        if action.type == "heal_enemy":
            payload = EnemyHpPayload.model_validate(data)
            if payload.amount <= 0:
                return None
            row = await _resolve_enemy_row(
                room_id=room_id,
                enemy_id=payload.enemy_id,
                name=payload.name,
            )
            if row is None:
                return None
            result = await heal_enemy(
                room_id=room_id,
                enemy_id=str(row["id"]),
                amount=payload.amount,
            )
            if result is None:
                return None
            return (
                f"{result['name']} recupere {payload.amount} PV "
                f"({result['hp']} -> {result['next_hp']})."
            )

        if action.type == "defeat_enemy":
            payload = DefeatEnemyPayload.model_validate(data)
            row = await _resolve_enemy_row(
                room_id=room_id,
                enemy_id=payload.enemy_id,
                name=payload.name,
            )
            if row is None:
                return None
            await set_enemy_status(
                room_id=room_id,
                enemy_id=str(row["id"]),
                status="defeated",
                hp=0,
            )
            return f"{row.get('name', 'Ennemi')} est vaincu."
    except ValidationError:
        return None

    return None


async def _apply_combat(*, room_id: str, action: GameMasterAction) -> str | None:
    try:
        if action.type == "start_combat":
            payload = StartCombatPayload.model_validate(action.payload or {})
            current = await fetch_combat_session(room_id=room_id)
            next_state = next_combat_state(
                current_active=bool(current.get("active")) if current else False,
                current_round=as_int(current.get("round"), 0) if current else 0,
                starting=True,
                requested_round=payload.round,
            )
            await upsert_combat_session(
                room_id=room_id,
                active=True,
                round=next_state["round"],
            )
            return f"Combat : round {next_state['round']}."

        if action.type == "end_combat":
            current = await fetch_combat_session(room_id=room_id)
            next_state = next_combat_state(
                current_active=bool(current.get("active")) if current else False,
                current_round=as_int(current.get("round"), 0) if current else 0,
                starting=False,
                requested_round=None,
            )
            await upsert_combat_session(
                room_id=room_id,
                active=False,
                round=next_state["round"],
            )
            return "Combat termine."
    except ValidationError:
        return None

    return None


async def _apply_finish(*, room_id: str, action: GameMasterAction) -> str | None:
    ending = parse_finish_game(action.payload)
    context = await fetch_room_narrative_context(room_id=room_id)
    status = (
        "demo_finished"
        if str(context.get("scenario_id") or "") == "demo"
        else "finished"
    )
    changed = await finish_room(room_id=room_id, ending=ending, status=status)
    if not changed:
        return None
    return f"Fin de partie ({ending['result']})."


async def persist_request_rolls(
    *,
    room_id: str,
    actions: list[GameMasterAction],
) -> list[str]:
    summaries: list[str] = [
        "Jet demande : aucun effet applique avant le resultat.",
    ]
    for action in actions:
        if action.type != "request_roll":
            continue
        parsed = parse_request_roll(action.payload)
        if parsed is None:
            continue
        player_id = parsed["player_id"]
        row = await fetch_room_player(room_id=room_id, player_id=player_id)
        if row is None:
            continue
        await create_pending_roll(
            room_id=room_id,
            player_id=player_id,
            ability=parsed["ability"],
            dc=parsed["dc"],
            reason=parsed["reason"],
        )
        name = str(row.get("figurine_name") or "Aventurier")
        summaries.append(
            f"Jet de {parsed['ability']} demande a {name} (DD {parsed['dc']})."
        )
    return summaries


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
