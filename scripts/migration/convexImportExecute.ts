import { spawn } from "node:child_process";
import { computeGlobalEntitlement } from "../../convex/lib/entitlements";
import type { ConvexImportPlan } from "./convexImportPlan";

export class ConvexImportExecuteError extends Error {
  readonly code: string;
  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

export type ImportWriter = {
  calls: string[];
  upsertUser: (row: ConvexImportPlan["users"][number]) => Promise<string>;
  upsertProfile: (row: ConvexImportPlan["profiles"][number]) => Promise<string>;
  upsertSource: (row: ConvexImportPlan["entitlementSources"][number]) => Promise<string>;
  recomputeEntitlement: (userLegacyUuid: string) => Promise<{
    accessLevel: "demo" | "full";
    source: string;
  }>;
  upsertRoom: (row: ConvexImportPlan["rooms"][number]) => Promise<string>;
  upsertPlayer: (row: ConvexImportPlan["players"][number]) => Promise<string>;
  upsertGmState: (row: ConvexImportPlan["roomGmState"][number]) => Promise<void>;
  upsertEventBatch: (rows: ConvexImportPlan["eventBatches"][number]) => Promise<number>;
  upsertEnemy: (row: ConvexImportPlan["enemies"][number]) => Promise<string>;
  upsertCombat: (row: ConvexImportPlan["combatSessions"][number]) => Promise<string>;
  upsertRoll: (row: ConvexImportPlan["pendingRolls"][number]) => Promise<string>;
  upsertDemo: (row: ConvexImportPlan["demoSessions"][number]) => Promise<string>;
};

export function assertConvexExecuteAllowed(args: {
  execute: boolean;
  dryRunFlag: boolean;
  target?: string;
  deployment?: string;
  confirm?: string;
}): { deployment: string } {
  if (args.dryRunFlag && args.execute) {
    throw new ConvexImportExecuteError(
      "EXECUTE_DRY_RUN_CONFLICT",
      "convex-import refuses --execute together with --dry-run",
    );
  }
  if (!args.execute) {
    throw new ConvexImportExecuteError(
      "EXECUTE_REQUIRED",
      "convex-import writes only when --execute is explicitly set",
    );
  }
  const deployment = String(args.deployment ?? "").trim();
  const target = String(args.target ?? "").trim();
  const confirm = String(args.confirm ?? "").trim();
  if (!deployment || !target) {
    throw new ConvexImportExecuteError(
      "CONVEX_TARGET_MISSING",
      "CONVEX_DEPLOYMENT and --target are required for --execute",
    );
  }
  if (/prod/i.test(deployment) || /prod/i.test(target)) {
    throw new ConvexImportExecuteError(
      "CONVEX_TARGET_PROD",
      "convex-import refuses a production Convex target",
    );
  }
  if (target !== deployment) {
    throw new ConvexImportExecuteError(
      "CONVEX_TARGET_MISMATCH",
      " --target does not match CONVEX_DEPLOYMENT",
    );
  }
  if (confirm !== deployment) {
    throw new ConvexImportExecuteError(
      "CONVEX_CONFIRM_MISMATCH",
      "CONVEX_MIGRATION_CONFIRM must equal CONVEX_DEPLOYMENT",
    );
  }
  return { deployment };
}

export async function executeConvexImportPlan(
  plan: ConvexImportPlan,
  writer: ImportWriter,
): Promise<{ writes: number }> {
  if (plan.verdict !== "CONVEX_IMPORT_READY") {
    throw new ConvexImportExecuteError(
      "PLAN_BLOCKED",
      "Refusing Convex writes for a blocked import plan",
    );
  }
  const mappedUsers = new Set(plan.users.map((row) => row.legacyUuid));
  const mappedRooms = new Set(plan.rooms.map((row) => row.legacyUuid));
  const mappedPlayers = new Set(plan.players.map((row) => row.legacyUuid));
  const requireMapped = (kind: string, legacyUuid: string, known: Set<string>) => {
    if (!known.has(legacyUuid)) {
      throw new ConvexImportExecuteError(
        "IMPORT_COLLISION",
        `Imported ${kind} parent is not in the migratable mapping`,
      );
    }
  };

  let writes = 0;
  for (const row of plan.users) {
    const id = await writer.upsertUser(row);
    if (id === row.legacyUuid || id === row.workosSubject) {
      throw new ConvexImportExecuteError(
        "LEGACY_ID_USED_AS_CONVEX_ID",
        "Convex user id must not equal a legacy or WorkOS identifier",
      );
    }
    writes += 1;
  }
  for (const row of plan.profiles) {
    requireMapped("profile", row.userLegacyUuid, mappedUsers);
    await writer.upsertProfile(row);
    writes += 1;
  }
  for (const row of plan.entitlementSources) {
    requireMapped("entitlement source", row.userLegacyUuid, mappedUsers);
    await writer.upsertSource(row);
    writes += 1;
  }
  for (const expected of plan.entitlementExpectations) {
    requireMapped("entitlement", expected.userLegacyUuid, mappedUsers);
    const computed = await writer.recomputeEntitlement(expected.userLegacyUuid);
    writes += 1;
    if (
      expected.historicalAccessLevel &&
      expected.historicalAccessLevel !== computed.accessLevel
    ) {
      throw new ConvexImportExecuteError(
        "ENTITLEMENT_RECOMPUTE_MISMATCH",
        "Recomputed entitlement diverges from historical cache",
      );
    }
  }
  for (const row of plan.rooms) {
    requireMapped("room host", row.hostLegacyUuid, mappedUsers);
    await writer.upsertRoom(row);
    writes += 1;
  }
  for (const row of plan.players) {
    requireMapped("player room", row.roomLegacyUuid, mappedRooms);
    requireMapped("player user", row.userLegacyUuid, mappedUsers);
    await writer.upsertPlayer(row);
    writes += 1;
  }
  for (const row of plan.roomGmState) {
    requireMapped("gm state room", row.roomLegacyUuid, mappedRooms);
    await writer.upsertGmState(row);
    writes += 1;
  }
  for (const batch of plan.eventBatches) {
    for (const row of batch) {
      requireMapped("event room", row.roomLegacyUuid, mappedRooms);
      if (row.playerLegacyUuid) {
        requireMapped("event player", row.playerLegacyUuid, mappedPlayers);
      }
    }
    writes += await writer.upsertEventBatch(batch);
  }
  for (const row of plan.enemies) {
    requireMapped("enemy room", row.roomLegacyUuid, mappedRooms);
    await writer.upsertEnemy(row);
    writes += 1;
  }
  for (const row of plan.combatSessions) {
    requireMapped("combat room", row.roomLegacyUuid, mappedRooms);
    await writer.upsertCombat(row);
    writes += 1;
  }
  for (const row of plan.pendingRolls) {
    requireMapped("roll room", row.roomLegacyUuid, mappedRooms);
    requireMapped("roll player", row.playerLegacyUuid, mappedPlayers);
    await writer.upsertRoll(row);
    writes += 1;
  }
  for (const row of plan.demoSessions) {
    requireMapped("demo user", row.userLegacyUuid, mappedUsers);
    if (row.roomLegacyUuid) {
      requireMapped("demo room", row.roomLegacyUuid, mappedRooms);
    }
    await writer.upsertDemo(row);
    writes += 1;
  }
  return { writes };
}

function compactArgs(value: unknown): unknown {
  return JSON.parse(JSON.stringify(value));
}

export type ImportRunContext = {
  phase: string;
  operation: string;
  legacy?: string;
  batch?: string;
};

function prefixLegacy(legacy: string): string {
  const trimmed = legacy.trim();
  return trimmed.length <= 8 ? trimmed : trimmed.slice(0, 8);
}

function sanitizeConvexOutput(text: string): string {
  let cleaned = text.replace(/\u001b\[[0-9;]*m/g, "");
  cleaned = cleaned.replace(
    /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g,
    "[redacted-email]",
  );
  cleaned = cleaned.replace(/Bearer\s+\S+/gi, "Bearer [redacted]");
  cleaned = cleaned.replace(/Authorization:\s*\S+/gi, "Authorization: [redacted]");
  cleaned = cleaned.replace(
    /\b(CONVEX_DEPLOY_KEY|CONVEX_ADMIN_KEY|API[_-]?KEY|SECRET|TOKEN)\b\s*[=:]\s*\S+/gi,
    "$1=[redacted]",
  );
  cleaned = cleaned.replace(/\bsk_[A-Za-z0-9]+\b/g, "[redacted-key]");
  cleaned = cleaned.replace(/\s+/g, " ").trim();
  if (cleaned.length > 400) {
    cleaned = `${cleaned.slice(0, 400)}…`;
  }
  return cleaned;
}

function formatImportFailure(context: ImportRunContext, remote: string): string {
  const lines = [`phase: ${context.phase}`, `operation: ${context.operation}`];
  if (context.legacy) {
    lines.push(`legacy: ${prefixLegacy(context.legacy)}`);
  }
  if (context.batch) {
    lines.push(`batch: ${context.batch}`);
  }
  lines.push(`Convex error: ${remote || "internal Convex mutation failed"}`);
  return lines.join("\n");
}

type ConvexRunFn = (
  functionName: string,
  args: unknown,
  context: ImportRunContext,
) => Promise<unknown>;

export function createConvexRunWriter(
  run: ConvexRunFn = runInternalConvexMutation,
): ImportWriter {
  return {
    calls: [],
    async upsertUser(row) {
      return (await run("internal.migrationImport.upsertUser", compactArgs(row), {
        phase: "users",
        operation: "upsertUser",
        legacy: row.legacyUuid,
      })) as string;
    },
    async upsertProfile(row) {
      return (await run("internal.migrationImport.upsertProfile", compactArgs(row), {
        phase: "profiles",
        operation: "upsertProfile",
        legacy: row.legacyUuid,
      })) as string;
    },
    async upsertSource(row) {
      return (await run(
        "internal.migrationImport.upsertEntitlementSource",
        compactArgs(row),
        {
          phase: "entitlement_sources",
          operation: "upsertEntitlementSource",
          legacy: row.legacyUuid,
        },
      )) as string;
    },
    async recomputeEntitlement(userLegacyUuid) {
      return (await run(
        "internal.migrationImport.recomputeUserEntitlement",
        { userLegacyUuid },
        {
          phase: "user_entitlements",
          operation: "recomputeUserEntitlement",
          legacy: userLegacyUuid,
        },
      )) as { accessLevel: "demo" | "full"; source: string };
    },
    async upsertRoom(row) {
      return (await run("internal.migrationImport.upsertRoom", compactArgs(row), {
        phase: "rooms",
        operation: "upsertRoom",
        legacy: row.legacyUuid,
      })) as string;
    },
    async upsertPlayer(row) {
      return (await run("internal.migrationImport.upsertPlayer", compactArgs(row), {
        phase: "players",
        operation: "upsertPlayer",
        legacy: row.legacyUuid,
      })) as string;
    },
    async upsertGmState(row) {
      await run("internal.migrationImport.upsertGmState", compactArgs(row), {
        phase: "room_gm_state",
        operation: "upsertGmState",
        legacy: row.roomLegacyUuid,
      });
    },
    async upsertEventBatch(rows) {
      return (await run(
        "internal.migrationImport.upsertEventBatch",
        { events: compactArgs(rows) },
        {
          phase: "game_events",
          operation: "upsertEventBatch",
          legacy: rows[0]?.legacyUuid,
          batch: `${rows.length} events`,
        },
      )) as number;
    },
    async upsertEnemy(row) {
      return (await run("internal.migrationImport.upsertEnemy", compactArgs(row), {
        phase: "enemies",
        operation: "upsertEnemy",
        legacy: row.legacyUuid,
      })) as string;
    },
    async upsertCombat(row) {
      return (await run("internal.migrationImport.upsertCombat", compactArgs(row), {
        phase: "combat_sessions",
        operation: "upsertCombat",
        legacy: row.legacyUuid,
      })) as string;
    },
    async upsertRoll(row) {
      return (await run("internal.migrationImport.upsertRoll", compactArgs(row), {
        phase: "pending_rolls",
        operation: "upsertRoll",
        legacy: row.legacyUuid,
      })) as string;
    },
    async upsertDemo(row) {
      return (await run("internal.migrationImport.upsertDemo", compactArgs(row), {
        phase: "demo_sessions",
        operation: "upsertDemo",
        legacy: row.legacyUuid,
      })) as string;
    },
  };
}

export function convexRunCliArgv(functionName: string, args: unknown): string[] {
  return ["convex", "run", functionName, JSON.stringify(args)];
}

type SpawnImpl = (
  command: string,
  argv: string[],
  options: { stdio: ["ignore", "pipe", "pipe"] },
) => ReturnType<typeof spawn>;

export function runInternalConvexMutation(
  functionName: string,
  args: unknown,
  context: ImportRunContext = {
    phase: "unknown",
    operation: functionName,
  },
  spawnImpl: SpawnImpl = spawn,
): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const child = spawnImpl("npx", convexRunCliArgv(functionName, args), {
      stdio: ["ignore", "pipe", "pipe"],
    });
    const childStdout = child.stdout;
    const childStderr = child.stderr;
    if (!childStdout || !childStderr) {
      reject(
        new ConvexImportExecuteError(
          "CONVEX_RUN_FAILED",
          formatImportFailure(context, "convex run pipes were missing"),
        ),
      );
      return;
    }
    let stdout = "";
    let stderr = "";
    childStdout.on("data", (chunk: Buffer) => {
      stdout += chunk.toString("utf8");
    });
    childStderr.on("data", (chunk: Buffer) => {
      stderr += chunk.toString("utf8");
    });
    child.on("error", (error) => {
      reject(
        new ConvexImportExecuteError(
          "CONVEX_RUN_FAILED",
          formatImportFailure(context, sanitizeConvexOutput(error.message)),
        ),
      );
    });
    child.on("close", (code) => {
      if (code !== 0) {
        reject(
          new ConvexImportExecuteError(
            "CONVEX_RUN_FAILED",
            formatImportFailure(
              context,
              sanitizeConvexOutput(`${stderr}\n${stdout}`),
            ),
          ),
        );
        return;
      }
      const trimmed = stdout.trim();
      if (!trimmed) {
        resolve(undefined);
        return;
      }
      try {
        resolve(JSON.parse(trimmed) as unknown);
      } catch {
        resolve(trimmed);
      }
    });
  });
}

export function createMemoryWriter(): ImportWriter & {
  ids: {
    users: Map<string, string>;
    rooms: Map<string, string>;
    players: Map<string, string>;
  };
  sourcesLookedUpGlobally: string[];
  entitlementsCopiedFromCache: boolean;
  aiUsageImported: number;
} {
  const calls: string[] = [];
  const users = new Map<string, string>();
  const rooms = new Map<string, string>();
  const players = new Map<string, string>();
  const docs = new Map<string, Record<string, unknown>>();
  const sourcesByUser = new Map<string, ConvexImportPlan["entitlementSources"]>();
  const sourcesLookedUpGlobally: string[] = [];
  let seq = 0;
  const nextId = (table: string, legacy: string) => {
    seq += 1;
    const id = `conv_${table}_${seq}`;
    if (id === legacy) {
      throw new Error("generated id collided with legacy uuid");
    }
    return id;
  };
  const upsert = (table: string, legacy: string, payload: Record<string, unknown>) => {
    const key = `${table}:${legacy}`;
    const existing = docs.get(key);
    const nextParent = payload.parent;
    if (nextParent === undefined || nextParent === null || nextParent === "") {
      throw new ConvexImportExecuteError(
        "IMPORT_COLLISION",
        "Imported document parent is missing from the Convex id map",
      );
    }
    if (existing) {
      if (existing.parent !== nextParent) {
        throw new ConvexImportExecuteError(
          "IMPORT_COLLISION",
          "Imported document collides with a different parent",
        );
      }
      calls.push(`${table}:skip`);
      return String(existing.id);
    }
    const id = nextId(table, legacy);
    docs.set(key, { id, ...payload });
    calls.push(`${table}:insert`);
    return id;
  };
  return {
    calls,
    sourcesLookedUpGlobally,
    entitlementsCopiedFromCache: false,
    aiUsageImported: 0,
    ids: { users, rooms, players },
    async upsertUser(row) {
      const id = upsert("users", row.legacyUuid, {
        parent: row.workosSubject,
        workosSubject: row.workosSubject,
        legacyUuid: row.legacyUuid,
      });
      users.set(row.legacyUuid, id);
      return id;
    },
    async upsertProfile(row) {
      return upsert("profiles", row.legacyUuid, { parent: users.get(row.userLegacyUuid) });
    },
    async upsertSource(row) {
      const list = sourcesByUser.get(row.userLegacyUuid) ?? [];
      list.push(row);
      sourcesByUser.set(row.userLegacyUuid, list);
      return upsert("entitlementSources", row.legacyUuid, {
        parent: users.get(row.userLegacyUuid),
        providerRef: row.providerRef,
      });
    },
    async recomputeEntitlement(userLegacyUuid) {
      calls.push("userEntitlements:recompute");
      const computed = computeGlobalEntitlement({
        sources: (sourcesByUser.get(userLegacyUuid) ?? []).map((row) => ({
          provider: row.provider,
          status: row.status,
          currentPeriodEnd: row.currentPeriodEnd,
        })),
      });
      return { accessLevel: computed.accessLevel, source: computed.source };
    },
    async upsertRoom(row) {
      const id = upsert("rooms", row.legacyUuid, { parent: users.get(row.hostLegacyUuid) });
      rooms.set(row.legacyUuid, id);
      return id;
    },
    async upsertPlayer(row) {
      const id = upsert("players", row.legacyUuid, { parent: rooms.get(row.roomLegacyUuid) });
      players.set(row.legacyUuid, id);
      return id;
    },
    async upsertGmState(row) {
      upsert("roomGmState", row.roomLegacyUuid, { parent: rooms.get(row.roomLegacyUuid) });
    },
    async upsertEventBatch(rows) {
      for (const row of rows) {
        upsert("gameEvents", row.legacyUuid, { parent: rooms.get(row.roomLegacyUuid) });
      }
      return rows.length;
    },
    async upsertEnemy(row) {
      return upsert("enemies", row.legacyUuid, { parent: rooms.get(row.roomLegacyUuid) });
    },
    async upsertCombat(row) {
      return upsert("combatSessions", row.legacyUuid, { parent: rooms.get(row.roomLegacyUuid) });
    },
    async upsertRoll(row) {
      return upsert("pendingRolls", row.legacyUuid, { parent: players.get(row.playerLegacyUuid) });
    },
    async upsertDemo(row) {
      return upsert("demoSessions", row.legacyUuid, { parent: users.get(row.userLegacyUuid) });
    },
  };
}
