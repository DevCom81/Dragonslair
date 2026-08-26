import os

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from models import GameMasterRequest, GameMasterResponse
from openrouter_client import GameMasterBackendError, request_game_master_response


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


@app.post("/v1/game-master/respond", response_model=GameMasterResponse)
async def respond(request: GameMasterRequest) -> GameMasterResponse:
    try:
        return await request_game_master_response(request)
    except GameMasterBackendError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
