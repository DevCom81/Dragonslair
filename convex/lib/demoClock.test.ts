import { describe, expect, test } from "vitest";
import {
  cannedDemoEnding,
  DEMO_DURATION_MS,
  ensureFinishAction,
  evaluateDemoPlay,
  nextDemoClock,
  normalizeAccessLevel,
} from "./demoClock";

describe("LOT 8 demo clock helpers", () => {
  test("missing entitlement is demo", () => {
    expect(normalizeAccessLevel(undefined)).toBe("demo");
    expect(normalizeAccessLevel("FULL")).toBe("full");
  });

  test("clock starts on first play for exactly 10 minutes", () => {
    const now = Date.UTC(2026, 7, 27, 10, 0, 0);
    const clock = nextDemoClock({ now });
    expect(clock.status).toBe("ok");
    expect(clock.startedAt).toBe(now);
    expect(clock.expiresAt - clock.startedAt).toBe(DEMO_DURATION_MS);
    expect(DEMO_DURATION_MS).toBe(10 * 60 * 1000);
  });

  test("clock expires at exactly ten minutes", () => {
    const start = Date.UTC(2026, 7, 27, 10, 0, 0);
    const clock = nextDemoClock({
      now: start + DEMO_DURATION_MS,
      startedAt: start,
      expiresAt: start + DEMO_DURATION_MS,
    });
    expect(clock.status).toBe("expired");
  });

  test("full access skips demo room rules", () => {
    expect(
      evaluateDemoPlay({
        accessLevel: "full",
        roomStatus: "playing",
        roomScenarioId: "dungeon",
        roomHostId: "host",
        userId: "other",
      }),
    ).toBe("ok");
  });

  test("demo cannot play catalog room", () => {
    expect(
      evaluateDemoPlay({
        accessLevel: "demo",
        roomStatus: "playing",
        roomScenarioId: "dungeon",
        roomHostId: "user",
        userId: "user",
      }),
    ).toBe("forbidden");
  });

  test("closed room is closed even for full", () => {
    expect(
      evaluateDemoPlay({
        accessLevel: "full",
        roomStatus: "demo_finished",
        roomScenarioId: "demo",
        roomHostId: "user",
        userId: "user",
      }),
    ).toBe("closed");
  });

  test("canned ending has finish_game", () => {
    const payload = cannedDemoEnding("fr");
    expect(payload.narration.toLowerCase()).toContain("wyrm");
    expect(payload.actions[0]?.type).toBe("finish_game");
  });

  test("ensure_finish_action appends when missing", () => {
    const payload = ensureFinishAction(
      { narration: "Suite.", actions: [{ type: "narrate" }] },
      "en",
    );
    const types = (payload.actions as Array<{ type: string }>).map(
      (action) => action.type,
    );
    expect(types).toContain("finish_game");
  });

  test("demo scenario is allowed for the host before expiry", () => {
    const start = Date.UTC(2026, 7, 27, 10, 0, 0);
    expect(
      evaluateDemoPlay({
        accessLevel: "demo",
        roomStatus: "playing",
        roomScenarioId: "demo",
        roomHostId: "user",
        userId: "user",
        startedAt: start,
        expiresAt: start + DEMO_DURATION_MS,
        now: start + 5 * 60 * 1000,
      }),
    ).toBe("ok");
  });

  test("custom and other-host demo are forbidden", () => {
    expect(
      evaluateDemoPlay({
        accessLevel: "demo",
        roomStatus: "playing",
        roomScenarioId: "custom",
        roomHostId: "user",
        userId: "user",
      }),
    ).toBe("forbidden");
    expect(
      evaluateDemoPlay({
        accessLevel: "demo",
        roomStatus: "playing",
        roomScenarioId: "demo",
        roomHostId: "host",
        userId: "other",
      }),
    ).toBe("forbidden");
  });

  test("paused clock does not consume wall time", () => {
    const start = Date.UTC(2026, 7, 27, 10, 0, 0);
    const paused = start + 3 * 60 * 1000;
    const now = start + 30 * 60 * 1000;
    expect(
      nextDemoClock({
        now,
        startedAt: start,
        expiresAt: start + DEMO_DURATION_MS,
        pausedAt: paused,
      }).status,
    ).toBe("ok");
    expect(
      evaluateDemoPlay({
        accessLevel: "demo",
        roomStatus: "paused",
        roomScenarioId: "demo",
        roomHostId: "user",
        userId: "user",
        startedAt: start,
        expiresAt: start + DEMO_DURATION_MS,
        pausedAt: paused,
        now,
      }),
    ).toBe("ok");
  });

  test("completed session is expired", () => {
    const start = Date.UTC(2026, 7, 27, 10, 0, 0);
    expect(
      nextDemoClock({
        now: start + 1000,
        startedAt: start,
        expiresAt: start + DEMO_DURATION_MS,
        completedAt: start + 500,
      }).status,
    ).toBe("expired");
  });
});
