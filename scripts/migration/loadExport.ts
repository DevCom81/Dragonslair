import { readFileSync } from "node:fs";
import { join } from "node:path";
import { sanitizeAuthUser, stripForbiddenFields } from "./sanitize";
import { EXPORT_VERSION, type Manifest, type MigrationBundle } from "./types";

const DATA_FILES = [
  "auth_users.sanitized.json",
  "profiles.json",
  "entitlement_sources.json",
  "user_entitlements.json",
  "rooms.json",
  "players.json",
  "room_gm_state.json",
  "game_events.json",
  "enemies.json",
  "combat_sessions.json",
  "pending_rolls.json",
  "demo_sessions.json",
  "ai_usage_events.json",
] as const;

function readJson(dir: string, name: string): unknown {
  const raw = readFileSync(join(dir, name), "utf8");
  return JSON.parse(raw) as unknown;
}

function asArray(value: unknown, label: string): unknown[] {
  if (!Array.isArray(value)) {
    throw new Error(`${label} must be a JSON array`);
  }
  return value;
}

export function loadMigrationDir(dir: string): MigrationBundle {
  const manifestRaw = stripForbiddenFields(readJson(dir, "manifest.json"));
  const manifest =
    manifestRaw !== null && typeof manifestRaw === "object" && !Array.isArray(manifestRaw)
      ? (manifestRaw as Manifest)
      : { version: EXPORT_VERSION, exported_at: "", table_counts: {} };

  const authRaw = asArray(readJson(dir, "auth_users.sanitized.json"), "auth_users");
  const auth_users = authRaw
    .map((row) => sanitizeAuthUser(row))
    .filter((row): row is NonNullable<typeof row> => row !== null);

  return {
    manifest,
    auth_users,
    profiles: asArray(readJson(dir, "profiles.json"), "profiles") as MigrationBundle["profiles"],
    entitlement_sources: asArray(
      readJson(dir, "entitlement_sources.json"),
      "entitlement_sources",
    ) as MigrationBundle["entitlement_sources"],
    user_entitlements: asArray(
      readJson(dir, "user_entitlements.json"),
      "user_entitlements",
    ) as MigrationBundle["user_entitlements"],
    rooms: asArray(readJson(dir, "rooms.json"), "rooms") as MigrationBundle["rooms"],
    players: asArray(readJson(dir, "players.json"), "players") as MigrationBundle["players"],
    room_gm_state: asArray(
      readJson(dir, "room_gm_state.json"),
      "room_gm_state",
    ) as MigrationBundle["room_gm_state"],
    game_events: asArray(
      readJson(dir, "game_events.json"),
      "game_events",
    ) as MigrationBundle["game_events"],
    enemies: asArray(readJson(dir, "enemies.json"), "enemies") as MigrationBundle["enemies"],
    combat_sessions: asArray(
      readJson(dir, "combat_sessions.json"),
      "combat_sessions",
    ) as MigrationBundle["combat_sessions"],
    pending_rolls: asArray(
      readJson(dir, "pending_rolls.json"),
      "pending_rolls",
    ) as MigrationBundle["pending_rolls"],
    demo_sessions: asArray(
      readJson(dir, "demo_sessions.json"),
      "demo_sessions",
    ) as MigrationBundle["demo_sessions"],
    ai_usage_events: asArray(
      readJson(dir, "ai_usage_events.json"),
      "ai_usage_events",
    ) as MigrationBundle["ai_usage_events"],
  };
}

export { DATA_FILES };
