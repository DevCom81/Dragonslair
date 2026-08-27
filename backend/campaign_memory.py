from models import RecentGameEvent

RECENT_EVENT_LIMIT = 8
SUMMARY_THRESHOLD = 12
CAMPAIGN_SUMMARY_MAX_CHARS = 1800
EVENT_LINE_MAX_CHARS = 160
EVENT_PROMPT_MAX_CHARS = 400


def should_summarize(*, event_count: int, summarized_event_count: int) -> bool:
    old_count = max(0, event_count - RECENT_EVENT_LIMIT)
    return old_count - max(0, summarized_event_count) >= SUMMARY_THRESHOLD


def summary_window(
    *, event_count: int, summarized_event_count: int
) -> tuple[int, int]:
    start = max(0, summarized_event_count)
    end = max(0, event_count - RECENT_EVENT_LIMIT)
    if end <= start:
        return start, 0
    return start, end - start


def cap_recent_events(events: list, limit: int = RECENT_EVENT_LIMIT) -> list:
    if len(events) <= limit:
        return list(events)
    return list(events[-limit:])


def parse_memory(gm_state: object) -> dict:
    if not isinstance(gm_state, dict):
        return {"campaign_summary": "", "summarized_event_count": 0}
    summary = str(gm_state.get("campaign_summary") or "").strip()
    if len(summary) > CAMPAIGN_SUMMARY_MAX_CHARS:
        summary = summary[-CAMPAIGN_SUMMARY_MAX_CHARS:]
    raw_count = gm_state.get("summarized_event_count") or 0
    try:
        count = int(raw_count)
    except (TypeError, ValueError):
        count = 0
    if count < 0:
        count = 0
    return {"campaign_summary": summary, "summarized_event_count": count}


def event_line(event: dict) -> str:
    kind = str(event.get("type") or "system").strip() or "system"
    content = str(event.get("content") or "").replace("\n", " ").strip()
    if len(content) > EVENT_LINE_MAX_CHARS:
        content = content[:EVENT_LINE_MAX_CHARS]
    if not content:
        return ""
    return f"[{kind}] {content}"


def merge_campaign_summary(previous: str, folded_events: list[dict]) -> str:
    lines = []
    for event in folded_events:
        line = event_line(event)
        if line:
            lines.append(line)
    chunk = "\n".join(lines)
    previous = (previous or "").strip()
    if not previous:
        text = chunk
    elif not chunk:
        text = previous
    else:
        text = f"{previous}\n{chunk}"
    if len(text) <= CAMPAIGN_SUMMARY_MAX_CHARS:
        return text
    return "…" + text[-(CAMPAIGN_SUMMARY_MAX_CHARS - 1) :]


def next_memory(
    *,
    previous: dict,
    folded_events: list[dict],
    event_count: int,
) -> dict:
    return {
        "campaign_summary": merge_campaign_summary(
            str(previous.get("campaign_summary") or ""),
            folded_events,
        ),
        "summarized_event_count": max(0, event_count - RECENT_EVENT_LIMIT),
    }


def recent_events_from_rows(rows: list[dict]) -> list[RecentGameEvent]:
    events: list[RecentGameEvent] = []
    for row in rows:
        kind = row.get("type")
        content = str(row.get("content") or "").strip()
        if kind not in {"action", "narration", "system"} or not content:
            continue
        events.append(
            RecentGameEvent(type=kind, content=content[:2000])
        )
    return cap_recent_events(events)


def apply_memory_to_gm_state(gm_state: object, memory: dict) -> dict:
    merged = dict(gm_state) if isinstance(gm_state, dict) else {}
    merged.pop("gm_secrets", None)
    merged["campaign_summary"] = str(memory.get("campaign_summary") or "")
    merged["summarized_event_count"] = int(
        memory.get("summarized_event_count") or 0
    )
    return merged
