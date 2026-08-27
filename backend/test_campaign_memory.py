import unittest

from campaign_memory import (
    CAMPAIGN_SUMMARY_MAX_CHARS,
    RECENT_EVENT_LIMIT,
    SUMMARY_THRESHOLD,
    apply_memory_to_gm_state,
    cap_recent_events,
    merge_campaign_summary,
    next_memory,
    parse_memory,
    recent_events_from_rows,
    should_summarize,
    summary_window,
)
from models import GameMasterRequest, GameMasterResponse
from openrouter_client import build_user_prompt


def _event(index: int, kind: str = "narration") -> dict:
    return {"type": kind, "content": f"fait {index}"}


class CampaignMemoryTest(unittest.TestCase):
    def test_does_not_summarize_while_inside_recent_window(self) -> None:
        self.assertFalse(
            should_summarize(
                event_count=RECENT_EVENT_LIMIT,
                summarized_event_count=0,
            )
        )

    def test_summarizes_after_threshold_beyond_recent_window(self) -> None:
        self.assertFalse(
            should_summarize(
                event_count=RECENT_EVENT_LIMIT + SUMMARY_THRESHOLD - 1,
                summarized_event_count=0,
            )
        )
        self.assertTrue(
            should_summarize(
                event_count=RECENT_EVENT_LIMIT + SUMMARY_THRESHOLD,
                summarized_event_count=0,
            )
        )

    def test_summary_window_excludes_recent_events(self) -> None:
        offset, limit = summary_window(
            event_count=RECENT_EVENT_LIMIT + SUMMARY_THRESHOLD,
            summarized_event_count=0,
        )
        self.assertEqual(offset, 0)
        self.assertEqual(limit, SUMMARY_THRESHOLD)
        folded_end = offset + limit
        self.assertEqual(folded_end, SUMMARY_THRESHOLD)
        recent_start = (RECENT_EVENT_LIMIT + SUMMARY_THRESHOLD) - RECENT_EVENT_LIMIT
        self.assertEqual(folded_end, recent_start)

    def test_cap_recent_events_keeps_the_tail(self) -> None:
        events = [_event(i) for i in range(20)]
        capped = cap_recent_events(events)
        self.assertEqual(len(capped), RECENT_EVENT_LIMIT)
        self.assertEqual(capped[0]["content"], "fait 12")
        self.assertEqual(capped[-1]["content"], "fait 19")

    def test_merge_summary_truncates_to_max_chars(self) -> None:
        previous = "A" * (CAMPAIGN_SUMMARY_MAX_CHARS - 10)
        folded = [{"type": "narration", "content": "B" * 80}]
        merged = merge_campaign_summary(previous, folded)
        self.assertLessEqual(len(merged), CAMPAIGN_SUMMARY_MAX_CHARS)
        self.assertTrue(merged.startswith("…"))
        self.assertIn("B", merged)

    def test_next_memory_marks_old_events_summarized_without_deleting(self) -> None:
        event_count = RECENT_EVENT_LIMIT + SUMMARY_THRESHOLD
        folded = [_event(i) for i in range(SUMMARY_THRESHOLD)]
        memory = next_memory(
            previous={"campaign_summary": "", "summarized_event_count": 0},
            folded_events=folded,
            event_count=event_count,
        )
        self.assertEqual(
            memory["summarized_event_count"],
            event_count - RECENT_EVENT_LIMIT,
        )
        self.assertIn("fait 0", memory["campaign_summary"])
        self.assertIn("fait 11", memory["campaign_summary"])

    def test_parse_memory_strips_invalid_values(self) -> None:
        parsed = parse_memory(
            {
                "campaign_summary": "  le prince fuit  ",
                "summarized_event_count": "4",
                "gm_secrets": ["ne pas copier"],
            }
        )
        self.assertEqual(parsed["campaign_summary"], "le prince fuit")
        self.assertEqual(parsed["summarized_event_count"], 4)

    def test_apply_memory_preserves_other_gm_state_and_drops_nested_secrets(self) -> None:
        merged = apply_memory_to_gm_state(
            {"tone": "sombre", "gm_secrets": ["fuite"]},
            {"campaign_summary": "resume", "summarized_event_count": 12},
        )
        self.assertEqual(merged["tone"], "sombre")
        self.assertEqual(merged["campaign_summary"], "resume")
        self.assertNotIn("gm_secrets", merged)

    def test_recent_events_from_rows_drops_unknown_types(self) -> None:
        events = recent_events_from_rows(
            [
                {"type": "narration", "content": "La porte s ouvre."},
                {"type": "secret", "content": "ne pas envoyer"},
                {"type": "action", "content": "  "},
            ]
        )
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0].type, "narration")

    def test_user_prompt_uses_labeled_sections_and_caps_events(self) -> None:
        request = GameMasterRequest(
            room_id="room-1",
            player_id="p1",
            player_name="Aldric",
            action="Inspecte le tonneau.",
            campaign_summary="Le groupe escorte un prince.",
            recent_events=[
                {"type": "narration", "content": f"evenement {index}"}
                for index in range(20)
            ],
            world_state={"title": "La Route", "tone": "sombre"},
            gm_secrets=["le prince est un usurateur"],
        )
        prompt = build_user_prompt(request)
        for section in (
            "SCENARIO",
            "WORLD STATE",
            "CAMPAIGN SUMMARY",
            "CURRENT PLAYERS",
            "CURRENT ENEMIES",
            "RECENT EVENTS",
            "CURRENT ACTION",
        ):
            self.assertIn(section, prompt)
        self.assertIn("Le groupe escorte un prince.", prompt)
        self.assertIn("Inspecte le tonneau.", prompt)
        self.assertIn("le prince est un usurateur", prompt)
        self.assertNotIn("evenement 0", prompt)
        self.assertIn("evenement 19", prompt)

    def test_gm_http_response_cannot_carry_campaign_summary(self) -> None:
        response = GameMasterResponse.model_validate(
            {
                "narration": "La taverne est calme.",
                "actions": [],
                "choices": [],
            }
        )
        dumped = response.model_dump()
        self.assertNotIn("campaign_summary", dumped)
        self.assertNotIn("gm_secrets", dumped)


if __name__ == "__main__":
    unittest.main()
