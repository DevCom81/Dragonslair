import unittest
from unittest.mock import patch

from ai_usage import (
    estimate_cost_usd,
    parse_openrouter_usage,
    record_ai_usage,
    usage_log_row,
)


class AiUsageTest(unittest.TestCase):
    def test_openrouter_cost_is_stored(self) -> None:
        stats = parse_openrouter_usage(
            {
                "usage": {
                    "prompt_tokens": 194,
                    "completion_tokens": 40,
                    "cost": 0.0012,
                }
            },
            model="google/gemini-3.1-flash-lite",
            latency_ms=321,
        )
        self.assertEqual(stats["input_tokens"], 194)
        self.assertEqual(stats["output_tokens"], 40)
        self.assertEqual(stats["latency_ms"], 321)
        self.assertEqual(stats["cost"], 0.0012)
        self.assertEqual(stats["cost_source"], "openrouter")
        self.assertEqual(stats["model"], "google/gemini-3.1-flash-lite")

    def test_missing_usage_has_no_cost(self) -> None:
        stats = parse_openrouter_usage({}, model="m", latency_ms=10)
        self.assertIsNone(stats["input_tokens"])
        self.assertIsNone(stats["output_tokens"])
        self.assertIsNone(stats["cost"])
        self.assertEqual(stats["cost_source"], "none")

    def test_estimate_is_used_when_openrouter_has_no_cost(self) -> None:
        with patch.dict(
            "os.environ",
            {
                "AI_INPUT_USD_PER_MILLION": "0.10",
                "AI_OUTPUT_USD_PER_MILLION": "0.40",
            },
            clear=False,
        ):
            estimated = estimate_cost_usd(input_tokens=1_000_000, output_tokens=0)
            self.assertEqual(estimated, 0.10)
            stats = parse_openrouter_usage(
                {"usage": {"prompt_tokens": 1_000_000, "completion_tokens": 0}},
                model="m",
                latency_ms=1,
            )
            self.assertEqual(stats["cost_source"], "estimate")
            self.assertEqual(stats["cost"], 0.10)

    def test_log_row_is_scoped_to_one_user_and_room(self) -> None:
        row = usage_log_row(
            user_id="user-1",
            room_id="room-1",
            kind="game_master",
            stats={
                "model": "m",
                "input_tokens": 10,
                "output_tokens": 4,
                "latency_ms": 9,
                "cost": 0.01,
                "cost_source": "openrouter",
            },
        )
        self.assertEqual(row["user_id"], "user-1")
        self.assertEqual(row["room_id"], "room-1")
        self.assertNotIn("choices", row)
        self.assertNotIn("narration", row)


class AiUsageRecordTest(unittest.IsolatedAsyncioTestCase):
    async def test_persist_failure_does_not_raise(self) -> None:
        async def boom(row: dict) -> None:
            raise RuntimeError("db down")

        with self.assertLogs("dragons_lair", level="INFO"):
            await record_ai_usage(
                user_id="user-1",
                room_id="room-1",
                kind="game_master",
                stats={
                    "model": "m",
                    "input_tokens": 1,
                    "output_tokens": 1,
                    "latency_ms": 1,
                    "cost": None,
                    "cost_source": "none",
                },
                persist=boom,
            )


if __name__ == "__main__":
    unittest.main()
