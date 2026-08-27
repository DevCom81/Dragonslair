import logging
import os

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from apply_actions import apply_game_master_actions
from campaign_memory import (
    RECENT_EVENT_LIMIT,
    apply_memory_to_gm_state,
    cap_recent_events,
    next_memory,
    parse_memory,
    recent_events_from_rows,
    should_summarize,
    summary_window,
)
from gm_locale import normalize_locale
from models import (
    CombatContext,
    GameMasterRequest,
    GameMasterResponse,
    GenerateScenarioRequest,
    PublicScenarioResponse,
    ResolveRollRequest,
    RollResult,
)
from openrouter_client import GameMasterBackendError, request_game_master_response
from scenario_generator import request_generated_scenario
from scenario_state import public_world_state
from state_effects import (
    can_resolve_pending_roll,
    combat_context_from_row,
    effective_modifier_from_row,
    resolve_roll_total,
)
from supabase_admin import (
    RoomFinishedError,
    SupabaseAdminError,
    assert_player_belongs_to_user,
    assert_room_host,
    count_room_events,
    fetch_combat_session,
    fetch_pending_roll,
    fetch_recent_room_events,
    fetch_room_events_slice,
    fetch_room_gm_row,
    fetch_room_narrative_context,
    fetch_room_player,
    get_user_id_from_access_token,
    insert_game_event,
    mark_pending_roll_resolved,
    patch_room_world_state,
    upsert_room_gm_state,
)


def _allowed_origins() -> list[str]:
    # Browser CORS only. Native Android is not affected.
    # Comma-separated ALLOWED_ORIGINS, for example:
    # https://PROJECT.web.app,https://play.example.com,http://localhost:5000
    # Empty env falls back to * for local development. Do not keep * in
    # production if cookies/credentials are introduced later.
    value = os.getenv("ALLOWED_ORIGINS", "")
    origins = [origin.strip() for origin in value.split(",") if origin.strip()]
    return origins or ["*"]


logger = logging.getLogger("dragons_lair")

app = FastAPI(title="DragonsLair Game Master API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins(),
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


def _bearer_token(authorization: str | None) -> str:
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing Authorization header.")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise HTTPException(status_code=401, detail="Invalid Authorization header.")
    return token.strip()


@app.post("/v1/game-master/respond", response_model=GameMasterResponse)
async def respond(
    request: GameMasterRequest,
    authorization: str | None = Header(default=None),
) -> GameMasterResponse:
    try:
        user_id = await get_user_id_from_access_token(_bearer_token(authorization))
        await assert_player_belongs_to_user(
            user_id=user_id,
            player_id=request.player_id,
            room_id=request.room_id,
        )
        gm_request = await _with_authoritative_combat(
            request, drop_roll_result=True
        )
        response = await request_game_master_response(gm_request)
        await _persist_gm_response(room_id=request.room_id, response=response)
        return response
    except HTTPException:
        raise
    except RoomFinishedError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    except SupabaseAdminError as error:
        raise HTTPException(status_code=403, detail=str(error)) from error
    except GameMasterBackendError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error


async def _persist_gm_response(*, room_id: str, response: GameMasterResponse) -> None:
    await insert_game_event(
        room_id=room_id,
        event_type="narration",
        content=response.narration,
    )
    effect_summaries = await apply_game_master_actions(
        room_id=room_id,
        actions=response.actions,
    )
    if effect_summaries:
        await insert_game_event(
            room_id=room_id,
            event_type="system",
            content=" ; ".join(effect_summaries),
        )
    elif response.actions:
        summaries = [
            action.type
            if not action.payload
            else f"{action.type}: {action.payload}"
            for action in response.actions
        ]
        await insert_game_event(
            room_id=room_id,
            event_type="system",
            content="Actions MJ: " + "; ".join(summaries),
        )
    await _refresh_campaign_summary(room_id=room_id)


@app.post("/v1/game-master/resolve-roll", response_model=GameMasterResponse)
async def resolve_roll(
    request: ResolveRollRequest,
    authorization: str | None = Header(default=None),
) -> GameMasterResponse:
    try:
        user_id = await get_user_id_from_access_token(_bearer_token(authorization))
        roll = await fetch_pending_roll(pending_roll_id=request.pending_roll_id)
        if roll is None:
            raise HTTPException(status_code=404, detail="Pending roll not found.")
        room_id = str(roll["room_id"])
        player_id = str(roll["player_id"])
        await assert_player_belongs_to_user(
            user_id=user_id,
            player_id=player_id,
            room_id=room_id,
        )
        if not can_resolve_pending_roll(
            status=str(roll.get("status") or ""),
            roll_player_id=player_id,
            actor_player_id=player_id,
        ):
            raise HTTPException(
                status_code=409,
                detail="This roll is not pending or cannot be resolved.",
            )

        player = await fetch_room_player(room_id=room_id, player_id=player_id)
        if player is None:
            raise HTTPException(status_code=404, detail="Player not found.")

        ability = str(roll["ability"])
        dc = int(roll["dc"])
        modifier = effective_modifier_from_row(player, ability)
        resolved = resolve_roll_total(raw=request.raw, modifier=modifier, dc=dc)
        await mark_pending_roll_resolved(
            pending_roll_id=request.pending_roll_id,
            raw=resolved["raw"],
            modifier=resolved["modifier"],
            total=resolved["total"],
            success=resolved["success"],
        )

        name = str(player.get("figurine_name") or request.player_name)
        outcome = "succes" if resolved["success"] else "echec"
        sign = (
            f"+{resolved['modifier']}"
            if resolved["modifier"] >= 0
            else str(resolved["modifier"])
        )
        content = (
            f"{name} : 1d20={resolved['raw']} {sign} = {resolved['total']} "
            f"vs DD {dc}. {outcome}."
        )
        await insert_game_event(
            room_id=room_id,
            event_type="action",
            content=content,
            player_id=player_id,
        )

        gm_request = await _with_authoritative_combat(
            GameMasterRequest(
                room_id=room_id,
                player_id=player_id,
                player_name=name,
                action=content,
                players=request.players,
                enemies=request.enemies,
                recent_events=request.recent_events,
                roll_result=RollResult(
                    pending_roll_id=request.pending_roll_id,
                    player_id=player_id,
                    ability=ability,
                    dc=dc,
                    raw=resolved["raw"],
                    modifier=resolved["modifier"],
                    total=resolved["total"],
                    success=resolved["success"],
                    reason=str(roll.get("reason") or ""),
                ),
            )
        )
        response = await request_game_master_response(gm_request)
        await _persist_gm_response(room_id=room_id, response=response)
        return response
    except HTTPException:
        raise
    except RoomFinishedError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    except SupabaseAdminError as error:
        raise HTTPException(status_code=403, detail=str(error)) from error
    except GameMasterBackendError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error


async def _refresh_campaign_summary(*, room_id: str) -> None:
    try:
        event_count = await count_room_events(room_id=room_id)
        row = await fetch_room_gm_row(room_id=room_id)
        memory = parse_memory(row.get("gm_state"))
        if not should_summarize(
            event_count=event_count,
            summarized_event_count=int(memory["summarized_event_count"]),
        ):
            return
        offset, limit = summary_window(
            event_count=event_count,
            summarized_event_count=int(memory["summarized_event_count"]),
        )
        folded = await fetch_room_events_slice(
            room_id=room_id,
            offset=offset,
            limit=limit,
        )
        updated = next_memory(
            previous=memory,
            folded_events=folded,
            event_count=event_count,
        )
        await upsert_room_gm_state(
            room_id=room_id,
            gm_state=apply_memory_to_gm_state(row.get("gm_state"), updated),
        )
    except Exception as error:
        logger.warning("campaign summary refresh failed: %s", error)


async def _with_authoritative_combat(
    request: GameMasterRequest,
    *,
    drop_roll_result: bool = False,
) -> GameMasterRequest:
    row = await fetch_combat_session(room_id=request.room_id)
    narrative = await fetch_room_narrative_context(room_id=request.room_id)
    if str(narrative.get("status") or "") == "finished":
        raise RoomFinishedError("This game is finished.")
    world_state = dict(narrative.get("world_state") or {})
    locale = normalize_locale(narrative.get("locale"))
    try:
        gm_row = await fetch_room_gm_row(room_id=request.room_id)
    except SupabaseAdminError:
        gm_row = {"gm_secrets": [], "gm_state": {}}
    memory = parse_memory(gm_row.get("gm_state"))
    try:
        recent_rows = await fetch_recent_room_events(
            room_id=request.room_id,
            limit=RECENT_EVENT_LIMIT,
        )
        recent_events = recent_events_from_rows(recent_rows)
    except SupabaseAdminError:
        recent_events = cap_recent_events(list(request.recent_events))
    updates: dict = {
        "combat": CombatContext.model_validate(combat_context_from_row(row)),
        "world_state": world_state,
        "gm_secrets": list(gm_row.get("gm_secrets") or []),
        "campaign_summary": str(memory.get("campaign_summary") or ""),
        "recent_events": recent_events,
        "locale": locale,
    }
    if drop_roll_result:
        updates["roll_result"] = None
    return request.model_copy(update=updates)


@app.post("/v1/scenarios/generate", response_model=PublicScenarioResponse)
async def generate_scenario(
    request: GenerateScenarioRequest,
    authorization: str | None = Header(default=None),
) -> PublicScenarioResponse:
    try:
        user_id = await get_user_id_from_access_token(_bearer_token(authorization))
        room = await assert_room_host(user_id=user_id, room_id=request.room_id)
        if str(room.get("scenario_id") or "") != "custom":
            raise HTTPException(
                status_code=400,
                detail="Scenario generation is only allowed for custom rooms.",
            )
        generated = await request_generated_scenario(
            request.model_copy(
                update={"locale": normalize_locale(room.get("locale"))},
            )
        )
        world_state = public_world_state(generated.public_dict())
        secrets = [
            secret.strip()[:240]
            for secret in generated.gm_secrets
            if secret.strip()
        ][:12]
        title = generated.title.strip() or request.title.strip() or "Aventure"
        await patch_room_world_state(
            room_id=request.room_id,
            world_state=world_state,
            scenario_title=title,
            scenario_prompt=request.prompt.strip(),
        )
        await upsert_room_gm_state(
            room_id=request.room_id,
            gm_secrets=secrets,
        )
        opening = generated.opening_narration.strip()
        if opening:
            await insert_game_event(
                room_id=request.room_id,
                event_type="narration",
                content=opening,
            )
        return PublicScenarioResponse(
            world_state=world_state,
            opening_narration=opening,
        )
    except HTTPException:
        raise
    except SupabaseAdminError as error:
        raise HTTPException(status_code=403, detail=str(error)) from error
    except GameMasterBackendError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
