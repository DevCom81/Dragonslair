import { describe, expect, test } from "vitest";
import {
  ABILITY_KEYS,
  ACCESS_LEVELS,
  AI_COST_SOURCES,
  AI_USAGE_KINDS,
  ENEMY_STATUSES,
  ENTITLEMENT_GRANT_SOURCES,
  ENTITLEMENT_PROVIDERS,
  ENTITLEMENT_SOURCE_STATUSES,
  GAME_ENDING_RESULTS,
  GAME_EVENT_TYPES,
  NARRATIVE_MUSIC_MOODS,
  PENDING_ROLL_STATUSES,
  ROOM_LOCALES,
  ROOM_STATUSES,
  isAbilityKey,
  isDisplayName,
  isFigurineId,
  isNormalizedPosition,
  isPendingRollDc,
  isPendingRollDie,
  isRoomStatus,
  isStatInRange,
} from "./validators";

describe("admitted values", () => {
  test("matches the live SQL/Flutter contracts", () => {
    expect([...ROOM_STATUSES]).toEqual([
      "waiting",
      "playing",
      "paused",
      "finished",
      "demo_finished",
    ]);
    expect([...ROOM_LOCALES]).toEqual(["fr", "en", "de", "es"]);
    expect([...NARRATIVE_MUSIC_MOODS]).toEqual([
      "tavern",
      "exploration",
      "mystery",
      "tension",
    ]);
    expect([...GAME_EVENT_TYPES]).toEqual(["action", "narration", "system"]);
    expect([...ENEMY_STATUSES]).toEqual(["active", "defeated", "escaped"]);
    expect([...ABILITY_KEYS]).toEqual([
      "strength",
      "dexterity",
      "constitution",
      "intelligence",
      "wisdom",
      "charisma",
    ]);
    expect([...PENDING_ROLL_STATUSES]).toEqual([
      "pending",
      "resolved",
      "cancelled",
    ]);
    expect([...ACCESS_LEVELS]).toEqual(["demo", "full"]);
    expect([...ENTITLEMENT_GRANT_SOURCES]).toEqual([
      "default",
      "purchase",
      "admin",
      "promo",
    ]);
    expect([...ENTITLEMENT_PROVIDERS]).toEqual([
      "stripe",
      "google_play",
      "manual",
    ]);
    expect([...ENTITLEMENT_SOURCE_STATUSES]).toEqual([
      "active",
      "pending",
      "canceled",
      "expired",
      "on_hold",
      "revoked",
    ]);
    expect([...AI_USAGE_KINDS]).toEqual(["game_master", "scenario"]);
    expect([...AI_COST_SOURCES]).toEqual(["none", "openrouter", "estimate"]);
    expect([...GAME_ENDING_RESULTS]).toEqual(["victory", "defeat", "neutral"]);
  });

  test("does not include values absent from the live contracts", () => {
    expect(ROOM_STATUSES).not.toContain("cancelled");
    expect(NARRATIVE_MUSIC_MOODS).not.toContain("combat");
    expect(ACCESS_LEVELS).not.toContain("guest");
    expect(ENTITLEMENT_PROVIDERS).not.toContain("apple");
    expect(ENTITLEMENT_SOURCE_STATUSES).not.toContain("cancelled");
  });
});

describe("SQL check helpers", () => {
  test("accepts in-range character, figurine, position, DC, and display name", () => {
    expect(isRoomStatus("paused")).toBe(true);
    expect(isAbilityKey("charisma")).toBe(true);
    expect(isFigurineId(0)).toBe(true);
    expect(isFigurineId(39)).toBe(true);
    expect(isStatInRange(8)).toBe(true);
    expect(isStatInRange(18)).toBe(true);
    expect(isNormalizedPosition(0)).toBe(true);
    expect(isNormalizedPosition(1)).toBe(true);
    expect(isPendingRollDc(5)).toBe(true);
    expect(isPendingRollDc(25)).toBe(true);
    expect(isPendingRollDie(1)).toBe(true);
    expect(isPendingRollDie(20)).toBe(true);
    expect(isDisplayName("ab")).toBe(true);
    expect(isDisplayName("a".repeat(32))).toBe(true);
  });

  test("rejects out-of-range values", () => {
    expect(isRoomStatus("archived")).toBe(false);
    expect(isFigurineId(40)).toBe(false);
    expect(isFigurineId(-1)).toBe(false);
    expect(isStatInRange(7)).toBe(false);
    expect(isStatInRange(19)).toBe(false);
    expect(isNormalizedPosition(-0.01)).toBe(false);
    expect(isNormalizedPosition(1.01)).toBe(false);
    expect(isPendingRollDc(4)).toBe(false);
    expect(isPendingRollDc(26)).toBe(false);
    expect(isPendingRollDie(0)).toBe(false);
    expect(isPendingRollDie(21)).toBe(false);
    expect(isDisplayName("a")).toBe(false);
    expect(isDisplayName("a".repeat(33))).toBe(false);
  });
});
