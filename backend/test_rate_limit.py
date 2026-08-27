import unittest

from rate_limit import (
    DEMO_EXPIRED,
    NOT_ENTITLED,
    RATE_LIMITED,
    RateLimitedError,
    RateLimiter,
)


class Clock:
    def __init__(self) -> None:
        self.value = 1_000.0

    def __call__(self) -> float:
        return self.value


class RateLimitTest(unittest.TestCase):
    def test_error_codes_are_stable(self) -> None:
        self.assertEqual(RATE_LIMITED, "RATE_LIMITED")
        self.assertEqual(DEMO_EXPIRED, "DEMO_EXPIRED")
        self.assertEqual(NOT_ENTITLED, "NOT_ENTITLED")

    def test_minute_limit_blocks_bursts(self) -> None:
        clock = Clock()
        limiter = RateLimiter(per_minute=3, per_hour=100, now=clock)
        limiter.check("user-1")
        limiter.check("user-1")
        limiter.check("user-1")
        with self.assertRaises(RateLimitedError) as raised:
            limiter.check("user-1")
        self.assertEqual(str(raised.exception), RATE_LIMITED)

    def test_minute_window_resets(self) -> None:
        clock = Clock()
        limiter = RateLimiter(per_minute=2, per_hour=100, now=clock)
        limiter.check("user-1")
        limiter.check("user-1")
        with self.assertRaises(RateLimitedError):
            limiter.check("user-1")
        clock.value += 60
        limiter.check("user-1")

    def test_hour_limit_blocks_even_if_minute_allows(self) -> None:
        clock = Clock()
        limiter = RateLimiter(per_minute=50, per_hour=3, now=clock)
        limiter.check("user-1")
        clock.value += 90
        limiter.check("user-1")
        clock.value += 90
        limiter.check("user-1")
        clock.value += 90
        with self.assertRaises(RateLimitedError):
            limiter.check("user-1")

    def test_users_are_isolated(self) -> None:
        clock = Clock()
        limiter = RateLimiter(per_minute=1, per_hour=10, now=clock)
        limiter.check("user-1")
        with self.assertRaises(RateLimitedError):
            limiter.check("user-1")
        limiter.check("user-2")

    def test_normal_play_burst_stays_under_defaults(self) -> None:
        clock = Clock()
        limiter = RateLimiter(now=clock)
        for _ in range(20):
            limiter.check("user-1")

    def test_disabled_when_limits_are_zero(self) -> None:
        limiter = RateLimiter(per_minute=0, per_hour=0)
        for _ in range(40):
            limiter.check("user-1")


if __name__ == "__main__":
    unittest.main()
