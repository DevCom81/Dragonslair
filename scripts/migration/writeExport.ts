import { existsSync, mkdirSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { sanitizeAuthUser, stripForbiddenFields } from "./sanitize";
import { EXPORT_VERSION, type Manifest, type MigrationBundle } from "./types";

export const EXPORT_FILENAMES = {
  manifest: "manifest.json",
  auth: "auth_users.sanitized.json",
  profiles: "profiles.json",
  entitlement_sources: "entitlement_sources.json",
  user_entitlements: "user_entitlements.json",
  rooms: "rooms.json",
  players: "players.json",
  room_gm_state: "room_gm_state.json",
  game_events: "game_events.json",
  enemies: "enemies.json",
  combat_sessions: "combat_sessions.json",
  pending_rolls: "pending_rolls.json",
  demo_sessions: "demo_sessions.json",
  ai_usage_events: "ai_usage_events.json",
} as const;

export function buildManifest(bundle: Omit<MigrationBundle, "manifest">): Manifest {
  return {
    version: EXPORT_VERSION,
    exported_at: new Date().toISOString(),
    table_counts: {
      auth_users: bundle.auth_users.length,
      profiles: bundle.profiles.length,
      entitlement_sources: bundle.entitlement_sources.length,
      user_entitlements: bundle.user_entitlements.length,
      rooms: bundle.rooms.length,
      players: bundle.players.length,
      room_gm_state: bundle.room_gm_state.length,
      game_events: bundle.game_events.length,
      enemies: bundle.enemies.length,
      combat_sessions: bundle.combat_sessions.length,
      pending_rolls: bundle.pending_rolls.length,
      demo_sessions: bundle.demo_sessions.length,
      ai_usage_events: bundle.ai_usage_events.length,
    },
  };
}

function writeJson(dir: string, name: string, payload: unknown): void {
  writeFileSync(join(dir, name), `${JSON.stringify(payload, null, 2)}\n`);
}

export function writeMigrationExport(dir: string, bundle: MigrationBundle): void {
  const staging = `${dir}.inprogress`;
  const backup = `${dir}.bak`;
  rmSync(staging, { recursive: true, force: true });
  rmSync(backup, { recursive: true, force: true });
  mkdirSync(staging, { recursive: true });
  try {
    const auth = bundle.auth_users
      .map((row) => sanitizeAuthUser(stripForbiddenFields(row)))
      .filter((row): row is NonNullable<typeof row> => row !== null);
    const data = {
      auth_users: auth,
      profiles: stripForbiddenFields(bundle.profiles),
      entitlement_sources: stripForbiddenFields(bundle.entitlement_sources),
      user_entitlements: stripForbiddenFields(bundle.user_entitlements),
      rooms: stripForbiddenFields(bundle.rooms),
      players: stripForbiddenFields(bundle.players),
      room_gm_state: stripForbiddenFields(bundle.room_gm_state),
      game_events: stripForbiddenFields(bundle.game_events),
      enemies: stripForbiddenFields(bundle.enemies),
      combat_sessions: stripForbiddenFields(bundle.combat_sessions),
      pending_rolls: stripForbiddenFields(bundle.pending_rolls),
      demo_sessions: stripForbiddenFields(bundle.demo_sessions),
      ai_usage_events: stripForbiddenFields(bundle.ai_usage_events),
    };
    writeJson(staging, EXPORT_FILENAMES.auth, data.auth_users);
    writeJson(staging, EXPORT_FILENAMES.profiles, data.profiles);
    writeJson(staging, EXPORT_FILENAMES.entitlement_sources, data.entitlement_sources);
    writeJson(staging, EXPORT_FILENAMES.user_entitlements, data.user_entitlements);
    writeJson(staging, EXPORT_FILENAMES.rooms, data.rooms);
    writeJson(staging, EXPORT_FILENAMES.players, data.players);
    writeJson(staging, EXPORT_FILENAMES.room_gm_state, data.room_gm_state);
    writeJson(staging, EXPORT_FILENAMES.game_events, data.game_events);
    writeJson(staging, EXPORT_FILENAMES.enemies, data.enemies);
    writeJson(staging, EXPORT_FILENAMES.combat_sessions, data.combat_sessions);
    writeJson(staging, EXPORT_FILENAMES.pending_rolls, data.pending_rolls);
    writeJson(staging, EXPORT_FILENAMES.demo_sessions, data.demo_sessions);
    writeJson(staging, EXPORT_FILENAMES.ai_usage_events, data.ai_usage_events);
    const manifest = buildManifest({
      auth_users: auth,
      profiles: data.profiles as MigrationBundle["profiles"],
      entitlement_sources:
        data.entitlement_sources as MigrationBundle["entitlement_sources"],
      user_entitlements: data.user_entitlements as MigrationBundle["user_entitlements"],
      rooms: data.rooms as MigrationBundle["rooms"],
      players: data.players as MigrationBundle["players"],
      room_gm_state: data.room_gm_state as MigrationBundle["room_gm_state"],
      game_events: data.game_events as MigrationBundle["game_events"],
      enemies: data.enemies as MigrationBundle["enemies"],
      combat_sessions: data.combat_sessions as MigrationBundle["combat_sessions"],
      pending_rolls: data.pending_rolls as MigrationBundle["pending_rolls"],
      demo_sessions: data.demo_sessions as MigrationBundle["demo_sessions"],
      ai_usage_events: data.ai_usage_events as MigrationBundle["ai_usage_events"],
    });
    writeJson(staging, EXPORT_FILENAMES.manifest, manifest);
    try {
      renameSync(dir, backup);
    } catch (error) {
      const code = (error as NodeJS.ErrnoException).code;
      if (code !== "ENOENT") {
        throw error;
      }
    }
    renameSync(staging, dir);
    rmSync(backup, { recursive: true, force: true });
  } catch (error) {
    rmSync(staging, { recursive: true, force: true });
    if (!existsSync(dir) && existsSync(backup)) {
      renameSync(backup, dir);
    }
    throw error;
  }
}
