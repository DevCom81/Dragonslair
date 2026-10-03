import { v } from "convex/values";

export const ROOM_STATUSES = [
  "waiting",
  "playing",
  "paused",
  "finished",
  "demo_finished",
] as const;

export const ROOM_LOCALES = ["fr", "en", "de", "es"] as const;

export const NARRATIVE_MUSIC_MOODS = [
  "tavern",
  "exploration",
  "mystery",
  "tension",
] as const;

export const GAME_EVENT_TYPES = ["action", "narration", "system"] as const;

export const ENEMY_STATUSES = ["active", "defeated", "escaped"] as const;

export const ABILITY_KEYS = [
  "strength",
  "dexterity",
  "constitution",
  "intelligence",
  "wisdom",
  "charisma",
] as const;

export const PENDING_ROLL_STATUSES = [
  "pending",
  "resolved",
  "cancelled",
] as const;

export const ACCESS_LEVELS = ["demo", "full"] as const;

export const ENTITLEMENT_GRANT_SOURCES = [
  "default",
  "purchase",
  "admin",
  "promo",
] as const;

export const ENTITLEMENT_PROVIDERS = [
  "stripe",
  "google_play",
  "manual",
] as const;

export const ENTITLEMENT_SOURCE_STATUSES = [
  "active",
  "pending",
  "canceled",
  "expired",
  "on_hold",
  "revoked",
] as const;

export const AI_USAGE_KINDS = ["game_master", "scenario"] as const;

export const AI_COST_SOURCES = ["none", "openrouter", "estimate"] as const;

export const GAME_ENDING_RESULTS = ["victory", "defeat", "neutral"] as const;

export const CHARACTER_CLASS_IDS = [
  "barbarian",
  "bard",
  "cleric",
  "druid",
  "fighter",
  "monk",
  "paladin",
  "ranger",
  "rogue",
  "sorcerer",
  "warlock",
  "wizard",
] as const;

function includesString(allowed: readonly string[], value: string): boolean {
  return allowed.includes(value);
}

export const roomStatus = v.union(
  v.literal("waiting"),
  v.literal("playing"),
  v.literal("paused"),
  v.literal("finished"),
  v.literal("demo_finished"),
);

export const roomLocale = v.union(
  v.literal("fr"),
  v.literal("en"),
  v.literal("de"),
  v.literal("es"),
);

export const narrativeMusicMood = v.union(
  v.literal("tavern"),
  v.literal("exploration"),
  v.literal("mystery"),
  v.literal("tension"),
);

export const gameEventType = v.union(
  v.literal("action"),
  v.literal("narration"),
  v.literal("system"),
);

export const enemyStatus = v.union(
  v.literal("active"),
  v.literal("defeated"),
  v.literal("escaped"),
);

export const abilityKey = v.union(
  v.literal("strength"),
  v.literal("dexterity"),
  v.literal("constitution"),
  v.literal("intelligence"),
  v.literal("wisdom"),
  v.literal("charisma"),
);

export const pendingRollStatus = v.union(
  v.literal("pending"),
  v.literal("resolved"),
  v.literal("cancelled"),
);

export const accessLevel = v.union(v.literal("demo"), v.literal("full"));

export const entitlementGrantSource = v.union(
  v.literal("default"),
  v.literal("purchase"),
  v.literal("admin"),
  v.literal("promo"),
);

export const entitlementProvider = v.union(
  v.literal("stripe"),
  v.literal("google_play"),
  v.literal("manual"),
);

export const entitlementSourceStatus = v.union(
  v.literal("active"),
  v.literal("pending"),
  v.literal("canceled"),
  v.literal("expired"),
  v.literal("on_hold"),
  v.literal("revoked"),
);

export const aiUsageKind = v.union(
  v.literal("game_master"),
  v.literal("scenario"),
);

export const aiCostSource = v.union(
  v.literal("none"),
  v.literal("openrouter"),
  v.literal("estimate"),
);

export const gameEndingResult = v.union(
  v.literal("victory"),
  v.literal("defeat"),
  v.literal("neutral"),
);

export const characterStat = v.number();

export function isAbilityKey(value: string): boolean {
  return includesString(ABILITY_KEYS, value);
}

export function isRoomStatus(value: string): boolean {
  return includesString(ROOM_STATUSES, value);
}

export function isFigurineId(value: number): boolean {
  return Number.isInteger(value) && value >= 0 && value <= 39;
}

export function isStatInRange(value: number): boolean {
  return Number.isInteger(value) && value >= 8 && value <= 18;
}

export function isNormalizedPosition(value: number): boolean {
  return value >= 0 && value <= 1;
}

export function isPendingRollDc(value: number): boolean {
  return Number.isInteger(value) && value >= 5 && value <= 25;
}

export function isDisplayName(value: string): boolean {
  const trimmed = value.trim();
  return trimmed.length >= 2 && trimmed.length <= 32;
}

export function isPendingRollDie(value: number): boolean {
  return Number.isInteger(value) && value >= 1 && value <= 20;
}

export function isCharacterClassId(value: string): boolean {
  return includesString(CHARACTER_CLASS_IDS, value);
}
