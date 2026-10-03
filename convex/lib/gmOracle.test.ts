import { describe, expect, test } from "vitest";
import {
  applyMemoryToGmState,
  capRecentEvents,
  CAMPAIGN_SUMMARY_MAX_CHARS,
  mergeCampaignSummary,
  nextMemory,
  parseMemory,
  RECENT_EVENT_LIMIT,
  recentEventsFromRows,
  shouldSummarize,
  SUMMARY_THRESHOLD,
  summaryWindow,
} from "./campaignMemory";
import { parseOpenRouterUsage } from "./aiUsage";
import { parseGameMasterResponse } from "./gmValidate";
import { GameMasterBackendError } from "./errors";
import { rateLimitExceeded } from "./rateLimit";
import { RATE_LIMITED, RateLimitedError } from "./errors";
import { buildUserPrompt } from "../prompts";

describe("campaign memory oracle", () => {
  test("summarizes after threshold beyond recent window", () => {
    expect(
      shouldSummarize({
        eventCount: RECENT_EVENT_LIMIT,
        summarizedEventCount: 0,
      }),
    ).toBe(false);
    expect(
      shouldSummarize({
        eventCount: RECENT_EVENT_LIMIT + SUMMARY_THRESHOLD - 1,
        summarizedEventCount: 0,
      }),
    ).toBe(false);
    expect(
      shouldSummarize({
        eventCount: RECENT_EVENT_LIMIT + SUMMARY_THRESHOLD,
        summarizedEventCount: 0,
      }),
    ).toBe(true);
  });

  test("summary window excludes recent events", () => {
    const window = summaryWindow({
      eventCount: RECENT_EVENT_LIMIT + SUMMARY_THRESHOLD,
      summarizedEventCount: 0,
    });
    expect(window).toEqual({ start: 0, limit: SUMMARY_THRESHOLD });
  });

  test("cap recent events keeps the tail", () => {
    const events = Array.from({ length: 20 }, (_, index) => ({
      content: `fait ${index}`,
    }));
    const capped = capRecentEvents(events);
    expect(capped).toHaveLength(RECENT_EVENT_LIMIT);
    expect(capped[0]?.content).toBe("fait 12");
    expect(capped.at(-1)?.content).toBe("fait 19");
  });

  test("merge summary truncates and parse strips secrets", () => {
    const previous = "A".repeat(CAMPAIGN_SUMMARY_MAX_CHARS - 10);
    const merged = mergeCampaignSummary(previous, [
      { type: "narration", content: "B".repeat(80) },
    ]);
    expect(merged.length).toBeLessThanOrEqual(CAMPAIGN_SUMMARY_MAX_CHARS);
    expect(merged.startsWith("…")).toBe(true);
    const parsed = parseMemory({
      campaign_summary: "  le prince fuit  ",
      summarized_event_count: "4",
      gm_secrets: ["ne pas copier"],
    });
    expect(parsed).toEqual({
      campaign_summary: "le prince fuit",
      summarized_event_count: 4,
    });
    const applied = applyMemoryToGmState(
      { tone: "sombre", gm_secrets: ["fuite"] },
      { campaign_summary: "resume", summarized_event_count: 12 },
    );
    expect(applied.tone).toBe("sombre");
    expect(applied).not.toHaveProperty("gm_secrets");
  });

  test("next memory marks old events summarized", () => {
    const eventCount = RECENT_EVENT_LIMIT + SUMMARY_THRESHOLD;
    const folded = Array.from({ length: SUMMARY_THRESHOLD }, (_, index) => ({
      type: "narration",
      content: `fait ${index}`,
    }));
    const memory = nextMemory({
      previous: { campaign_summary: "", summarized_event_count: 0 },
      foldedEvents: folded,
      eventCount,
    });
    expect(memory.summarized_event_count).toBe(eventCount - RECENT_EVENT_LIMIT);
    expect(memory.campaign_summary).toContain("fait 0");
  });

  test("recent events drop unknown types", () => {
    const events = recentEventsFromRows([
      { type: "narration", content: "La porte s ouvre." },
      { type: "secret", content: "ne pas envoyer" },
      { type: "action", content: "  " },
    ]);
    expect(events).toHaveLength(1);
    expect(events[0]?.type).toBe("narration");
  });
});

describe("prompts", () => {
  test("user prompt uses labeled sections and caps events", () => {
    const prompt = buildUserPrompt({
      locale: "fr",
      world_state: { title: "La Route", tone: "sombre" },
      campaign_summary: "Le groupe escorte un prince.",
      players: [],
      enemies: [],
      combat: null,
      music_mood: "exploration",
      recent_events: Array.from({ length: 20 }, (_, index) => ({
        type: "narration",
        content: `evenement ${index}`,
      })),
      player_id: "p1",
      player_name: "Aldric",
      action: "Inspecte le tonneau.",
      demo_end_required: false,
      roll_result: null,
      gm_secrets: ["le prince est un usurateur"],
    });
    for (const section of [
      "SCENARIO",
      "WORLD STATE",
      "CAMPAIGN SUMMARY",
      "CURRENT PLAYERS",
      "CURRENT ENEMIES",
      "RECENT EVENTS",
      "CURRENT ACTION",
    ]) {
      expect(prompt).toContain(section);
    }
    expect(prompt).toContain("Le groupe escorte un prince.");
    expect(prompt).toContain("Inspecte le tonneau.");
    expect(prompt).toContain("le prince est un usurateur");
    expect(prompt).not.toContain("evenement 0");
    expect(prompt).toContain("evenement 19");
  });
});

describe("gm response parse", () => {
  test("valid payload and drop invalid music", () => {
    const parsed = parseGameMasterResponse({
      narration: "La taverne est calme.",
      actions: [
        { type: "set_music_mood", payload: { mood: "combat" } },
        { type: "set_music_mood", mood: "tavern" },
      ],
      choices: [],
    });
    expect(parsed.narration).toBe("La taverne est calme.");
    expect(parsed.actions).toHaveLength(1);
    expect(parsed.actions[0]?.payload).toMatchObject({ mood: "tavern" });
    expect(parsed).not.toHaveProperty("campaign_summary");
    expect(parsed).not.toHaveProperty("gm_secrets");
  });

  test("unknown action type is invalid", () => {
    expect(() =>
      parseGameMasterResponse({
        narration: "Boom",
        actions: [{ type: "explode", payload: {} }],
      }),
    ).toThrow(GameMasterBackendError);
  });
});

describe("ai usage parse", () => {
  test("stores openrouter cost and tokens", () => {
    const stats = parseOpenRouterUsage(
      {
        usage: {
          prompt_tokens: 194,
          completion_tokens: 40,
          cost: 0.0012,
        },
      },
      { model: "google/gemini-3.1-flash-lite", latencyMs: 321 },
    );
    expect(stats.input_tokens).toBe(194);
    expect(stats.output_tokens).toBe(40);
    expect(stats.cost).toBe(0.0012);
    expect(stats.cost_source).toBe("openrouter");
  });

  test("missing usage has no cost", () => {
    const stats = parseOpenRouterUsage({}, { model: "m", latencyMs: 10 });
    expect(stats.input_tokens).toBeNull();
    expect(stats.cost).toBeNull();
    expect(stats.cost_source).toBe("none");
  });
});

describe("rate limit", () => {
  test("error code is stable and minute limit blocks", () => {
    expect(RATE_LIMITED).toBe("RATE_LIMITED");
    expect(new RateLimitedError().message).toBe(RATE_LIMITED);
    const now = 1_000_000;
    expect(
      rateLimitExceeded({
        hits: [now - 1000, now - 500, now - 100],
        now,
        perMinute: 3,
        perHour: 100,
      }),
    ).toBe(true);
    expect(
      rateLimitExceeded({
        hits: [now - 1000, now - 500],
        now,
        perMinute: 3,
        perHour: 100,
      }),
    ).toBe(false);
  });
});
