// @vitest-environment node
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, test, vi } from "vitest";
import { playObfuscatedAccountId } from "./classify";
import { runCli } from "./cli";
import { runDryRun } from "./dryRun";
import { sanitizeAuthUser } from "./sanitize";
import type { MigrationBundle, SanitizedAuthUser } from "./types";
import { writeMigrationExport } from "./writeExport";

const EMAIL = "11111111-1111-4111-8111-111111111111";
const ANON = "22222222-2222-4222-8222-222222222222";
const PAYING_ANON = "33333333-3333-4333-8333-333333333333";
const OTHER_EMAIL = "66666666-6666-4666-8666-666666666666";
const ROOM = "44444444-4444-4444-8444-444444444444";
const PLAYER = "55555555-5555-4555-8555-555555555555";
const ORPHAN = "99999999-9999-4999-8999-999999999999";

function authUser(
  id: string,
  args: Partial<SanitizedAuthUser> = {},
): SanitizedAuthUser {
  return {
    id,
    email: null,
    is_anonymous: true,
    created_at: "2026-01-01T00:00:00.000Z",
    email_confirmed_at: null,
    deleted_at: null,
    ...args,
  };
}

function validBundle(): MigrationBundle {
  return {
    manifest: {
      version: "lot12-b1",
      exported_at: "2026-01-01T00:00:00.000Z",
      table_counts: {},
    },
    auth_users: [
      authUser(EMAIL, {
        email: "alice@example.com",
        is_anonymous: false,
        email_confirmed_at: "2026-01-01T00:00:00.000Z",
      }),
      authUser(ANON),
    ],
    profiles: [
      { id: EMAIL, display_name: "Alice" },
      { id: ANON, display_name: "Guest" },
    ],
    entitlement_sources: [
      {
        id: "src-stripe-1",
        user_id: EMAIL,
        provider: "stripe",
        provider_ref: "cs_test_alice",
        status: "active",
        metadata: { provider: "stripe", stripe_session_id: "cs_test_alice" },
      },
    ],
    user_entitlements: [
      { user_id: EMAIL, access_level: "full", source: "purchase" },
      { user_id: ANON, access_level: "demo", source: "default" },
    ],
    rooms: [
      {
        id: ROOM,
        name: "Quest",
        status: "playing",
        host_id: EMAIL,
        join_code: "ABC123",
        scenario_id: "custom",
      },
    ],
    players: [
      {
        id: PLAYER,
        room_id: ROOM,
        user_id: EMAIL,
        figurine_id: 1,
        figurine_name: "Alice",
      },
    ],
    room_gm_state: [{ room_id: ROOM, gm_secrets: [], gm_state: {} }],
    game_events: [],
    enemies: [],
    combat_sessions: [
      { id: "combat-1", room_id: ROOM, active: true, round: 1 },
    ],
    pending_rolls: [],
    demo_sessions: [
      {
        id: "demo-1",
        user_id: EMAIL,
        room_id: ROOM,
        started_at: "2026-01-01T00:00:00.000Z",
        expires_at: "2026-01-01T00:10:00.000Z",
        paused_at: null,
        completed_at: null,
      },
    ],
    ai_usage_events: [],
  };
}

const tempDirs: string[] = [];

afterEach(() => {
  while (tempDirs.length > 0) {
    const dir = tempDirs.pop();
    if (dir) {
      rmSync(dir, { recursive: true, force: true });
    }
  }
});

function tempDir(): string {
  const dir = mkdtempSync(join(tmpdir(), "jdr-mig-"));
  tempDirs.push(dir);
  return dir;
}

describe("LOT 12 B1 dry-run", () => {
  test("valid dataset is DRY_RUN_PASS", () => {
    const report = runDryRun(validBundle());
    expect(report.verdict).toBe("DRY_RUN_PASS");
    expect(report.category_counts.migratable_email).toBe(1);
    expect(report.category_counts.ignored_anonymous).toBe(1);
  });

  test("orphan FK is CRITICAL and BLOCKED", () => {
    const bundle = validBundle();
    bundle.players[0]!.room_id = ORPHAN;
    const report = runDryRun(bundle);
    expect(report.verdict).toBe("DRY_RUN_BLOCKED");
    expect(report.findings.some((item) => item.code === "ORPHAN_FK")).toBe(true);
  });

  test("duplicate email is ambiguous and BLOCKED", () => {
    const bundle = validBundle();
    bundle.auth_users.push(
      authUser(OTHER_EMAIL, {
        email: "alice@example.com",
        is_anonymous: false,
      }),
    );
    const report = runDryRun(bundle);
    expect(report.classified_users[EMAIL]).toBe("ambiguous_identity");
    expect(report.classified_users[OTHER_EMAIL]).toBe("ambiguous_identity");
    expect(report.verdict).toBe("DRY_RUN_BLOCKED");
  });

  test("anonymous without value is ignored", () => {
    const report = runDryRun(validBundle());
    expect(report.classified_users[ANON]).toBe("ignored_anonymous");
  });

  test("anonymous with purchase is ignored and ANONYMOUS_PAID_SOURCE", () => {
    const bundle = validBundle();
    bundle.auth_users.push(authUser(PAYING_ANON));
    bundle.entitlement_sources.push({
      id: "src-play-1",
      user_id: PAYING_ANON,
      provider: "google_play",
      provider_ref: "fp_unique_pay",
      status: "active",
      metadata: { play_account_id: playObfuscatedAccountId(PAYING_ANON) },
    });
    const report = runDryRun(bundle);
    expect(report.classified_users[PAYING_ANON]).toBe("ignored_anonymous");
    expect(report.category_counts.pending_identity_link).toBe(0);
    expect(
      report.findings.some((item) => item.code === "ANONYMOUS_PAID_SOURCE"),
    ).toBe(true);
    expect(report.verdict).toBe("DRY_RUN_BLOCKED");
  });

  test("shared Play providerRef is CRITICAL", () => {
    const bundle = validBundle();
    bundle.auth_users.push(
      authUser(OTHER_EMAIL, {
        email: "bob@example.com",
        is_anonymous: false,
      }),
    );
    bundle.entitlement_sources.push(
      {
        id: "src-play-a",
        user_id: EMAIL,
        provider: "google_play",
        provider_ref: "fp_shared",
        status: "active",
        metadata: { play_account_id: playObfuscatedAccountId(EMAIL) },
      },
      {
        id: "src-play-b",
        user_id: OTHER_EMAIL,
        provider: "google_play",
        provider_ref: "fp_shared",
        status: "active",
        metadata: { play_account_id: playObfuscatedAccountId(OTHER_EMAIL) },
      },
    );
    const report = runDryRun(bundle);
    expect(report.findings.some((item) => item.code === "PLAY_REF_SHARED")).toBe(
      true,
    );
    expect(report.verdict).toBe("DRY_RUN_BLOCKED");
  });

  test("shared Stripe cs_* is CRITICAL", () => {
    const bundle = validBundle();
    bundle.auth_users.push(
      authUser(OTHER_EMAIL, {
        email: "bob@example.com",
        is_anonymous: false,
      }),
    );
    bundle.entitlement_sources.push({
      id: "src-stripe-2",
      user_id: OTHER_EMAIL,
      provider: "stripe",
      provider_ref: "cs_test_alice",
      status: "active",
    });
    const report = runDryRun(bundle);
    expect(report.findings.some((item) => item.code === "STRIPE_CS_SHARED")).toBe(
      true,
    );
    expect(report.verdict).toBe("DRY_RUN_BLOCKED");
  });

  test("shared Stripe legacy is not an identity collision", () => {
    const bundle = validBundle();
    bundle.auth_users.push(
      authUser(OTHER_EMAIL, {
        email: "bob@example.com",
        is_anonymous: false,
      }),
    );
    bundle.entitlement_sources = [
      {
        id: "src-legacy-1",
        user_id: EMAIL,
        provider: "stripe",
        provider_ref: "legacy",
        status: "active",
      },
      {
        id: "src-legacy-2",
        user_id: OTHER_EMAIL,
        provider: "stripe",
        provider_ref: "legacy",
        status: "active",
      },
    ];
    const report = runDryRun(bundle);
    expect(report.findings.some((item) => item.code === "STRIPE_CS_SHARED")).toBe(
      false,
    );
    expect(
      report.findings.some((item) => item.code === "STRIPE_LEGACY_NON_GLOBAL_REF"),
    ).toBe(true);
    expect(report.verdict).toBe("DRY_RUN_PASS");
  });

  test("Play source hash for another user is CRITICAL", () => {
    const bundle = validBundle();
    bundle.entitlement_sources.push({
      id: "src-play-bad",
      user_id: EMAIL,
      provider: "google_play",
      provider_ref: "fp_bad",
      status: "active",
      metadata: { play_account_id: playObfuscatedAccountId(ANON) },
    });
    const report = runDryRun(bundle);
    expect(
      report.findings.some((item) => item.code === "PLAY_ACCOUNT_MISMATCH"),
    ).toBe(true);
    expect(report.verdict).toBe("DRY_RUN_BLOCKED");
  });

  test("FULL without granting source is unresolved not auto-fixed", () => {
    const bundle = validBundle();
    bundle.entitlement_sources = [];
    const report = runDryRun(bundle);
    expect(report.unresolved_entitlements).toContain(EMAIL);
    expect(
      report.findings.some((item) => item.code === "UNRESOLVED_ENTITLEMENT"),
    ).toBe(true);
  });

  test("demo session fields are accepted without transformation", () => {
    const report = runDryRun(validBundle());
    expect(report.table_counts.demo_sessions).toBe(1);
    expect(validBundle().demo_sessions[0]?.expires_at).toBe(
      "2026-01-01T00:10:00.000Z",
    );
  });

  test("complete playing room passes", () => {
    const report = runDryRun(validBundle());
    expect(report.room_status_counts.playing).toBe(1);
    expect(report.verdict).toBe("DRY_RUN_PASS");
  });

  test("anonymous demo only is ignored and PASS", () => {
    const report = runDryRun(validBundle());
    expect(report.classified_users[ANON]).toBe("ignored_anonymous");
    expect(report.verdict).toBe("DRY_RUN_PASS");
    expect(report.pending_identity_link).toEqual([]);
  });

  test("anonymous playing demo without gm_state is archived PASS", () => {
    const bundle = validBundle();
    const demoRoom = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1";
    bundle.rooms.push({
      id: demoRoom,
      name: "Demo",
      status: "playing",
      host_id: ANON,
      scenario_id: "demo",
    });
    bundle.players.push({
      id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1",
      room_id: demoRoom,
      user_id: ANON,
      figurine_id: 2,
      figurine_name: "Guest",
    });
    const report = runDryRun(bundle);
    expect(report.classified_users[ANON]).toBe("ignored_anonymous");
    expect(report.findings.some((item) => item.code === "INCOMPLETE_ROOM_GRAPH")).toBe(
      false,
    );
    expect(
      report.findings.some((item) => item.code === "ANONYMOUS_DATA_ARCHIVED"),
    ).toBe(true);
    expect(report.archived_counts.rooms).toBe(1);
    expect(report.migratable_counts.rooms).toBe(1);
    expect(report.verdict).toBe("DRY_RUN_PASS");
  });

  test("anonymous demo with events combat and resolved rolls is archived PASS", () => {
    const bundle = validBundle();
    const demoRoom = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2";
    const demoPlayer = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2";
    bundle.rooms.push({
      id: demoRoom,
      name: "Demo",
      status: "playing",
      host_id: ANON,
      scenario_id: "demo",
    });
    bundle.players.push({
      id: demoPlayer,
      room_id: demoRoom,
      user_id: ANON,
      figurine_id: 2,
      figurine_name: "Guest",
    });
    bundle.game_events.push({
      id: "evt-1",
      room_id: demoRoom,
      player_id: demoPlayer,
      type: "action",
      content: "looks around",
    });
    bundle.enemies.push({
      id: "en-1",
      room_id: demoRoom,
      name: "Rat",
      enemy_type: "beast",
      status: "active",
    });
    bundle.combat_sessions.push({
      id: "combat-demo",
      room_id: demoRoom,
      active: true,
      round: 1,
    });
    bundle.pending_rolls.push({
      id: "roll-1",
      room_id: demoRoom,
      player_id: demoPlayer,
      ability: "strength",
      dc: 10,
      status: "resolved",
    });
    const report = runDryRun(bundle);
    expect(report.findings.some((item) => item.code === "ORPHAN_FK")).toBe(false);
    expect(report.findings.some((item) => item.code === "INCOMPLETE_ROOM_GRAPH")).toBe(
      false,
    );
    expect(report.archived_counts.game_events).toBe(1);
    expect(report.migratable_counts.game_events).toBe(0);
    expect(report.verdict).toBe("DRY_RUN_PASS");
  });

  test("anonymous Stripe active source is CRITICAL", () => {
    const bundle = validBundle();
    bundle.auth_users.push(authUser(PAYING_ANON));
    bundle.entitlement_sources.push({
      id: "src-anon-stripe",
      user_id: PAYING_ANON,
      provider: "stripe",
      provider_ref: "cs_anon",
      status: "active",
    });
    const report = runDryRun(bundle);
    expect(report.classified_users[PAYING_ANON]).toBe("ignored_anonymous");
    expect(
      report.findings.some((item) => item.code === "ANONYMOUS_PAID_SOURCE"),
    ).toBe(true);
    expect(report.verdict).toBe("DRY_RUN_BLOCKED");
  });

  test("email playing custom with gm_state is migrable PASS", () => {
    const report = runDryRun(validBundle());
    expect(report.classified_users[EMAIL]).toBe("migratable_email");
    expect(report.migratable_counts.rooms).toBe(1);
    expect(report.migratable_counts.auth_users).toBe(1);
    expect(report.verdict).toBe("DRY_RUN_PASS");
  });

  test("anonymous excluded data does not create migratable FK orphans", () => {
    const bundle = validBundle();
    const demoRoom = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3";
    bundle.rooms.push({
      id: demoRoom,
      name: "Demo",
      status: "paused",
      host_id: ANON,
      scenario_id: "demo",
    });
    bundle.players.push({
      id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3",
      room_id: demoRoom,
      user_id: ANON,
      figurine_id: 3,
      figurine_name: "Guest",
    });
    bundle.game_events.push({
      id: "evt-orphan-check",
      room_id: demoRoom,
      type: "system",
      content: "tick",
    });
    const report = runDryRun(bundle);
    expect(report.orphans).toEqual([]);
    expect(report.findings.some((item) => item.code === "ORPHAN_USER")).toBe(false);
    expect(report.findings.some((item) => item.code === "ORPHAN_FK")).toBe(false);
    expect(report.source_counts.rooms).toBe(2);
    expect(report.migratable_counts.rooms).toBe(1);
    expect(report.archived_counts.rooms).toBe(1);
    expect(report.verdict).toBe("DRY_RUN_PASS");
  });

  test("source vs migratable counts stay distinct", () => {
    const report = runDryRun(validBundle());
    expect(report.source_counts.auth_users).toBe(2);
    expect(report.migratable_counts.auth_users).toBe(1);
    expect(report.archived_counts.auth_users).toBe(1);
    expect(report.source_counts.profiles).toBe(2);
    expect(report.migratable_counts.profiles).toBe(1);
    expect(report.table_counts.auth_users).toBe(report.source_counts.auth_users);
  });

  test("playing room without gm state is BLOCKED", () => {
    const bundle = validBundle();
    bundle.room_gm_state = [];
    const report = runDryRun(bundle);
    expect(report.verdict).toBe("DRY_RUN_BLOCKED");
    expect(
      report.findings.some((item) => item.code === "INCOMPLETE_ROOM_GRAPH"),
    ).toBe(true);
  });

  test("sanitized auth never keeps password or tokens", () => {
    const sanitized = sanitizeAuthUser({
      id: EMAIL,
      email: "alice@example.com",
      is_anonymous: false,
      created_at: "2026-01-01T00:00:00.000Z",
      encrypted_password: "hash",
      recovery_token: "tok",
      identities: [{ provider: "email", identity_data: { email: "a" } }],
    });
    expect(sanitized).toEqual({
      id: EMAIL,
      email: "alice@example.com",
      is_anonymous: false,
      created_at: "2026-01-01T00:00:00.000Z",
      email_confirmed_at: null,
      deleted_at: null,
    });
    const dir = tempDir();
    writeMigrationExport(dir, validBundle());
    const raw = readFileSync(join(dir, "auth_users.sanitized.json"), "utf8");
    expect(raw).not.toContain("encrypted_password");
    expect(raw).not.toContain("recovery_token");
    expect(raw).not.toContain("refresh_token");
  });

  test("dry-run CLI does not call fetch or accept import", async () => {
    const dir = tempDir();
    writeMigrationExport(dir, validBundle());
    const fetchMock = vi.fn();
    await expect(
      runCli(["node", "cli.ts", "import", "--dir", dir], fetchMock),
    ).rejects.toThrow("LOT 12 refuses a generic import");
    const result = await runCli(
      ["node", "cli.ts", "--dry-run", "--dir", dir],
      fetchMock,
    );
    expect(fetchMock).not.toHaveBeenCalled();
    expect(result.stdout).toContain("DRY_RUN_PASS");
    expect(result.code).toBe(0);
  });
});
