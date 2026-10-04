// @vitest-environment node
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, test, vi } from "vitest";
import { runCli } from "./cli";
import { archivedLegacyIds, compareMigrationAudit } from "./convexAudit";
import { buildConvexImportPlan } from "./convexImportPlan";
import type { MigrationAuditSnapshot } from "./convexAudit";
import type { MigrationBundle, SanitizedAuthUser, WorkosMapping } from "./types";
import { writeMigrationExport } from "./writeExport";
import { writeWorkosMapping } from "./writeWorkosMapping";

const EMAIL = "11111111-1111-4111-8111-111111111111";
const ANON = "22222222-2222-4222-8222-222222222222";
const ROOM = "44444444-4444-4444-8444-444444444444";
const DEMO_ROOM = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1";
const PLAYER = "55555555-5555-4555-8555-555555555555";

function authUser(id: string, args: Partial<SanitizedAuthUser> = {}): SanitizedAuthUser {
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

function bundle(): MigrationBundle {
  return {
    manifest: { version: "lot12-b1", exported_at: "2026-01-01T00:00:00.000Z", table_counts: {} },
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
        provider_ref: "legacy",
        status: "active",
      },
    ],
    user_entitlements: [{ user_id: EMAIL, access_level: "full", source: "purchase" }],
    rooms: [
      {
        id: ROOM,
        name: "Quest",
        status: "waiting",
        host_id: EMAIL,
        join_code: "ABC123",
        scenario_id: "dungeon",
      },
      {
        id: DEMO_ROOM,
        name: "Demo",
        status: "playing",
        host_id: ANON,
        join_code: "DEMO01",
        scenario_id: "demo",
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
    room_gm_state: [],
    game_events: [{ id: "evt-1", room_id: ROOM, player_id: PLAYER, type: "action", content: "looks" }],
    enemies: [],
    combat_sessions: [],
    pending_rolls: [],
    demo_sessions: [{ id: "demo-email", user_id: EMAIL, room_id: ROOM }],
    ai_usage_events: [{ id: "ai-1", user_id: EMAIL, room_id: ROOM, kind: "game_master" }],
  };
}

const mapping: WorkosMapping = {
  version: "lot12-b3",
  generated_at: "2026-01-01T00:00:00.000Z",
  verdict: "WORKOS_MAP_PASS",
  entries: [
    {
      legacy_user_id: EMAIL,
      email: "alice@example.com",
      status: "EXISTING_WORKOS_USER",
      workos_user_id: "user_01ALICE",
    },
  ],
  findings: [],
};

function happySnapshot(): MigrationAuditSnapshot {
  return {
    users: [{ convexId: "u1", workosSubject: "user_01ALICE", legacyUuid: EMAIL }],
    profiles: [{ convexId: "p1", userId: "u1", legacyUuid: EMAIL, sheetConfirmed: false }],
    sources: [
      {
        convexId: "s1",
        userId: "u1",
        provider: "stripe",
        providerRef: "legacy",
        status: "active",
        legacyUuid: "src-stripe-1",
      },
    ],
    entitlements: [{ userId: "u1", accessLevel: "full", source: "purchase" }],
    rooms: [
      { convexId: "r1", hostUserId: "u1", legacyUuid: ROOM, status: "waiting", scenarioId: "dungeon" },
    ],
    players: [{ convexId: "pl1", roomId: "r1", userId: "u1", legacyUuid: PLAYER }],
    events: [{ convexId: "e1", roomId: "r1", playerId: "pl1", legacyUuid: "evt-1" }],
    enemies: [],
    combat: [],
    rolls: [],
    gmRooms: [],
    demos: [{ convexId: "d1", userId: "u1", roomId: "r1", legacyUuid: "demo-email" }],
    aiUsageCount: 0,
  };
}

function audit(snapshot: MigrationAuditSnapshot) {
  const data = bundle();
  return compareMigrationAudit(
    buildConvexImportPlan(data, mapping),
    archivedLegacyIds(data),
    snapshot,
  );
}

describe("LOT 12 B5 post-import audit", () => {
  test("matching snapshot passes", () => {
    const report = audit(happySnapshot());
    expect(report.verdict).toBe("B5_PASS");
    expect(report.counts.users).toEqual({ expected: 1, actual: 1 });
    expect(report.archives.anonymous_users_imported).toBe(0);
    expect(report.archives.ai_usage_imported).toBe(0);
  });

  test("detects incorrect counts", () => {
    const snapshot = happySnapshot();
    snapshot.rooms = [];
    const report = audit(snapshot);
    expect(report.verdict).toBe("B5_BLOCKED");
    expect(report.findings.some((item) => item.code === "COUNT_MISMATCH")).toBe(true);
  });

  test("detects duplicate legacyUuid", () => {
    const snapshot = happySnapshot();
    snapshot.users.push({
      convexId: "u2",
      workosSubject: "user_01OTHER",
      legacyUuid: EMAIL,
    });
    const report = audit(snapshot);
    expect(report.findings.some((item) => item.code === "DUPLICATE_LEGACY_UUID")).toBe(true);
  });

  test("detects duplicate WorkOS subject", () => {
    const snapshot = happySnapshot();
    snapshot.users.push({
      convexId: "u2",
      workosSubject: "user_01ALICE",
      legacyUuid: "99999999-9999-4999-8999-999999999999",
    });
    const report = audit(snapshot);
    expect(report.findings.some((item) => item.code === "DUPLICATE_WORKOS_SUBJECT")).toBe(true);
  });

  test("detects wrong parent", () => {
    const snapshot = happySnapshot();
    snapshot.players[0]!.roomId = "r-wrong";
    snapshot.rooms.push({
      convexId: "r-wrong",
      hostUserId: "u1",
      legacyUuid: "zzzzzzzz-zzzz-4zzz-8zzz-zzzzzzzzzzzz",
      status: "waiting",
    });
    const report = audit(snapshot);
    expect(report.findings.some((item) => item.code === "WRONG_PARENT")).toBe(true);
  });

  test("detects orphan FK", () => {
    const snapshot = happySnapshot();
    snapshot.players[0]!.roomId = "missing-room";
    const report = audit(snapshot);
    expect(report.findings.some((item) => item.code === "ORPHAN_FK")).toBe(true);
  });

  test("detects entitlement divergence", () => {
    const snapshot = happySnapshot();
    snapshot.entitlements[0]!.accessLevel = "demo";
    const report = audit(snapshot);
    expect(report.findings.some((item) => item.code === "ENTITLEMENT_DIVERGENCE")).toBe(true);
  });

  test("detects anonymous import", () => {
    const snapshot = happySnapshot();
    snapshot.users.push({
      convexId: "u-anon",
      workosSubject: "user_anon",
      legacyUuid: ANON,
    });
    const report = audit(snapshot);
    expect(report.findings.some((item) => item.code === "ANONYMOUS_IMPORTED")).toBe(true);
  });

  test("Convex-native ai_usage does not count as a Supabase import", () => {
    const snapshot = happySnapshot();
    snapshot.aiUsageCount = 1;
    const report = audit(snapshot);
    expect(report.verdict).toBe("B5_PASS");
    expect(report.archives.ai_usage_imported).toBe(0);
    expect(report.archives.ai_usage_native).toBe(1);
    expect(report.findings.some((item) => item.code === "AI_USAGE_IMPORTED")).toBe(false);
  });

  test("detects custom playing without gm_state", () => {
    const snapshot = happySnapshot();
    snapshot.rooms[0]!.status = "playing";
    snapshot.rooms[0]!.scenarioId = "custom";
    snapshot.gmRooms = [];
    const report = audit(snapshot);
    expect(report.findings.some((item) => item.code === "INCOMPLETE_ROOM_GRAPH")).toBe(true);
  });

  test("waiting without gm_state is accepted", () => {
    const report = audit(happySnapshot());
    expect(report.findings.some((item) => item.code === "INCOMPLETE_ROOM_GRAPH")).toBe(false);
    expect(report.verdict).toBe("B5_PASS");
  });
});

describe("LOT 14B convex-audit target guard", () => {
  test("convex-audit production is read-only without production write confirm", async () => {
    const exportDir = mkdtempSync(join(tmpdir(), "jdr-14b-audit-"));
    const mapDir = mkdtempSync(join(tmpdir(), "jdr-14b-auditmap-"));
    writeMigrationExport(exportDir, bundle());
    writeWorkosMapping(mapDir, mapping);
    const result = await runCli(
      [
        "node",
        "cli.ts",
        "convex-audit",
        "--target",
        "prod:PLACEHOLDER_DEPLOYMENT",
        "--dir",
        exportDir,
        "--mapping-dir",
        mapDir,
      ],
      vi.fn(),
      {
        env: {
          CONVEX_DEPLOYMENT: "prod:PLACEHOLDER_DEPLOYMENT",
        } as NodeJS.ProcessEnv,
        loadAuditSnapshot: async () => happySnapshot(),
      },
    );
    rmSync(exportDir, { recursive: true, force: true });
    rmSync(mapDir, { recursive: true, force: true });
    expect(result.code).toBe(0);
    expect(result.stdout).toContain("environment: PRODUCTION");
    expect(result.stdout).toContain("production write: not requested");
    expect(result.stdout).toContain("mode: audit (read-only, zero Convex writes)");
    expect(result.stdout).toContain("B5_PASS");
  });

  test("convex-audit mismatch is refused even for production", async () => {
    const exportDir = mkdtempSync(join(tmpdir(), "jdr-14b-audmis-"));
    const mapDir = mkdtempSync(join(tmpdir(), "jdr-14b-audmismap-"));
    writeMigrationExport(exportDir, bundle());
    writeWorkosMapping(mapDir, mapping);
    await expect(
      runCli(
        [
          "node",
          "cli.ts",
          "convex-audit",
          "--target",
          "prod:PLACEHOLDER_DEPLOYMENT",
          "--dir",
          exportDir,
          "--mapping-dir",
          mapDir,
        ],
        vi.fn(),
        {
          env: {
            CONVEX_DEPLOYMENT: "prod:OTHER_DEPLOYMENT",
          } as NodeJS.ProcessEnv,
          loadAuditSnapshot: async () => {
            throw new Error("snapshot must not run");
          },
        },
      ),
    ).rejects.toThrow(/does not match/);
    rmSync(exportDir, { recursive: true, force: true });
    rmSync(mapDir, { recursive: true, force: true });
  });

  test("convex-audit without --target is refused", async () => {
    await expect(
      runCli(["node", "cli.ts", "convex-audit"], vi.fn(), {
        env: {} as NodeJS.ProcessEnv,
      }),
    ).rejects.toThrow(/CONVEX_DEPLOYMENT and --target are required for convex-audit/);
  });
});
