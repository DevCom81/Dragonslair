import os

import httpx


class SupabaseAdminError(RuntimeError):
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
                "select": "id,hp,inventory,figurine_name,effects",
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
