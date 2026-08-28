import os

import httpx


class SupabaseAdminError(RuntimeError):
    pass


class RoomFinishedError(RuntimeError):
    pass


def _supabase_url() -> str:
    url = os.getenv("SUPABASE_URL", "").rstrip("/")
    if not url:
        raise SupabaseAdminError("SUPABASE_URL is not configured.")
    return url


def _anon_key() -> str:
    key = os.getenv("SUPABASE_ANON_KEY", "")
    if not key:
        raise SupabaseAdminError("SUPABASE_ANON_KEY is not configured.")
    return key


def _service_role_key() -> str:
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    if not key:
        raise SupabaseAdminError("SUPABASE_SERVICE_ROLE_KEY is not configured.")
    return key


async def get_user_id_from_access_token(access_token: str) -> str:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f"{_supabase_url()}/auth/v1/user",
            headers={
                "Authorization": f"Bearer {access_token}",
                "apikey": _anon_key(),
            },
        )

    if response.status_code != 200:
        raise SupabaseAdminError("Invalid or expired player token.")

    user_id = response.json().get("id")
    if not isinstance(user_id, str) or not user_id:
        raise SupabaseAdminError("Supabase Auth returned an invalid user.")
    return user_id


async def assert_player_belongs_to_user(
    *,
    user_id: str,
    player_id: str,
    room_id: str,
) -> None:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f"{_supabase_url()}/rest/v1/players",
            params={
                "id": f"eq.{player_id}",
                "room_id": f"eq.{room_id}",
                "user_id": f"eq.{user_id}",
                "select": "id",
            },
            headers={
                "apikey": _service_role_key(),
                "Authorization": f"Bearer {_service_role_key()}",
            },
        )

    if response.status_code >= 400:
        raise SupabaseAdminError("Unable to verify player ownership.")

    rows = response.json()
    if not isinstance(rows, list) or not rows:
        raise SupabaseAdminError("Player does not belong to this user or room.")


def _admin_headers() -> dict[str, str]:
    return {
        "apikey": _service_role_key(),
        "Authorization": f"Bearer {_service_role_key()}",
        "Content-Type": "application/json",
    }


async def fetch_room_player(*, room_id: str, player_id: str) -> dict | None:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f"{_supabase_url()}/rest/v1/players",
            params={
                "id": f"eq.{player_id}",
                "room_id": f"eq.{room_id}",
                "select": (
                    "id,hp,inventory,figurine_name,effects,"
                    "strength,dexterity,constitution,intelligence,wisdom,charisma"
                ),
            },
            headers=_admin_headers(),
        )

    if response.status_code >= 400:
        raise SupabaseAdminError("Unable to load player state.")

    rows = response.json()
    if not isinstance(rows, list) or not rows:
        return None
    row = rows[0]
    return row if isinstance(row, dict) else None


async def patch_room_player(
    *,
    room_id: str,
    player_id: str,
    fields: dict,
) -> None:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.patch(
            f"{_supabase_url()}/rest/v1/players",
            params={
                "id": f"eq.{player_id}",
                "room_id": f"eq.{room_id}",
            },
            headers={
                **_admin_headers(),
                "Prefer": "return=minimal",
            },
            json=fields,
        )

    if response.status_code >= 400:
        raise SupabaseAdminError(
            f"Unable to update player state ({response.status_code})."
        )


async def fetch_room_players(*, room_id: str) -> list[dict]:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f"{_supabase_url()}/rest/v1/players",
            params={
                "room_id": f"eq.{room_id}",
                "select": "id,figurine_name,effects",
            },
            headers=_admin_headers(),
        )

    if response.status_code >= 400:
        raise SupabaseAdminError("Unable to load room players.")

    rows = response.json()
    if not isinstance(rows, list):
        return []
    return [row for row in rows if isinstance(row, dict)]


async def insert_game_event(
    *,
    room_id: str,
    event_type: str,
    content: str,
    player_id: str | None = None,
) -> None:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.post(
            f"{_supabase_url()}/rest/v1/game_events",
            headers={
                "apikey": _service_role_key(),
                "Authorization": f"Bearer {_service_role_key()}",
                "Content-Type": "application/json",
                "Prefer": "return=minimal",
            },
            json={
                "room_id": room_id,
                "player_id": player_id,
                "type": event_type,
                "content": content,
            },
        )

    if response.status_code >= 400:
        raise SupabaseAdminError(
            f"Unable to persist {event_type} event ({response.status_code})."
        )


async def insert_ai_usage_event(
    *,
    user_id: str | None,
    room_id: str | None,
    model: str,
    kind: str,
    input_tokens: int | None,
    output_tokens: int | None,
    latency_ms: int | None,
    cost: float | None,
    cost_source: str,
) -> None:
    payload = {
        "user_id": user_id or None,
        "room_id": room_id or None,
        "model": model,
        "kind": kind,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "latency_ms": latency_ms,
        "cost": cost,
        "cost_source": cost_source,
    }
    async with httpx.AsyncClient(timeout=10) as client:
        response = await client.post(
            f"{_supabase_url()}/rest/v1/ai_usage_events",
            headers={
                "apikey": _service_role_key(),
                "Authorization": f"Bearer {_service_role_key()}",
                "Content-Type": "application/json",
                "Prefer": "return=minimal",
            },
            json=payload,
        )
    if response.status_code >= 400:
        raise SupabaseAdminError(
            f"Unable to persist ai usage ({response.status_code})."
        )


async def create_enemy(
    *,
    room_id: str,
    name: str,
    enemy_type: str,
    position_x: float,
    position_y: float,
    hp: int,
    max_hp: int,
    metadata: dict | None = None,
) -> dict:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.post(
            f"{_supabase_url()}/rest/v1/enemies",
            headers={
                **_admin_headers(),
                "Prefer": "return=representation",
            },
            json={
                "room_id": room_id,
                "name": name,
                "enemy_type": enemy_type,
                "position_x": position_x,
                "position_y": position_y,
                "hp": hp,
                "max_hp": max_hp,
                "status": "active",
                "metadata": metadata or {},
            },
        )

    if response.status_code >= 400:
        raise SupabaseAdminError(
            f"Unable to create enemy ({response.status_code})."
        )

    rows = response.json()
    if isinstance(rows, list) and rows and isinstance(rows[0], dict):
        return rows[0]
    if isinstance(rows, dict):
        return rows
    raise SupabaseAdminError("Enemy create returned an invalid payload.")


async def fetch_room_enemies(*, room_id: str) -> list[dict]:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f"{_supabase_url()}/rest/v1/enemies",
            params={
                "room_id": f"eq.{room_id}",
                "select": (
                    "id,name,enemy_type,position_x,position_y,"
                    "hp,max_hp,status,metadata"
                ),
                "order": "created_at.asc",
            },
            headers=_admin_headers(),
        )

    if response.status_code >= 400:
        raise SupabaseAdminError("Unable to load room enemies.")

    rows = response.json()
    if not isinstance(rows, list):
        return []
    return [row for row in rows if isinstance(row, dict)]


async def fetch_room_enemy(*, room_id: str, enemy_id: str) -> dict | None:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f"{_supabase_url()}/rest/v1/enemies",
            params={
                "id": f"eq.{enemy_id}",
                "room_id": f"eq.{room_id}",
                "select": (
                    "id,name,enemy_type,position_x,position_y,"
                    "hp,max_hp,status"
                ),
            },
            headers=_admin_headers(),
        )

    if response.status_code >= 400:
        raise SupabaseAdminError("Unable to load enemy.")

    rows = response.json()
    if not isinstance(rows, list) or not rows:
        return None
    row = rows[0]
    return row if isinstance(row, dict) else None


async def fetch_room_enemy_by_name(*, room_id: str, name: str) -> dict | None:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f"{_supabase_url()}/rest/v1/enemies",
            params={
                "room_id": f"eq.{room_id}",
                "name": f"eq.{name}",
                "select": (
                    "id,name,enemy_type,position_x,position_y,"
                    "hp,max_hp,status,created_at"
                ),
                "order": "created_at.desc",
                "limit": "5",
            },
            headers=_admin_headers(),
        )

    if response.status_code >= 400:
        raise SupabaseAdminError("Unable to load enemy by name.")

    rows = response.json()
    if not isinstance(rows, list):
        return None
    active = [
        row
        for row in rows
        if isinstance(row, dict) and row.get("status") == "active"
    ]
    if active:
        return active[0]
    first = rows[0] if rows else None
    return first if isinstance(first, dict) else None


async def patch_room_enemy(
    *,
    room_id: str,
    enemy_id: str,
    fields: dict,
) -> None:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.patch(
            f"{_supabase_url()}/rest/v1/enemies",
            params={
                "id": f"eq.{enemy_id}",
                "room_id": f"eq.{room_id}",
            },
            headers={
                **_admin_headers(),
                "Prefer": "return=minimal",
            },
            json=fields,
        )

    if response.status_code >= 400:
        raise SupabaseAdminError(
            f"Unable to update enemy ({response.status_code})."
        )


async def move_enemy(
    *,
    room_id: str,
    enemy_id: str,
    x: float,
    y: float,
) -> None:
    await patch_room_enemy(
        room_id=room_id,
        enemy_id=enemy_id,
        fields={"position_x": x, "position_y": y},
    )


async def damage_enemy(
    *,
    room_id: str,
    enemy_id: str,
    amount: int,
) -> dict | None:
    from state_effects import apply_enemy_damage, as_int, enemy_status_for_hp

    row = await fetch_room_enemy(room_id=room_id, enemy_id=enemy_id)
    if row is None:
        return None
    max_hp = max(1, as_int(row.get("max_hp"), 20))
    hp = as_int(row.get("hp"), 0)
    next_hp = apply_enemy_damage(hp, amount, max_hp)
    status = enemy_status_for_hp(next_hp, str(row.get("status") or "active"))
    await patch_room_enemy(
        room_id=room_id,
        enemy_id=enemy_id,
        fields={"hp": next_hp, "status": status},
    )
    return {
        "id": row.get("id"),
        "name": row.get("name"),
        "hp": hp,
        "next_hp": next_hp,
        "status": status,
    }


async def heal_enemy(
    *,
    room_id: str,
    enemy_id: str,
    amount: int,
) -> dict | None:
    from state_effects import apply_enemy_heal, as_int, enemy_status_for_hp

    row = await fetch_room_enemy(room_id=room_id, enemy_id=enemy_id)
    if row is None:
        return None
    max_hp = max(1, as_int(row.get("max_hp"), 20))
    hp = as_int(row.get("hp"), 0)
    next_hp = apply_enemy_heal(hp, amount, max_hp)
    status = enemy_status_for_hp(next_hp, str(row.get("status") or "active"))
    await patch_room_enemy(
        room_id=room_id,
        enemy_id=enemy_id,
        fields={"hp": next_hp, "status": status},
    )
    return {
        "id": row.get("id"),
        "name": row.get("name"),
        "hp": hp,
        "next_hp": next_hp,
        "status": status,
    }


async def set_enemy_status(
    *,
    room_id: str,
    enemy_id: str,
    status: str,
    hp: int | None = None,
) -> None:
    fields: dict = {"status": status}
    if hp is not None:
        fields["hp"] = hp
    await patch_room_enemy(room_id=room_id, enemy_id=enemy_id, fields=fields)


async def cancel_open_pending_rolls(*, room_id: str, player_id: str) -> None:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.patch(
            f"{_supabase_url()}/rest/v1/pending_rolls",
            params={
                "room_id": f"eq.{room_id}",
                "player_id": f"eq.{player_id}",
                "status": "eq.pending",
            },
            headers={
                **_admin_headers(),
                "Prefer": "return=minimal",
            },
            json={"status": "cancelled"},
        )

    if response.status_code >= 400:
        raise SupabaseAdminError(
            f"Unable to cancel pending rolls ({response.status_code})."
        )


async def create_pending_roll(
    *,
    room_id: str,
    player_id: str,
    ability: str,
    dc: int,
    reason: str,
) -> dict:
    await cancel_open_pending_rolls(room_id=room_id, player_id=player_id)
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.post(
            f"{_supabase_url()}/rest/v1/pending_rolls",
            headers={
                **_admin_headers(),
                "Prefer": "return=representation",
            },
            json={
                "room_id": room_id,
                "player_id": player_id,
                "ability": ability,
                "dc": dc,
                "reason": reason,
                "status": "pending",
            },
        )

    if response.status_code >= 400:
        raise SupabaseAdminError(
            f"Unable to create pending roll ({response.status_code})."
        )

    rows = response.json()
    if isinstance(rows, list) and rows and isinstance(rows[0], dict):
        return rows[0]
    if isinstance(rows, dict):
        return rows
    raise SupabaseAdminError("Pending roll create returned an invalid payload.")


async def fetch_pending_roll(*, pending_roll_id: str) -> dict | None:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f"{_supabase_url()}/rest/v1/pending_rolls",
            params={
                "id": f"eq.{pending_roll_id}",
                "select": (
                    "id,room_id,player_id,ability,dc,reason,status,"
                    "result,modifier,total,success"
                ),
            },
            headers=_admin_headers(),
        )

    if response.status_code >= 400:
        raise SupabaseAdminError("Unable to load pending roll.")

    rows = response.json()
    if not isinstance(rows, list) or not rows:
        return None
    row = rows[0]
    return row if isinstance(row, dict) else None


async def mark_pending_roll_resolved(
    *,
    pending_roll_id: str,
    raw: int,
    modifier: int,
    total: int,
    success: bool,
) -> None:
    from datetime import datetime, timezone

    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.patch(
            f"{_supabase_url()}/rest/v1/pending_rolls",
            params={
                "id": f"eq.{pending_roll_id}",
                "status": "eq.pending",
            },
            headers={
                **_admin_headers(),
                "Prefer": "return=representation",
            },
            json={
                "status": "resolved",
                "result": raw,
                "modifier": modifier,
                "total": total,
                "success": success,
                "resolved_at": datetime.now(timezone.utc).isoformat(),
            },
        )

    if response.status_code >= 400:
        raise SupabaseAdminError(
            f"Unable to resolve pending roll ({response.status_code})."
        )

    rows = response.json()
    if not isinstance(rows, list) or not rows:
        raise SupabaseAdminError("Pending roll was already resolved.")


async def fetch_combat_session(*, room_id: str) -> dict | None:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f"{_supabase_url()}/rest/v1/combat_sessions",
            params={
                "room_id": f"eq.{room_id}",
                "select": "id,room_id,active,round,started_at,ended_at",
                "limit": "1",
            },
            headers=_admin_headers(),
        )

    if response.status_code >= 400:
        raise SupabaseAdminError("Unable to load combat session.")

    rows = response.json()
    if not isinstance(rows, list) or not rows:
        return None
    row = rows[0]
    return row if isinstance(row, dict) else None


async def upsert_combat_session(
    *,
    room_id: str,
    active: bool,
    round: int,
) -> dict:
    from datetime import datetime, timezone

    now = datetime.now(timezone.utc).isoformat()
    existing = await fetch_combat_session(room_id=room_id)
    fields: dict = {
        "active": active,
        "round": round,
    }
    if active:
        if existing is None or not existing.get("active"):
            fields["started_at"] = now
            fields["ended_at"] = None
    else:
        fields["ended_at"] = now

    async with httpx.AsyncClient(timeout=15) as client:
        if existing is None:
            response = await client.post(
                f"{_supabase_url()}/rest/v1/combat_sessions",
                headers={
                    **_admin_headers(),
                    "Prefer": "return=representation",
                },
                json={
                    "room_id": room_id,
                    **fields,
                },
            )
        else:
            response = await client.patch(
                f"{_supabase_url()}/rest/v1/combat_sessions",
                params={"id": f"eq.{existing['id']}"},
                headers={
                    **_admin_headers(),
                    "Prefer": "return=representation",
                },
                json=fields,
            )

    if response.status_code >= 400:
        raise SupabaseAdminError(
            f"Unable to upsert combat session ({response.status_code})."
        )

    rows = response.json()
    if isinstance(rows, list) and rows and isinstance(rows[0], dict):
        return rows[0]
    if isinstance(rows, dict):
        return rows
    raise SupabaseAdminError("Combat session upsert returned an invalid payload.")


async def assert_room_host(*, user_id: str, room_id: str) -> dict:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f"{_supabase_url()}/rest/v1/rooms",
            params={
                "id": f"eq.{room_id}",
                "select": "id,host_id,scenario_id,scenario,scenario_prompt,world_state,locale",
                "limit": "1",
            },
            headers=_admin_headers(),
        )

    if response.status_code >= 400:
        raise SupabaseAdminError("Unable to verify room host.")

    rows = response.json()
    if not isinstance(rows, list) or not rows or not isinstance(rows[0], dict):
        raise SupabaseAdminError("Room not found.")
    row = rows[0]
    if str(row.get("host_id") or "") != user_id:
        raise SupabaseAdminError("Only the room host can generate a scenario.")
    return row


async def fetch_room_narrative_context(*, room_id: str) -> dict:
    from gm_locale import normalize_locale
    from scenario_state import public_world_state

    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f"{_supabase_url()}/rest/v1/rooms",
            params={
                "id": f"eq.{room_id}",
                "select": "world_state,scenario_prompt,scenario_id,scenario,locale,status,host_id,music_mood",
                "limit": "1",
            },
            headers=_admin_headers(),
        )

    if response.status_code >= 400:
        raise SupabaseAdminError("Unable to load room scenario.")

    rows = response.json()
    if not isinstance(rows, list) or not rows or not isinstance(rows[0], dict):
        return {
            "world_state": {},
            "locale": "en",
            "status": "waiting",
            "music_mood": "exploration",
        }
    row = rows[0]
    return {
        "world_state": public_world_state(row.get("world_state")),
        "locale": normalize_locale(row.get("locale")),
        "status": str(row.get("status") or "waiting"),
        "scenario_id": str(row.get("scenario_id") or ""),
        "host_id": str(row.get("host_id") or ""),
        "music_mood": str(row.get("music_mood") or "exploration"),
    }


async def fetch_room_world_state(*, room_id: str) -> dict:
    context = await fetch_room_narrative_context(room_id=room_id)
    return dict(context.get("world_state") or {})


async def fetch_room_gm_row(*, room_id: str) -> dict:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f"{_supabase_url()}/rest/v1/room_gm_state",
            params={
                "room_id": f"eq.{room_id}",
                "select": "gm_secrets,gm_state",
                "limit": "1",
            },
            headers=_admin_headers(),
        )

    if response.status_code >= 400:
        raise SupabaseAdminError("Unable to load GM state.")

    rows = response.json()
    if not isinstance(rows, list) or not rows or not isinstance(rows[0], dict):
        return {"gm_secrets": [], "gm_state": {}}
    row = rows[0]
    secrets = row.get("gm_secrets")
    if not isinstance(secrets, list):
        secrets = []
    gm_state = row.get("gm_state")
    if not isinstance(gm_state, dict):
        gm_state = {}
    return {
        "gm_secrets": [
            str(item).strip()[:240] for item in secrets if str(item).strip()
        ][:12],
        "gm_state": gm_state,
    }


async def fetch_room_gm_secrets(*, room_id: str) -> list[str]:
    row = await fetch_room_gm_row(room_id=room_id)
    return list(row.get("gm_secrets") or [])


async def count_room_events(*, room_id: str) -> int:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f"{_supabase_url()}/rest/v1/game_events",
            params={
                "room_id": f"eq.{room_id}",
                "select": "id",
            },
            headers={
                **_admin_headers(),
                "Prefer": "count=exact",
                "Range": "0-0",
            },
        )

    if response.status_code >= 400:
        raise SupabaseAdminError("Unable to count game events.")

    header = (
        response.headers.get("content-range")
        or response.headers.get("Content-Range")
        or ""
    )
    if "/" in header:
        total = header.rsplit("/", 1)[-1]
        if total.isdigit():
            return int(total)
    rows = response.json()
    if isinstance(rows, list):
        return len(rows)
    return 0


async def fetch_recent_room_events(*, room_id: str, limit: int) -> list[dict]:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f"{_supabase_url()}/rest/v1/game_events",
            params={
                "room_id": f"eq.{room_id}",
                "select": "type,content,created_at,id",
                "order": "created_at.desc,id.desc",
                "limit": str(max(1, limit)),
            },
            headers=_admin_headers(),
        )

    if response.status_code >= 400:
        raise SupabaseAdminError("Unable to load recent game events.")

    rows = response.json()
    if not isinstance(rows, list):
        return []
    chronological = list(reversed(rows))
    return [row for row in chronological if isinstance(row, dict)]


async def fetch_room_events_slice(
    *,
    room_id: str,
    offset: int,
    limit: int,
) -> list[dict]:
    if limit <= 0:
        return []
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f"{_supabase_url()}/rest/v1/game_events",
            params={
                "room_id": f"eq.{room_id}",
                "select": "type,content,created_at,id",
                "order": "created_at.asc,id.asc",
                "offset": str(max(0, offset)),
                "limit": str(limit),
            },
            headers=_admin_headers(),
        )

    if response.status_code >= 400:
        raise SupabaseAdminError("Unable to load game events for summary.")

    rows = response.json()
    if not isinstance(rows, list):
        return []
    return [row for row in rows if isinstance(row, dict)]


async def patch_room_music_mood(*, room_id: str, music_mood: str) -> None:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.patch(
            f"{_supabase_url()}/rest/v1/rooms",
            params={"id": f"eq.{room_id}"},
            headers={
                **_admin_headers(),
                "Prefer": "return=minimal",
            },
            json={"music_mood": music_mood},
        )

    if response.status_code >= 400:
        raise SupabaseAdminError(
            f"Unable to save music mood ({response.status_code})."
        )


async def patch_room_world_state(
    *,
    room_id: str,
    world_state: dict,
    scenario_title: str,
    scenario_prompt: str,
) -> None:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.patch(
            f"{_supabase_url()}/rest/v1/rooms",
            params={"id": f"eq.{room_id}"},
            headers={
                **_admin_headers(),
                "Prefer": "return=minimal",
            },
            json={
                "world_state": world_state,
                "scenario": scenario_title,
                "scenario_prompt": scenario_prompt,
            },
        )

    if response.status_code >= 400:
        raise SupabaseAdminError(
            f"Unable to save world state ({response.status_code})."
        )


async def upsert_room_gm_state(
    *,
    room_id: str,
    gm_secrets: list[str] | None = None,
    gm_state: dict | None = None,
) -> None:
    payload: dict = {"room_id": room_id}
    if gm_secrets is not None:
        payload["gm_secrets"] = gm_secrets
    if gm_state is not None:
        payload["gm_state"] = gm_state
    if len(payload) == 1:
        return
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.post(
            f"{_supabase_url()}/rest/v1/room_gm_state",
            params={"on_conflict": "room_id"},
            headers={
                **_admin_headers(),
                "Prefer": "resolution=merge-duplicates,return=minimal",
            },
            json=payload,
        )

    if response.status_code >= 400:
        raise SupabaseAdminError(
            f"Unable to save GM state ({response.status_code})."
        )


async def finish_room(*, room_id: str, ending: dict, status: str = "finished") -> bool:
    from datetime import datetime, timezone

    next_status = status if status in {"finished", "demo_finished"} else "finished"
    finished_at = datetime.now(timezone.utc).isoformat()
    payload = {
        "status": next_status,
        "finished_at": finished_at,
        "ending": {
            "result": ending.get("result") or "neutral",
            "summary": ending.get("summary") or "",
            "epilogue": ending.get("epilogue") or "",
        },
    }
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.patch(
            f"{_supabase_url()}/rest/v1/rooms",
            params={
                "id": f"eq.{room_id}",
                "status": "in.(playing,paused)",
            },
            headers={
                **_admin_headers(),
                "Prefer": "return=representation",
            },
            json=payload,
        )

    if response.status_code >= 400:
        raise SupabaseAdminError(
            f"Unable to finish room ({response.status_code})."
        )

    rows = response.json()
    if isinstance(rows, list):
        return bool(rows)
    if isinstance(rows, dict) and rows:
        return True
    return False


def _parse_timestamptz(value: object):
    from datetime import datetime, timezone

    if not isinstance(value, str) or not value.strip():
        return None
    raw = value.strip().replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(raw)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


async def fetch_user_entitlement(*, user_id: str) -> dict:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f"{_supabase_url()}/rest/v1/user_entitlements",
            params={
                "user_id": f"eq.{user_id}",
                "select": "user_id,access_level,source,expires_at,metadata",
                "limit": "1",
            },
            headers=_admin_headers(),
        )
    if response.status_code >= 400:
        raise SupabaseAdminError("Unable to load entitlement.")
    rows = response.json()
    if isinstance(rows, list) and rows and isinstance(rows[0], dict):
        return rows[0]
    return {"user_id": user_id, "access_level": "demo", "source": "default"}


async def fetch_demo_session(*, user_id: str) -> dict | None:
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.get(
            f"{_supabase_url()}/rest/v1/demo_sessions",
            params={
                "user_id": f"eq.{user_id}",
                "select": "id,user_id,room_id,started_at,expires_at,completed_at,paused_at",
                "limit": "1",
            },
            headers=_admin_headers(),
        )
        if response.status_code >= 400:
            response = await client.get(
                f"{_supabase_url()}/rest/v1/demo_sessions",
                params={
                    "user_id": f"eq.{user_id}",
                    "select": "id,user_id,room_id,started_at,expires_at,completed_at",
                    "limit": "1",
                },
                headers=_admin_headers(),
            )
    if response.status_code >= 400:
        raise SupabaseAdminError("Unable to load demo session.")
    rows = response.json()
    if isinstance(rows, list) and rows and isinstance(rows[0], dict):
        return rows[0]
    return None


async def start_demo_clock(*, user_id: str, room_id: str, started_at, expires_at) -> None:
    payload = {
        "started_at": started_at.isoformat(),
        "expires_at": expires_at.isoformat(),
        "room_id": room_id,
    }
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.patch(
            f"{_supabase_url()}/rest/v1/demo_sessions",
            params={"user_id": f"eq.{user_id}"},
            headers={
                **_admin_headers(),
                "Prefer": "return=representation",
            },
            json=payload,
        )
        rows = response.json() if response.status_code < 400 else []
        if isinstance(rows, list) and rows:
            return
        if isinstance(rows, dict) and rows:
            return
        insert = await client.post(
            f"{_supabase_url()}/rest/v1/demo_sessions",
            headers={
                **_admin_headers(),
                "Prefer": "return=minimal",
            },
            json={"user_id": user_id, **payload},
        )
        if insert.status_code >= 400:
            raise SupabaseAdminError(
                f"Unable to start demo clock ({insert.status_code})."
            )


async def sync_demo_play(*, user_id: str, room_id: str) -> str:
    from datetime import datetime, timezone

    from demo_access import evaluate_demo_play, next_demo_clock

    entitlement = await fetch_user_entitlement(user_id=user_id)
    context = await fetch_room_narrative_context(room_id=room_id)
    session = await fetch_demo_session(user_id=user_id)
    now = datetime.now(timezone.utc)
    started_at = _parse_timestamptz((session or {}).get("started_at"))
    expires_at = _parse_timestamptz((session or {}).get("expires_at"))
    completed_at = _parse_timestamptz((session or {}).get("completed_at"))
    paused_at = _parse_timestamptz((session or {}).get("paused_at"))
    status = evaluate_demo_play(
        access_level=entitlement.get("access_level"),
        room_status=context.get("status"),
        room_scenario_id=context.get("scenario_id"),
        room_host_id=context.get("host_id"),
        user_id=user_id,
        started_at=started_at,
        expires_at=expires_at,
        completed_at=completed_at,
        now=now,
        paused_at=paused_at,
    )
    if status != "ok":
        return status
    if str(entitlement.get("access_level") or "demo").lower() == "full":
        return "ok"
    start, end, clock = next_demo_clock(
        now=now,
        started_at=started_at,
        expires_at=expires_at,
        completed_at=completed_at,
        paused_at=paused_at,
    )
    if clock == "ok" and started_at is None:
        if str(context.get("status") or "").strip().lower() == "paused":
            return "ok"
        await start_demo_clock(
            user_id=user_id,
            room_id=room_id,
            started_at=start,
            expires_at=end,
        )
    return clock


async def grant_full_entitlement(
    *,
    user_id: str,
    source: str,
    metadata: dict | None = None,
) -> dict:
    from purchases import already_has_full_access, normalize_purchase_source

    current = await fetch_user_entitlement(user_id=user_id)
    if already_has_full_access(current):
        return current
    extra = metadata if isinstance(metadata, dict) else {}
    previous = current.get("metadata")
    merged = dict(previous) if isinstance(previous, dict) else {}
    merged.update({key: str(value)[:240] for key, value in extra.items()})
    payload = {
        "user_id": user_id,
        "access_level": "full",
        "source": normalize_purchase_source(source),
        "metadata": merged,
    }
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.patch(
            f"{_supabase_url()}/rest/v1/user_entitlements",
            params={"user_id": f"eq.{user_id}"},
            headers={
                **_admin_headers(),
                "Prefer": "return=representation",
            },
            json={
                "access_level": payload["access_level"],
                "source": payload["source"],
                "metadata": payload["metadata"],
            },
        )
        rows = response.json() if response.status_code < 400 else []
        if isinstance(rows, list) and rows and isinstance(rows[0], dict):
            return rows[0]
        insert = await client.post(
            f"{_supabase_url()}/rest/v1/user_entitlements",
            headers={
                **_admin_headers(),
                "Prefer": "return=representation",
            },
            json=payload,
        )
        if insert.status_code >= 400:
            raise SupabaseAdminError(
                f"Unable to grant entitlement ({insert.status_code})."
            )
        created = insert.json()
        if isinstance(created, list) and created and isinstance(created[0], dict):
            return created[0]
        if isinstance(created, dict):
            return created
    return payload



