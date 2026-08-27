import json
import os

import httpx
from pydantic import ValidationError

from models import GeneratedScenario, GenerateScenarioRequest
from openrouter_client import (
    DEFAULT_MODEL,
    OPENROUTER_URL,
    REQUEST_TIMEOUT_SECONDS,
    GameMasterBackendError,
)


def _build_scenario_system_prompt() -> str:
    return """
Tu generes le cadre INITIAL d'une aventure de JDR, pas toute l'histoire.
Tu ne produis jamais de markdown, jamais de texte hors JSON.
Retourne uniquement un objet JSON:
{
  "title": "titre court",
  "setting": "lieu et epoque, 2-4 phrases",
  "tone": "ambiance",
  "public_objective": "objectif connu des joueurs",
  "starting_location": {"name": "lieu", "description": "une phrase"},
  "initial_situation": "ce qui se passe maintenant",
  "known_facts": ["fait public"],
  "starting_npcs": [{"name": "Nom", "role": "role visible"}],
  "initial_threats": [{"name": "Menace", "hint": "indice public, pas le secret"}],
  "opening_narration": "narration d'ouverture en francais, jouable, 1-3 phrases",
  "gm_secrets": ["secret reserve au MJ, jamais dit aux joueurs"]
}

Contraintes:
- n'ecris pas la campagne complete ni une succession de chapitres;
- l'histoire continuera selon les actions des joueurs;
- known_facts et opening_narration ne doivent contenir AUCUN secret;
- gm_secrets reste uniquement dans gm_secrets (3 a 6 elements courts);
- initial_threats.hint est un indice public, pas la verite cachee;
- langue francaise.
""".strip()


def _build_scenario_user_prompt(request: GenerateScenarioRequest) -> str:
    orientations = [
        item
        for item in request.orientations
        if item in {
            "combat",
            "exploration",
            "investigation",
            "roleplay",
            "survival",
        }
    ]
    difficulty = (
        request.difficulty if request.difficulty in {"easy", "standard", "hard"} else "standard"
    )
    duration = (
        request.duration if request.duration in {"short", "medium", "long"} else "medium"
    )
    return json.dumps(
        {
            "prompt": request.prompt.strip(),
            "title": request.title.strip(),
            "tone": request.tone.strip(),
            "difficulty": difficulty,
            "duration": duration,
            "orientations": orientations,
            "improvise": request.improvise,
            "permadeath": request.permadeath,
            "pvp": request.pvp,
            "betrayals": request.betrayals,
        },
        ensure_ascii=False,
    )


async def request_generated_scenario(
    request: GenerateScenarioRequest,
) -> GeneratedScenario:
    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        raise GameMasterBackendError("OPENROUTER_API_KEY is not configured.")

    model = os.getenv("OPENROUTER_MODEL", DEFAULT_MODEL)
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": _build_scenario_system_prompt()},
            {"role": "user", "content": _build_scenario_user_prompt(request)},
        ],
        "temperature": 0.8,
        "max_tokens": 1200,
        "response_format": {"type": "json_object"},
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "X-Title": "DragonsLair Scenario",
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
        return GeneratedScenario.model_validate(decoded)
    except (
        KeyError,
        IndexError,
        TypeError,
        json.JSONDecodeError,
        ValidationError,
    ) as error:
        raise GameMasterBackendError(
            "OpenRouter returned an invalid scenario payload."
        ) from error
