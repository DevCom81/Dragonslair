from datetime import datetime, timedelta, timezone
from typing import Any, Literal

DEMO_DURATION = timedelta(minutes=10)
DEMO_SCENARIO_ID = "demo"
CLOSED_ROOM_STATUSES = {"finished", "demo_finished"}

DemoPlayStatus = Literal["ok", "expired", "forbidden", "closed"]


class DemoForbiddenError(RuntimeError):
    pass


class DemoExpiredError(RuntimeError):
    pass


def normalize_access_level(value: object) -> Literal["demo", "full"]:
    raw = str(value or "").strip().lower()
    if raw == "full":
        return "full"
    return "demo"


def next_demo_clock(
    *,
    now: datetime,
    started_at: datetime | None,
    expires_at: datetime | None,
    completed_at: datetime | None,
    paused_at: datetime | None = None,
) -> tuple[datetime, datetime, DemoPlayStatus]:
    if completed_at is not None:
        start = started_at or now
        end = expires_at or (start + DEMO_DURATION)
        return start, end, "expired"
    if started_at is None:
        start = now
        return start, start + DEMO_DURATION, "ok"
    end = expires_at or (started_at + DEMO_DURATION)
    effective_now = paused_at if paused_at is not None else now
    if effective_now < end:
        return started_at, end, "ok"
    return started_at, end, "expired"


def evaluate_demo_play(
    *,
    access_level: object,
    room_status: object,
    room_scenario_id: object,
    room_host_id: object,
    user_id: str,
    started_at: datetime | None,
    expires_at: datetime | None,
    completed_at: datetime | None,
    now: datetime | None = None,
    paused_at: datetime | None = None,
) -> DemoPlayStatus:
    current = now or datetime.now(timezone.utc)
    status = str(room_status or "").strip().lower()
    if status in CLOSED_ROOM_STATUSES:
        return "closed"
    if normalize_access_level(access_level) == "full":
        return "ok"
    if str(room_scenario_id or "") != DEMO_SCENARIO_ID:
        return "forbidden"
    if str(room_host_id or "") != user_id:
        return "forbidden"
    _, _, clock = next_demo_clock(
        now=current,
        started_at=started_at,
        expires_at=expires_at,
        completed_at=completed_at,
        paused_at=paused_at,
    )
    return clock


def canned_demo_ending(locale: str) -> dict[str, Any]:
    language = str(locale or "en").strip().lower()
    if language == "fr":
        narration = (
            "Le souffle du wyrm s'engouffre dans la cave. La porte de pierre "
            "se referme a demi, et l'aventure s'interrompt au seuil du secret."
        )
        summary = "La demo s'acheve au moment ou le danger se revele."
        epilogue = "L'aventure ne fait que commencer."
        choice = "Revenir a la taverne"
    elif language == "de":
        narration = (
            "Der Atem des Wyrms fuellt den Keller. Die Steintuer schliesst "
            "sich halb, und das Abenteuer stockt an der Schwelle des Geheimnisses."
        )
        summary = "Die Demo endet, als die Gefahr sichtbar wird."
        epilogue = "Das Abenteuer hat gerade erst begonnen."
        choice = "Zurueck zur Taverne"
    elif language == "es":
        narration = (
            "El aliento del wyrm llena la bodega. La puerta de piedra se "
            "cierra a medias y la aventura se detiene al borde del secreto."
        )
        summary = "La demo termina cuando el peligro se revela."
        epilogue = "La aventura no ha hecho mas que empezar."
        choice = "Volver a la taberna"
    else:
        narration = (
            "The wyrm's breath floods the cellar. The stone door closes "
            "halfway, and the adventure halts at the threshold of the secret."
        )
        summary = "The demo ends just as the danger reveals itself."
        epilogue = "The adventure is only beginning."
        choice = "Return to the tavern"
    return {
        "narration": narration,
        "actions": [
            {
                "type": "finish_game",
                "payload": {
                    "result": "neutral",
                    "summary": summary,
                    "epilogue": epilogue,
                },
            }
        ],
        "choices": [{"label": choice}],
    }


def ensure_finish_action(payload: dict[str, Any], locale: str) -> dict[str, Any]:
    actions = payload.get("actions")
    if isinstance(actions, list):
        for action in actions:
            if isinstance(action, dict) and action.get("type") == "finish_game":
                return payload
    canned = canned_demo_ending(locale)
    merged = dict(payload)
    existing = list(actions) if isinstance(actions, list) else []
    merged["actions"] = existing + canned["actions"]
    if not merged.get("narration"):
        merged["narration"] = canned["narration"]
    return merged
