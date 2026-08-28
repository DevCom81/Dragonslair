NARRATIVE_MUSIC_MOODS = {
    "tavern",
    "exploration",
    "mystery",
    "tension",
}


def normalize_narrative_music_mood(value: object) -> str:
    raw = str(value or "").strip().lower()
    if raw in NARRATIVE_MUSIC_MOODS:
        return raw
    return "exploration"


def last_narrative_music_mood(actions: list) -> str | None:
    last: str | None = None
    for action in actions:
        if getattr(action, "type", None) != "set_music_mood":
            continue
        payload = getattr(action, "payload", None)
        if not isinstance(payload, dict):
            continue
        mood = str(payload.get("mood") or "").strip().lower()
        if mood in NARRATIVE_MUSIC_MOODS:
            last = mood
    return last
