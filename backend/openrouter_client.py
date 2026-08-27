import json
import os

import httpx
from pydantic import ValidationError

from campaign_memory import EVENT_PROMPT_MAX_CHARS, RECENT_EVENT_LIMIT
from gm_locale import locale_language_name
from models import GameMasterRequest, GameMasterResponse


OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
DEFAULT_MODEL = "google/gemini-3.1-flash-lite"
REQUEST_TIMEOUT_SECONDS = 30


class GameMasterBackendError(RuntimeError):
    pass


def build_system_prompt(locale: str = "en") -> str:
    language = locale_language_name(locale)
    return f"""
Tu es le maitre du jeu IA d'un jeu de role medieval-fantasy multijoueur.
Tu ne produis jamais de markdown, jamais de texte hors JSON.
Tu dois retourner uniquement un objet JSON valide compatible avec ce contrat:
{{
  "narration": "immersive narrative text in {language}",
  "actions": [
    {{"type": "system_message", "payload": {{"message": "short text in {language}"}}}}
  ],
  "choices": [
    {{"label": "Player-facing choice in {language}", "action": "optional intent"}}
  ]
}}

Types d'actions autorises:
narrate, spawn_enemy, move_enemy, damage_enemy, heal_enemy, defeat_enemy,
damage_player, heal_player, give_item, remove_item, start_combat, end_combat,
system_message, request_roll, apply_effect, remove_effect, finish_game.

Payloads:
- spawn_enemy: {{"name": "Gobelin", "enemy_type": "goblin", "x": 0.4, "y": 0.6, "hp": 12, "max_hp": 12}}
- move_enemy: {{"enemy_id": "<id>", "x": 0.5, "y": 0.5}} ou {{"name": "Gobelin", "x": 0.5, "y": 0.5}}
- damage_enemy / heal_enemy: {{"enemy_id": "<id>", "amount": 4}} — jamais damage_player pour un ennemi
- defeat_enemy: {{"enemy_id": "<id>"}} ou {{"name": "Gobelin"}}
- damage_player / heal_player: {{"player_id": "<id>", "amount": 4}}
- give_item: {{"player_id": "<id>", "item": {{"id": "sword", "name": "Epee", "quantity": 1, "type": "weapon|armor|shield|accessory|potion|scroll|tool", "bonuses": {{"strength": 1}}, "heal": 20, "effect": {{"id": "bless", "name": "Benediction", "kind": "buff", "stat": "wisdom", "delta": 2, "remaining": 3}}}}}}
- remove_item: {{"player_id": "<id>", "item_id": "torch"}}
- request_roll: {{"player_id": "<id>", "ability": "strength|dexterity|constitution|intelligence|wisdom|charisma", "dc": 12, "reason": "escalader"}}
- apply_effect: {{"player_id": "<id>", "effect": {{"id": "poison", "name": "Poison", "kind": "debuff", "stat": "constitution", "delta": -2, "remaining": 2}}}}
- remove_effect: {{"player_id": "<id>", "effect_id": "poison"}}
- start_combat: {{"round": 1}} optionnel. Premier start = round 1. Un start pendant un combat actif passe au round suivant, ou au round fourni.
- end_combat: {{}} pour terminer. Ne supprime pas les ennemis.
- finish_game: {{"result": "victory|defeat|neutral", "summary": "short recap in {language}", "epilogue": "closing narration in {language}"}} when the adventure is over.

Contraintes:
- garde une narration courte et jouable;
- ne demande jamais de secret;
- n'invente pas de regle complexe inutile;
- pour une action incertaine, utilise request_roll et n'applique PAS encore damage/heal/give/remove/apply_effect/spawn_enemy/damage_enemy;
- tu PEUX emettre start_combat en meme temps qu'un request_roll (cadrage de scene, pas une consequence);
- si le message joueur contient deja un resultat de jet, ou si roll_result est present, resous la scene (succes/echec) et applique les effets;
- n'emets pas request_roll une seconde fois pour le meme jet deja resolu;
- si une action structuree n'est pas certaine, utilise system_message ou request_roll;
- un objet equipe ou un effet deja present sur le joueur ne doit pas etre reapplique a l'identique;
- les potions (type potion, heal) et parchemins structures (type scroll + effect) sont utilises par le joueur: narre seulement, ne les re-soigne pas;
- sorts et blessures durables: apply_effect (remaining = nombre de resolutions MJ, omit si permanent);
- le champ combat {{active, round}} est l'etat actuel: respecte-le;
- n'invente jamais les degats: le client ne calcule pas les PV. Apres un jet, utilise damage_enemy / damage_player;
- si world_state est present, respecte ce cadre (lieu, ton, objectif public) sans reveler gm_secrets;
- n'expose jamais gm_secrets dans narration, choices, ni actions;
- CAMPAIGN SUMMARY est la memoire longue; RECENT EVENTS sont le detail immediat;
- ne contredis pas le resume sauf si l'action du joueur le change;
- n'inclus jamais campaign_summary ni gm_secrets dans ta reponse JSON;
- ne raconte pas toute la campagne: construis la suite selon l'action du joueur;
- write narration, choice labels, reason text, item names shown to players, and system_message text in {language};
- JSON keys, action types, ability ids, and payload field names stay in English;
- emets finish_game seulement quand l'aventure est vraiment terminee (objectif atteint, echec irreversible, ou conclusion narrative).
""".strip()


def build_user_prompt(request: GameMasterRequest) -> str:
    world = request.world_state or {}
    scenario = {
        "title": world.get("title") or "",
        "setting": world.get("setting") or "",
        "tone": world.get("tone") or "",
        "public_objective": world.get("public_objective") or "",
        "starting_location": world.get("starting_location") or {},
    }
    recent = [
        {
            "type": event.type,
            "content": event.content[:EVENT_PROMPT_MAX_CHARS],
        }
        for event in request.recent_events[-RECENT_EVENT_LIMIT:]
    ]
    sections = [
        "OUTPUT LANGUAGE",
        locale_language_name(request.locale),
        "SCENARIO",
        json.dumps(scenario, ensure_ascii=False),
        "WORLD STATE",
        json.dumps(world, ensure_ascii=False),
        "CAMPAIGN SUMMARY",
        request.campaign_summary.strip() or "(aucun resume encore)",
        "CURRENT PLAYERS",
        json.dumps(
            [player.model_dump() for player in request.players],
            ensure_ascii=False,
        ),
        "CURRENT ENEMIES",
        json.dumps(
            [enemy.model_dump() for enemy in request.enemies],
            ensure_ascii=False,
        ),
        "COMBAT",
        json.dumps(
            request.combat.model_dump() if request.combat else None,
            ensure_ascii=False,
        ),
        "RECENT EVENTS",
        json.dumps(recent, ensure_ascii=False),
        "CURRENT ACTION",
        json.dumps(
            {
                "player_id": request.player_id,
                "player_name": request.player_name,
                "action": request.action,
            },
            ensure_ascii=False,
        ),
    ]
    if request.demo_end_required:
        sections.extend(
            [
                "DEMO END REQUIRED",
                (
                    "The 10-minute demo is over. Write a short cliffhanger "
                    "(2-4 sentences) in the output language. Emit finish_game "
                    "with result neutral, a brief summary, and an epilogue. "
                    "Do not continue the adventure. Do not mention timers, "
                    "purchases, or the word demo."
                ),
            ]
        )
    if request.roll_result is not None:
        sections.extend(
            [
                "ROLL RESULT",
                json.dumps(request.roll_result.model_dump(), ensure_ascii=False),
            ]
        )
    if request.gm_secrets:
        sections.extend(
            [
                "GM SECRETS — ne jamais reveler aux joueurs",
                json.dumps(request.gm_secrets, ensure_ascii=False),
            ]
        )
    return "\n".join(sections)


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
            {"role": "system", "content": build_system_prompt(request.locale)},
            {"role": "user", "content": build_user_prompt(request)},
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
