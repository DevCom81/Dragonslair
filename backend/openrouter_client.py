import json
import os

import httpx
from pydantic import ValidationError

from models import GameMasterRequest, GameMasterResponse


OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
DEFAULT_MODEL = "google/gemini-3.1-flash-lite"
REQUEST_TIMEOUT_SECONDS = 30


class GameMasterBackendError(RuntimeError):
    pass


def _build_system_prompt() -> str:
    return """
Tu es le maitre du jeu IA d'un jeu de role medieval-fantasy multijoueur.
Tu ne produis jamais de markdown, jamais de texte hors JSON.
Tu dois retourner uniquement un objet JSON valide compatible avec ce contrat:
{
  "narration": "texte narratif immersif en francais",
  "actions": [
    {"type": "system_message", "payload": {"message": "texte court"}}
  ],
  "choices": [
    {"label": "Choix lisible", "action": "intention optionnelle"}
  ]
}

Types d'actions autorises:
narrate, spawn_enemy, move_enemy, damage_player, heal_player, give_item,
remove_item, start_combat, end_combat, system_message.

Contraintes:
- garde une narration courte et jouable;
- ne demande jamais de secret;
- n'invente pas de regle complexe inutile;
- si une action structuree n'est pas certaine, utilise system_message.
""".strip()


def _build_user_prompt(request: GameMasterRequest) -> str:
    return json.dumps(
        {
            "room_id": request.room_id,
            "player_id": request.player_id,
            "player_name": request.player_name,
            "action": request.action,
            "players": [player.model_dump() for player in request.players],
            "recent_events": [
                event.model_dump() for event in request.recent_events
            ],
        },
        ensure_ascii=False,
    )


async def request_game_master_response(
    request: GameMasterRequest,
) -> GameMasterResponse:
    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        raise GameMasterBackendError("OPENROUTER_API_KEY is not configured.")

    model = os.getenv("OPENROUTER_MODEL", DEFAULT_MODEL)

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": _build_system_prompt()},
            {"role": "user", "content": _build_user_prompt(request)},
        ],
        "temperature": 0.7,
        "max_tokens": 900,
        "response_format": {"type": "json_object"},
    }

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "X-Title": "DragonsLair Game Master",
    }

    async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT_SECONDS) as client:
        response = await client.post(
            OPENROUTER_URL,
            json=payload,
            headers=headers,
        )

    if response.status_code >= 400:
        raise GameMasterBackendError(
            f"OpenRouter request failed with status {response.status_code}."
        )

    data = response.json()
    try:
        content = data["choices"][0]["message"]["content"]
        decoded = json.loads(content)
        return GameMasterResponse.model_validate(decoded)
    except (
        KeyError,
        IndexError,
        TypeError,
        json.JSONDecodeError,
        ValidationError,
    ) as error:
        raise GameMasterBackendError(
            "OpenRouter returned an invalid game master payload."
        ) from error
