from typing import Any

VALID_GAME_RESULTS = {"victory", "defeat", "neutral"}


def parse_finish_game(payload: dict[str, Any] | None) -> dict[str, str]:
    data = payload if isinstance(payload, dict) else {}
    result = str(data.get("result") or "neutral").strip().lower()
    if result not in VALID_GAME_RESULTS:
        result = "neutral"
    return {
        "result": result,
        "summary": str(data.get("summary") or "").strip()[:2000],
        "epilogue": str(data.get("epilogue") or "").strip()[:4000],
    }
