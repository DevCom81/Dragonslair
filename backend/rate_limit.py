import os
import threading
import time
from collections.abc import Callable

RATE_LIMITED = "RATE_LIMITED"
DEMO_EXPIRED = "DEMO_EXPIRED"
NOT_ENTITLED = "NOT_ENTITLED"

DEFAULT_PER_MINUTE = 30
DEFAULT_PER_HOUR = 300


class RateLimitedError(RuntimeError):
    def __init__(self) -> None:
        super().__init__(RATE_LIMITED)


def _env_limit(name: str, default: int) -> int:
    raw = os.getenv(name, "").strip()
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


class RateLimiter:
    def __init__(
        self,
        *,
        per_minute: int = DEFAULT_PER_MINUTE,
        per_hour: int = DEFAULT_PER_HOUR,
        now: Callable[[], float] | None = None,
    ) -> None:
        self.per_minute = per_minute
        self.per_hour = per_hour
        self._now = now or time.monotonic
        self._hits: dict[str, list[float]] = {}
        self._lock = threading.Lock()

    @property
    def disabled(self) -> bool:
        return self.per_minute <= 0 and self.per_hour <= 0

    def check(self, user_id: str) -> None:
        ident = str(user_id or "").strip()
        if not ident or self.disabled:
            return
        now = float(self._now())
        with self._lock:
            hits = self._hits.setdefault(ident, [])
            hour_cut = now - 3600
            minute_cut = now - 60
            hits[:] = [stamp for stamp in hits if stamp > hour_cut]
            minute_count = sum(1 for stamp in hits if stamp > minute_cut)
            hour_count = len(hits)
            over_minute = self.per_minute > 0 and minute_count >= self.per_minute
            over_hour = self.per_hour > 0 and hour_count >= self.per_hour
            if over_minute or over_hour:
                if not hits:
                    self._hits.pop(ident, None)
                raise RateLimitedError()
            hits.append(now)


def limiter_from_env() -> RateLimiter:
    return RateLimiter(
        per_minute=_env_limit("RATE_LIMIT_PER_MINUTE", DEFAULT_PER_MINUTE),
        per_hour=_env_limit("RATE_LIMIT_PER_HOUR", DEFAULT_PER_HOUR),
    )


_AI_LIMITER = limiter_from_env()


def enforce_ai_rate_limit(user_id: str) -> None:
    _AI_LIMITER.check(user_id)
