import json
import logging
import os

from fastapi import FastAPI, Header, HTTPException, Request
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
from demo_access import canned_demo_ending, ensure_finish_action, normalize_access_level
from gm_locale import normalize_locale
from purchases import (
    PurchaseConfigError,
    PurchaseSignatureError,
    create_stripe_checkout_url,
    fetch_stripe_offer,
    grant_metadata,
    is_checkout_configured,
    is_webhook_configured,
    parse_checkout_user_id,
    session_id_from_event,
    stripe_webhook_secret,
    verify_stripe_signature,
)
from models import (
    CombatContext,
    GameMasterRequest,
    GameMasterResponse,
    GenerateScenarioRequest,
    PublicScenarioResponse,
    ResolveRollRequest,
    RollResult,
)
from music_mood import normalize_narrative_music_mood
from openrouter_client import GameMasterBackendError, request_game_master_response
from rate_limit import (
    DEMO_EXPIRED,
    NOT_ENTITLED,
    RATE_LIMITED,
    RateLimitedError,
    enforce_ai_rate_limit,
)
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
    fetch_user_entitlement,
    get_user_id_from_access_token,
    grant_full_entitlement,
    insert_game_event,
    mark_pending_roll_resolved,
    patch_room_world_state,
    sync_demo_play,
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


def _enforce_ai_rate_limit(user_id: str) -> None:
    try:
        enforce_ai_rate_limit(user_id)
    except RateLimitedError as error:
        logger.warning("RATE_LIMITED user_id=%s", user_id)
        raise HTTPException(status_code=429, detail=RATE_LIMITED) from error


@app.post("/v1/game-master/respond", response_model=GameMasterResponse)
async def respond(
    request: GameMasterRequest,
    authorization: str | None = Header(default=None),
) -> GameMasterResponse:
    try:
        user_id = await get_user_id_from_access_token(_bearer_token(authorization))
        _enforce_ai_rate_limit(user_id)
        await assert_player_belongs_to_user(
            user_id=user_id,
            player_id=request.player_id,
            room_id=request.room_id,
        )
        gm_request = await _with_authoritative_combat(
            request, drop_roll_result=True
        )
        gm_request = await _apply_demo_gate(user_id=user_id, request=gm_request)
        response = await _run_gm_turn(gm_request, user_id=user_id)
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
        _enforce_ai_rate_limit(user_id)
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
        gm_request = await _apply_demo_gate(user_id=user_id, request=gm_request)
        response = await _run_gm_turn(gm_request, user_id=user_id)
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
    if str(narrative.get("status") or "") == "demo_finished":
        raise RoomFinishedError(DEMO_EXPIRED)
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
        "music_mood": normalize_narrative_music_mood(narrative.get("music_mood")),
    }
    if drop_roll_result:
        updates["roll_result"] = None
    updates["demo_end_required"] = False
    return request.model_copy(update=updates)


async def _apply_demo_gate(
    *,
    user_id: str,
    request: GameMasterRequest,
) -> GameMasterRequest:
    status = await sync_demo_play(user_id=user_id, room_id=request.room_id)
    if status == "closed":
        raise RoomFinishedError(DEMO_EXPIRED)
    if status == "forbidden":
        raise HTTPException(status_code=403, detail=NOT_ENTITLED)
    if status == "expired":
        return request.model_copy(update={"demo_end_required": True})
    return request.model_copy(update={"demo_end_required": False})


async def _run_gm_turn(
    request: GameMasterRequest,
    *,
    user_id: str,
) -> GameMasterResponse:
    if request.demo_end_required:
        try:
            raw = await request_game_master_response(request, user_id=user_id)
            payload = ensure_finish_action(raw.model_dump(), request.locale)
            response = GameMasterResponse.model_validate(payload)
        except GameMasterBackendError:
            response = GameMasterResponse.model_validate(
                canned_demo_ending(request.locale)
            )
        await _persist_gm_response(room_id=request.room_id, response=response)
        return response
    response = await request_game_master_response(request, user_id=user_id)
    await _persist_gm_response(room_id=request.room_id, response=response)
    return response


@app.post("/v1/scenarios/generate", response_model=PublicScenarioResponse)
async def generate_scenario(
    request: GenerateScenarioRequest,
    authorization: str | None = Header(default=None),
) -> PublicScenarioResponse:
    try:
        user_id = await get_user_id_from_access_token(_bearer_token(authorization))
        entitlement = await fetch_user_entitlement(user_id=user_id)
        if normalize_access_level(entitlement.get("access_level")) != "full":
            raise HTTPException(status_code=403, detail=NOT_ENTITLED)
        _enforce_ai_rate_limit(user_id)
        room = await assert_room_host(user_id=user_id, room_id=request.room_id)
        if str(room.get("scenario_id") or "") != "custom":
            raise HTTPException(
                status_code=400,
                detail="Scenario generation is only allowed for custom rooms.",
            )
        generated = await request_generated_scenario(
            request.model_copy(
                update={"locale": normalize_locale(room.get("locale"))},
            ),
            user_id=user_id,
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


def _public_entitlement(row: dict) -> dict[str, str]:
    return {
        "access_level": normalize_access_level(row.get("access_level")),
        "source": str(row.get("source") or "default"),
    }


@app.get("/v1/purchases/offer")
async def purchase_offer() -> dict:
    try:
        if not is_checkout_configured():
            raise HTTPException(status_code=503, detail="PURCHASE_UNAVAILABLE")
        return await fetch_stripe_offer()
    except PurchaseConfigError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error


@app.get("/v1/purchases/me")
async def purchase_me(
    authorization: str | None = Header(default=None),
) -> dict:
    try:
        user_id = await get_user_id_from_access_token(_bearer_token(authorization))
        row = await fetch_user_entitlement(user_id=user_id)
        return _public_entitlement(row)
    except HTTPException:
        raise
    except SupabaseAdminError as error:
        raise HTTPException(status_code=403, detail=str(error)) from error


@app.post("/v1/purchases/checkout")
async def purchase_checkout(
    authorization: str | None = Header(default=None),
) -> dict:
    try:
        user_id = await get_user_id_from_access_token(_bearer_token(authorization))
        url = await create_stripe_checkout_url(user_id=user_id)
        return {"checkout_url": url}
    except HTTPException:
        raise
    except PurchaseConfigError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error
    except SupabaseAdminError as error:
        raise HTTPException(status_code=403, detail=str(error)) from error


@app.post("/v1/purchases/stripe-webhook")
async def purchase_stripe_webhook(
    request: Request,
    stripe_signature: str | None = Header(default=None, alias="Stripe-Signature"),
) -> dict[str, str]:
    if not is_webhook_configured():
        raise HTTPException(status_code=503, detail="PURCHASE_UNAVAILABLE")
    payload = await request.body()
    try:
        verify_stripe_signature(
            payload=payload,
            header=stripe_signature or "",
            secret=stripe_webhook_secret(),
        )
        event = json.loads(payload.decode("utf-8"))
    except PurchaseSignatureError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise HTTPException(
            status_code=400, detail="Invalid webhook payload."
        ) from error
    if not isinstance(event, dict):
        raise HTTPException(status_code=400, detail="Invalid webhook payload.")
    user_id = parse_checkout_user_id(event)
    if user_id is None:
        return {"status": "ignored"}
    try:
        await grant_full_entitlement(
            user_id=user_id,
            source="purchase",
            metadata=grant_metadata(session_id=session_id_from_event(event)),
        )
    except SupabaseAdminError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    return {"status": "ok"}
