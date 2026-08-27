import asyncio
import json
import logging
import os
from typing import Any, Awaitable, Callable

logger = logging.getLogger("dragons_lair")

PersistFn = Callable[[dict[str, Any]], Awaitable[None]]


def _nonneg_int(value: object) -> int | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, int) and value >= 0:
        return value
    if isinstance(value, float) and value >= 0:
        return int(value)
    return None


def _nonneg_float(value: object) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)) and value >= 0:
        return float(value)
    return None


def _rate(name: str) -> float | None:
    raw = os.getenv(name, "").strip()
    if not raw:
        return None
    try:
        value = float(raw)
    except ValueError:
        return None
    if value < 0:
        return None
    return value


def estimate_cost_usd(
    *,
    input_tokens: int | None,
    output_tokens: int | None,
) -> float | None:
    in_rate = _rate("AI_INPUT_USD_PER_MILLION")
    out_rate = _rate("AI_OUTPUT_USD_PER_MILLION")
    if in_rate is None or out_rate is None:
        return None
    prompt = input_tokens or 0
    completion = output_tokens or 0
    return (prompt * in_rate + completion * out_rate) / 1_000_000


def parse_openrouter_usage(
    payload: object,
    *,
    model: str,
    latency_ms: int,
) -> dict[str, Any]:
    usage = payload.get("usage") if isinstance(payload, dict) else None
    input_tokens = None
    output_tokens = None
    cost = None
    cost_source = "none"
    if isinstance(usage, dict):
        input_tokens = _nonneg_int(usage.get("prompt_tokens"))
        output_tokens = _nonneg_int(usage.get("completion_tokens"))
        cost = _nonneg_float(usage.get("cost"))
        if cost is not None:
            cost_source = "openrouter"
    if cost is None and (input_tokens is not None or output_tokens is not None):
        estimated = estimate_cost_usd(
            input_tokens=input_tokens,
            output_tokens=output_tokens,
        )
        if estimated is not None:
            cost = estimated
            cost_source = "estimate"
    return {
        "model": str(model or "").strip()[:120],
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "latency_ms": max(0, int(latency_ms)),
        "cost": cost,
        "cost_source": cost_source,
    }


def usage_log_row(
    *,
    user_id: str,
    room_id: str,
    kind: str,
    stats: dict[str, Any],
) -> dict[str, Any]:
    return {
        "user_id": str(user_id or "").strip() or None,
        "room_id": str(room_id or "").strip() or None,
        "kind": kind if kind in {"game_master", "scenario"} else "game_master",
        "model": stats.get("model") or "",
        "input_tokens": stats.get("input_tokens"),
        "output_tokens": stats.get("output_tokens"),
        "latency_ms": stats.get("latency_ms"),
        "cost": stats.get("cost"),
        "cost_source": stats.get("cost_source") or "none",
    }


async def _persist_row(row: dict[str, Any]) -> None:
    from supabase_admin import insert_ai_usage_event

    await insert_ai_usage_event(
        user_id=row.get("user_id"),
        room_id=row.get("room_id"),
        model=str(row.get("model") or ""),
        kind=str(row.get("kind") or "game_master"),
        input_tokens=row.get("input_tokens"),
        output_tokens=row.get("output_tokens"),
        latency_ms=row.get("latency_ms"),
        cost=row.get("cost"),
        cost_source=str(row.get("cost_source") or "none"),
    )


async def record_ai_usage(
    *,
    user_id: str,
    room_id: str,
    kind: str,
    stats: dict[str, Any],
    persist: PersistFn | None = None,
) -> None:
    row = usage_log_row(
        user_id=user_id,
        room_id=room_id,
        kind=kind,
        stats=stats,
    )
    logger.info("ai_usage %s", json.dumps(row, default=str))
    writer = persist or _persist_row
    try:
        await asyncio.wait_for(writer(row), timeout=2)
    except Exception as error:
        logger.warning("ai_usage persist failed: %s", error)
