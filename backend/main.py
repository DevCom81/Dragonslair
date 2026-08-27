import os

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from apply_actions import apply_game_master_actions
from models import GameMasterRequest, GameMasterResponse
from openrouter_client import GameMasterBackendError, request_game_master_response
from supabase_admin import (
    SupabaseAdminError,
    assert_player_belongs_to_user,
    get_user_id_from_access_token,
    insert_game_event,
)


def _allowed_origins() -> list[str]:
    value = os.getenv("ALLOWED_ORIGINS", "")
    origins = [origin.strip() for origin in value.split(",") if origin.strip()]
    return origins or ["*"]


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
        response = await request_game_master_response(request)
        await insert_game_event(
            room_id=request.room_id,
            event_type="narration",
            content=response.narration,
        )
        effect_summaries = await apply_game_master_actions(
            room_id=request.room_id,
            actions=response.actions,
        )
        if effect_summaries:
            await insert_game_event(
                room_id=request.room_id,
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
                room_id=request.room_id,
                event_type="system",
                content="Actions MJ: " + "; ".join(summaries),
            )
        return response
    except HTTPException:
        raise
    except SupabaseAdminError as error:
        raise HTTPException(status_code=403, detail=str(error)) from error
    except GameMasterBackendError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
