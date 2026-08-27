import json

from pydantic import ValidationError

from gm_locale import locale_language_name
from models import GeneratedScenario, GenerateScenarioRequest
from openrouter_client import GameMasterBackendError, complete_openrouter_json


def build_scenario_system_prompt(locale: str = "en") -> str:
    language = locale_language_name(locale)
    return f"""
Tu generes le cadre INITIAL d'une aventure de JDR, pas toute l'histoire.
Tu ne produis jamais de markdown, jamais de texte hors JSON.
Retourne uniquement un objet JSON:
{{
  "title": "short title in {language}",
  "setting": "place and period, 2-4 sentences in {language}",
  "tone": "mood in {language}",
  "public_objective": "objective known to players, in {language}",
  "starting_location": {{"name": "place", "description": "one sentence in {language}"}},
  "initial_situation": "what is happening now, in {language}",
  "known_facts": ["public fact in {language}"],
  "starting_npcs": [{{"name": "Name", "role": "visible role in {language}"}}],
  "initial_threats": [{{"name": "Threat", "hint": "public hint in {language}, not the secret"}}],
  "opening_narration": "playable opening narration in {language}, 1-3 sentences",
  "gm_secrets": ["GM-only secret, never told to players"]
}}

Contraintes:
- n'ecris pas la campagne complete ni une succession de chapitres;
- l'histoire continuera selon les actions des joueurs;
- known_facts et opening_narration ne doivent contenir AUCUN secret;
- gm_secrets reste uniquement dans gm_secrets (3 a 6 elements courts);
- initial_threats.hint est un indice public, pas la verite cachee;
- write all player-facing strings in {language};
- JSON keys stay in English.
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
    *,
    user_id: str = "",
) -> GeneratedScenario:
    decoded = await complete_openrouter_json(
        messages=[
            {"role": "system", "content": build_scenario_system_prompt(request.locale)},
            {"role": "user", "content": _build_scenario_user_prompt(request)},
        ],
        temperature=0.8,
        max_tokens=1200,
        title="DragonsLair Scenario",
        user_id=user_id,
        room_id=request.room_id,
        kind="scenario",
    )
    try:
        return GeneratedScenario.model_validate(decoded)
    except ValidationError as error:
        raise GameMasterBackendError(
            "OpenRouter returned an invalid scenario payload."
        ) from error
