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
remove_item, start_combat, end_combat, system_message, request_roll,
apply_effect, remove_effect.

Payloads:
- damage_player / heal_player: {"player_id": "<id>", "amount": 4}
- give_item: {"player_id": "<id>", "item": {"id": "sword", "name": "Epee", "quantity": 1, "type": "weapon|armor|shield|accessory|potion|scroll|tool", "bonuses": {"strength": 1}, "heal": 20, "effect": {"id": "bless", "name": "Benediction", "kind": "buff", "stat": "wisdom", "delta": 2, "remaining": 3}}}
- remove_item: {"player_id": "<id>", "item_id": "torch"}
- request_roll: {"player_id": "<id>", "ability": "strength|dexterity|constitution|intelligence|wisdom|charisma", "dc": 12, "reason": "escalader"}
- apply_effect: {"player_id": "<id>", "effect": {"id": "poison", "name": "Poison", "kind": "debuff", "stat": "constitution", "delta": -2, "remaining": 2}}
- remove_effect: {"player_id": "<id>", "effect_id": "poison"}

Contraintes:
- garde une narration courte et jouable;
- ne demande jamais de secret;
- n'invente pas de regle complexe inutile;
- pour une action incertaine, utilise request_roll et n'applique PAS encore damage/heal/give/remove/apply_effect;
- si le message joueur contient deja un resultat de jet, resous la scene (succes/echec) et applique les effets;
- si une action structuree n'est pas certaine, utilise system_message ou request_roll;
- un objet equipe ou un effet deja present sur le joueur ne doit pas etre reapplique a l'identique;
- les potions (type potion, heal) et parchemins structures (type scroll + effect) sont utilises par le joueur: narre seulement, ne les re-soigne pas;
- sorts et blessures durables: apply_effect (remaining = nombre de resolutions MJ, omit si permanent).
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
