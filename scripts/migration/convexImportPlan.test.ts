// @vitest-environment node
import { EventEmitter } from "node:events";
import { describe, expect, test, vi } from "vitest";
import { runCli } from "./cli";
import {
  assertConvexExecuteAllowed,
  convexRunCliArgv,
  createMemoryWriter,
  executeConvexImportPlan,
  runInternalConvexMutation,
} from "./convexImportExecute";
import { buildConvexImportPlan, EVENT_BATCH_SIZE } from "./convexImportPlan";
import type { MigrationBundle, SanitizedAuthUser, WorkosMapping } from "./types";

const EMAIL = "11111111-1111-4111-8111-111111111111";
const ANON = "22222222-2222-4222-8222-222222222222";
const ROOM = "44444444-4444-4444-8444-444444444444";
const DEMO_ROOM = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1";
const PLAYER = "55555555-5555-4555-8555-555555555555";
const ANON_PLAYER = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1";

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

function mappingFor(
  entries: WorkosMapping["entries"],
  verdict: WorkosMapping["verdict"] = "WORKOS_MAP_PASS",
): WorkosMapping {
  return {
    version: "lot12-b3",
    generated_at: "2026-01-01T00:00:00.000Z",
    verdict,
    entries,
    findings: [],
  };
}

function validBundle(): MigrationBundle {
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
    user_entitlements: [
      { user_id: EMAIL, access_level: "full", source: "purchase" },
      { user_id: ANON, access_level: "demo", source: "default" },
    ],
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
      {
        id: ANON_PLAYER,
        room_id: DEMO_ROOM,
        user_id: ANON,
        figurine_id: 2,
        figurine_name: "Guest",
      },
    ],
    room_gm_state: [],
    game_events: [
      {
        id: "evt-1",
        room_id: ROOM,
        player_id: PLAYER,
        type: "action",
        content: "looks around",
      },
      {
        id: "evt-demo",
        room_id: DEMO_ROOM,
        type: "system",
        content: "demo tick",
      },
    ],
    enemies: [],
    combat_sessions: [],
    pending_rolls: [],
    demo_sessions: [
      { id: "demo-email", user_id: EMAIL, room_id: ROOM },
      { id: "demo-anon", user_id: ANON, room_id: DEMO_ROOM },
    ],
    ai_usage_events: [
      { id: "ai-1", user_id: EMAIL, room_id: ROOM, kind: "game_master" },
    ],
  };
}

const validMapping = mappingFor([
  {
    legacy_user_id: EMAIL,
    email: "alice@example.com",
    status: "EXISTING_WORKOS_USER",
    workos_user_id: "user_01ALICE",
  },
]);

describe("LOT 12 B4 Convex import plan", () => {
  test("anonymous dataset is excluded", () => {
    const plan = buildConvexImportPlan(validBundle(), validMapping);
    expect(plan.verdict).toBe("CONVEX_IMPORT_READY");
    expect(plan.users.map((row) => row.legacyUuid)).toEqual([EMAIL]);
    expect(plan.rooms.map((row) => row.legacyUuid)).toEqual([ROOM]);
    expect(plan.players.map((row) => row.legacyUuid)).toEqual([PLAYER]);
    expect(plan.counts.archived_rooms).toBe(1);
  });

  test("mapped WorkOS users are required", () => {
    const plan = buildConvexImportPlan(validBundle(), validMapping);
    expect(plan.users).toHaveLength(1);
    expect(plan.users[0]?.workosSubject).toBe("user_01ALICE");
    expect(plan.users[0]?.legacyUuid).toBe(EMAIL);
  });

  test("missing WorkOS mapping is BLOCKED", () => {
    const plan = buildConvexImportPlan(
      validBundle(),
      mappingFor([
        {
          legacy_user_id: EMAIL,
          email: "alice@example.com",
          status: "NOT_FOUND",
          workos_user_id: null,
        },
      ]),
    );
    expect(plan.verdict).toBe("CONVEX_IMPORT_BLOCKED");
    expect(plan.findings.some((item) => item.code === "WORKOS_MAPPING_MISSING")).toBe(true);
  });

  test("planned users keep legacyUuid and WorkOS subject", () => {
    const plan = buildConvexImportPlan(validBundle(), validMapping);
    expect(plan.users[0]).toMatchObject({
      legacyUuid: EMAIL,
      workosSubject: "user_01ALICE",
    });
  });

  test("FK remaps stay on legacy keys for Convex to rewrite", () => {
    const plan = buildConvexImportPlan(validBundle(), validMapping);
    expect(plan.rooms[0]?.hostLegacyUuid).toBe(EMAIL);
    expect(plan.players[0]?.roomLegacyUuid).toBe(ROOM);
    expect(plan.players[0]?.userLegacyUuid).toBe(EMAIL);
    expect(plan.eventBatches[0]?.[0]?.playerLegacyUuid).toBe(PLAYER);
  });

  test("archived demos are absent from the plan", () => {
    const plan = buildConvexImportPlan(validBundle(), validMapping);
    expect(plan.rooms.some((row) => row.scenarioId === "demo")).toBe(false);
    expect(plan.demoSessions.map((row) => row.legacyUuid)).toEqual(["demo-email"]);
  });

  test("ai_usage_events are not imported", () => {
    const plan = buildConvexImportPlan(validBundle(), validMapping);
    expect(plan.counts.ai_usage_events).toBe(0);
  });

  test("waiting room without gm_state is accepted", () => {
    const plan = buildConvexImportPlan(validBundle(), validMapping);
    expect(plan.rooms[0]?.status).toBe("waiting");
    expect(plan.roomGmState).toEqual([]);
    expect(plan.verdict).toBe("CONVEX_IMPORT_READY");
  });

  test("custom playing without gm_state is refused before write", () => {
    const bundle = validBundle();
    bundle.rooms[0]!.status = "playing";
    bundle.rooms[0]!.scenario_id = "custom";
    const plan = buildConvexImportPlan(bundle, validMapping);
    expect(plan.verdict).toBe("CONVEX_IMPORT_BLOCKED");
    expect(plan.findings.some((item) => item.code === "INCOMPLETE_ROOM_GRAPH")).toBe(true);
  });

  test("event batches are split", () => {
    const bundle = validBundle();
    bundle.game_events = Array.from({ length: EVENT_BATCH_SIZE + 3 }, (_, index) => ({
      id: `evt-${index}`,
      room_id: ROOM,
      type: "system" as const,
      content: `n${index}`,
    }));
    const plan = buildConvexImportPlan(bundle, validMapping);
    expect(plan.counts.game_events).toBe(EVENT_BATCH_SIZE + 3);
    expect(plan.eventBatches).toHaveLength(2);
    expect(plan.eventBatches[0]).toHaveLength(EVENT_BATCH_SIZE);
    expect(plan.eventBatches[1]).toHaveLength(3);
  });

  test("historical user_entitlements are not the import authority", () => {
    const plan = buildConvexImportPlan(validBundle(), validMapping);
    expect(plan.entitlementSources).toHaveLength(1);
    expect(plan.entitlementExpectations[0]?.computedAccessLevel).toBe("full");
    expect(plan.entitlementExpectations[0]?.computedSource).toBe("purchase");
  });

  test("Play legacyUuid stays on the planned user", () => {
    const bundle = validBundle();
    bundle.entitlement_sources[0] = {
      id: "src-play",
      user_id: EMAIL,
      provider: "google_play",
      provider_ref: "fp_alice",
      status: "active",
    };
    const plan = buildConvexImportPlan(bundle, validMapping);
    expect(plan.users[0]?.legacyUuid).toBe(EMAIL);
    expect(plan.entitlementSources[0]?.provider).toBe("google_play");
  });
});

describe("LOT 12 B4 Convex import execute gates", () => {
  test("memory execute remaps FKs to non-legacy ids and is idempotent", async () => {
    const plan = buildConvexImportPlan(validBundle(), validMapping);
    const writer = createMemoryWriter();
    const first = await executeConvexImportPlan(plan, writer);
    const second = await executeConvexImportPlan(plan, writer);
    const userId = writer.ids.users.get(EMAIL);
    const roomId = writer.ids.rooms.get(ROOM);
    const playerId = writer.ids.players.get(PLAYER);
    expect(userId).toBeTruthy();
    expect(userId).not.toBe(EMAIL);
    expect(userId).not.toBe("user_01ALICE");
    expect(roomId).not.toBe(ROOM);
    expect(playerId).not.toBe(PLAYER);
    expect(first.writes).toBeGreaterThan(0);
    expect(second.writes).toBe(first.writes);
    const inserts = writer.calls.filter((item) => item.endsWith(":insert"));
    const skips = writer.calls.filter((item) => item.endsWith(":skip"));
    const recomputes = writer.calls.filter(
      (item) => item === "userEntitlements:recompute",
    );
    expect(recomputes).toHaveLength(plan.entitlementExpectations.length * 2);
    expect(inserts).toHaveLength(first.writes - plan.entitlementExpectations.length);
    expect(skips).toHaveLength(inserts.length);
    expect(writer.entitlementsCopiedFromCache).toBe(false);
    expect(writer.aiUsageImported).toBe(0);
    expect(writer.sourcesLookedUpGlobally).toEqual([]);
  });

  test("incompatible parent collision is BLOCKED", async () => {
    const plan = buildConvexImportPlan(validBundle(), validMapping);
    const writer = createMemoryWriter();
    await executeConvexImportPlan(plan, writer);
    const collided = {
      ...plan,
      rooms: plan.rooms.map((row) => ({ ...row, hostLegacyUuid: ANON })),
    };
    await expect(executeConvexImportPlan(collided, writer)).rejects.toMatchObject({
      code: "IMPORT_COLLISION",
    });
  });

  test("blocked plan performs zero writes", async () => {
    const plan = buildConvexImportPlan(
      validBundle(),
      mappingFor([
        {
          legacy_user_id: EMAIL,
          email: "alice@example.com",
          status: "NOT_FOUND",
          workos_user_id: null,
        },
      ]),
    );
    const writer = createMemoryWriter();
    await expect(executeConvexImportPlan(plan, writer)).rejects.toMatchObject({
      code: "PLAN_BLOCKED",
    });
    expect(writer.calls).toEqual([]);
  });

  test("wrong Convex target performs zero writes", () => {
    expect(() =>
      assertConvexExecuteAllowed({
        execute: true,
        dryRunFlag: false,
        target: "dev:other",
        deployment: "dev:dragonslair",
        confirm: "dev:dragonslair",
      }),
    ).toThrow(/does not match/);
  });

  test("production target is refused", () => {
    expect(() =>
      assertConvexExecuteAllowed({
        execute: true,
        dryRunFlag: false,
        target: "prod:dragonslair",
        deployment: "prod:dragonslair",
        confirm: "prod:dragonslair",
      }),
    ).toThrow(/production/);
  });

  test("without --execute execute is refused", () => {
    expect(() =>
      assertConvexExecuteAllowed({
        execute: false,
        dryRunFlag: true,
        target: "dev:dragonslair",
        deployment: "dev:dragonslair",
        confirm: "dev:dragonslair",
      }),
    ).toThrow(/--execute/);
  });
});

describe("LOT 12 B4 CLI dry-run", () => {
  test("convex-import without --execute does not call fetch or execute", async () => {
    const fetchMock = vi.fn();
    const bundle = validBundle();
    const { writeMigrationExport } = await import("./writeExport");
    const { writeWorkosMapping } = await import("./writeWorkosMapping");
    const { mkdtempSync, rmSync } = await import("node:fs");
    const { tmpdir } = await import("node:os");
    const { join } = await import("node:path");
    const exportDir = mkdtempSync(join(tmpdir(), "jdr-b4-export-"));
    const mapDir = mkdtempSync(join(tmpdir(), "jdr-b4-map-"));
    writeMigrationExport(exportDir, bundle);
    writeWorkosMapping(mapDir, validMapping);
    const result = await runCli(
      [
        "node",
        "cli.ts",
        "convex-import",
        "--dir",
        exportDir,
        "--mapping-dir",
        mapDir,
      ],
      fetchMock,
      {
        createImportWriter: () => {
          throw new Error("writer must not be created");
        },
      },
    );
    rmSync(exportDir, { recursive: true, force: true });
    rmSync(mapDir, { recursive: true, force: true });
    expect(fetchMock).not.toHaveBeenCalled();
    expect(result.stdout).toContain("CONVEX_IMPORT_READY");
    expect(result.stdout).toContain("mode: dry-run (zero Convex writes)");
    expect(result.stdout).not.toContain("alice@example.com");
    expect(result.code).toBe(0);
  });

  test("convex-import --dry-run does not create a Convex writer", async () => {
    const fetchMock = vi.fn();
    const bundle = validBundle();
    const { writeMigrationExport } = await import("./writeExport");
    const { writeWorkosMapping } = await import("./writeWorkosMapping");
    const { mkdtempSync, rmSync } = await import("node:fs");
    const { tmpdir } = await import("node:os");
    const { join } = await import("node:path");
    const exportDir = mkdtempSync(join(tmpdir(), "jdr-b4-dry-"));
    const mapDir = mkdtempSync(join(tmpdir(), "jdr-b4-drymap-"));
    writeMigrationExport(exportDir, bundle);
    writeWorkosMapping(mapDir, validMapping);
    const result = await runCli(
      [
        "node",
        "cli.ts",
        "convex-import",
        "--dry-run",
        "--dir",
        exportDir,
        "--mapping-dir",
        mapDir,
      ],
      fetchMock,
      {
        createImportWriter: () => {
          throw new Error("writer must not be created");
        },
      },
    );
    rmSync(exportDir, { recursive: true, force: true });
    rmSync(mapDir, { recursive: true, force: true });
    expect(fetchMock).not.toHaveBeenCalled();
    expect(result.stdout).toContain("mode: dry-run (zero Convex writes)");
    expect(result.stdout).toContain("CONVEX_IMPORT_READY");
    expect(result.stdout).not.toContain("DRY_RUN_PASS");
    expect(result.code).toBe(0);
  });

  test("convex-import --execute with a production target does not create a writer", async () => {
    const fetchMock = vi.fn();
    const bundle = validBundle();
    const { writeMigrationExport } = await import("./writeExport");
    const { writeWorkosMapping } = await import("./writeWorkosMapping");
    const { mkdtempSync, rmSync } = await import("node:fs");
    const { tmpdir } = await import("node:os");
    const { join } = await import("node:path");
    const exportDir = mkdtempSync(join(tmpdir(), "jdr-b4-prod-"));
    const mapDir = mkdtempSync(join(tmpdir(), "jdr-b4-prodmap-"));
    writeMigrationExport(exportDir, bundle);
    writeWorkosMapping(mapDir, validMapping);
    let writerCreated = false;
    await expect(
      runCli(
        [
          "node",
          "cli.ts",
          "convex-import",
          "--execute",
          "--target",
          "prod:dragonslair",
          "--dir",
          exportDir,
          "--mapping-dir",
          mapDir,
        ],
        fetchMock,
        {
          env: {
            CONVEX_DEPLOYMENT: "prod:dragonslair",
            CONVEX_MIGRATION_CONFIRM: "prod:dragonslair",
          } as NodeJS.ProcessEnv,
          createImportWriter: () => {
            writerCreated = true;
            throw new Error("writer must not be created");
          },
        },
      ),
    ).rejects.toThrow(/production/);
    rmSync(exportDir, { recursive: true, force: true });
    rmSync(mapDir, { recursive: true, force: true });
    expect(writerCreated).toBe(false);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test("four migratable users require four WorkOS mappings", () => {
    const ids = [
      EMAIL,
      "aaaaaaa1-1111-4111-8111-111111111111",
      "aaaaaaa2-1111-4111-8111-111111111111",
      "aaaaaaa3-1111-4111-8111-111111111111",
    ];
    const bundle = validBundle();
    bundle.auth_users = ids.map((id, index) =>
      authUser(id, {
        email: `user${index}@example.com`,
        is_anonymous: false,
        email_confirmed_at: "2026-01-01T00:00:00.000Z",
      }),
    );
    bundle.profiles = ids.map((id) => ({ id, display_name: "Hero" }));
    const incomplete = mappingFor(
      ids.slice(0, 3).map((id, index) => ({
        legacy_user_id: id,
        email: `user${index}@example.com`,
        status: "EXISTING_WORKOS_USER" as const,
        workos_user_id: `user_0${index}`,
      })),
    );
    expect(buildConvexImportPlan(bundle, incomplete).verdict).toBe(
      "CONVEX_IMPORT_BLOCKED",
    );
    const complete = mappingFor(
      ids.map((id, index) => ({
        legacy_user_id: id,
        email: `user${index}@example.com`,
        status: "EXISTING_WORKOS_USER" as const,
        workos_user_id: `user_0${index}`,
      })),
    );
    const plan = buildConvexImportPlan(bundle, complete);
    expect(plan.verdict).toBe("CONVEX_IMPORT_READY");
    expect(plan.users).toHaveLength(4);
  });

  test("convex-import --execute --dry-run refuses before any writer", async () => {
    const fetchMock = vi.fn();
    const bundle = validBundle();
    const { writeMigrationExport } = await import("./writeExport");
    const { writeWorkosMapping } = await import("./writeWorkosMapping");
    const { mkdtempSync, rmSync } = await import("node:fs");
    const { tmpdir } = await import("node:os");
    const { join } = await import("node:path");
    const exportDir = mkdtempSync(join(tmpdir(), "jdr-b4-conflict-"));
    const mapDir = mkdtempSync(join(tmpdir(), "jdr-b4-conflictmap-"));
    writeMigrationExport(exportDir, bundle);
    writeWorkosMapping(mapDir, validMapping);
    let writerCreated = false;
    await expect(
      runCli(
        [
          "node",
          "cli.ts",
          "convex-import",
          "--dry-run",
          "--execute",
          "--target",
          "dev:dragonslair",
          "--dir",
          exportDir,
          "--mapping-dir",
          mapDir,
        ],
        fetchMock,
        {
          env: {
            CONVEX_DEPLOYMENT: "dev:dragonslair",
            CONVEX_MIGRATION_CONFIRM: "dev:dragonslair",
          } as NodeJS.ProcessEnv,
          createImportWriter: () => {
            writerCreated = true;
            return createMemoryWriter();
          },
        },
      ),
    ).rejects.toThrow(/--execute together with --dry-run|--dry-run/);
    rmSync(exportDir, { recursive: true, force: true });
    rmSync(mapDir, { recursive: true, force: true });
    expect(writerCreated).toBe(false);
    expect(fetchMock).not.toHaveBeenCalled();
  });
});

describe("LOT 12 B4 Convex CLI invocation", () => {
  test("spawn argv uses positional JSON and never --args", async () => {
    const functionName = "internal.migrationImport.upsertUser";
    const args = { legacyUuid: "11111111-1111-4111-8111-111111111111" };
    const expected = [
      "convex",
      "run",
      functionName,
      JSON.stringify(args),
    ];
    expect(convexRunCliArgv(functionName, args)).toEqual(expected);
    expect(convexRunCliArgv(functionName, args)).not.toContain("--args");

    let captured: string[] | undefined;
    const child = new EventEmitter() as EventEmitter & {
      stdout: EventEmitter;
      stderr: EventEmitter;
    };
    child.stdout = new EventEmitter();
    child.stderr = new EventEmitter();
    await new Promise<void>((resolve, reject) => {
      void runInternalConvexMutation(
        functionName,
        args,
        { phase: "users", operation: "upsertUser", legacy: args.legacyUuid },
        (_command, argv) => {
          captured = argv;
          queueMicrotask(() => {
            child.stdout.emit("data", Buffer.from('"ok"'));
            child.emit("close", 0);
          });
          return child as never;
        },
      ).then(() => resolve(), reject);
    });
    expect(captured).toEqual(expected);
    expect(captured).not.toContain("--args");
  });
});
