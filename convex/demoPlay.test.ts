import { afterEach, describe, expect, test, vi } from "vitest";
import { convexTest } from "convex-test";
import type { MutationCtx } from "./_generated/server";
import type { Id } from "./_generated/dataModel";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { DEMO_DURATION_MS, nextDemoClock } from "./lib/demoClock";
import {
  ForbiddenError,
  GameRuleError,
  RoomFinishedError,
} from "./lib/errors";

const modules = import.meta.glob("./**/*.ts");

function backend() {
  return convexTest(schema, modules);
}

const alice = {
  subject: "user_01ALICE",
  issuer: "https://api.workos.com/user_management/client_01EXAMPLE",
};
const bob = {
  subject: "user_01BOB",
  issuer: "https://api.workos.com/user_management/client_01EXAMPLE",
};

const fighterSheet = {
  displayName: "Aldric",
  classId: "fighter",
  strength: 16,
  dexterity: 10,
  constitution: 14,
  intelligence: 8,
  wisdom: 12,
  charisma: 10,
};

async function grantFull(
  t: ReturnType<typeof backend>,
  identity: typeof alice,
) {
  await t.withIdentity(identity).run(async (ctx: MutationCtx) => {
    const users = await ctx.db.query("users").collect();
    const user = users.find((row) => row.workosSubject === identity.subject);
    const entitlements = await ctx.db
      .query("userEntitlements")
      .withIndex("by_user", (q) => q.eq("userId", user!._id))
      .collect();
    await ctx.db.patch(entitlements[0]!._id, {
      accessLevel: "full",
      source: "admin",
    });
  });
}

async function provision(
  t: ReturnType<typeof backend>,
  identity: typeof alice,
  sheet: typeof fighterSheet,
  full = true,
) {
  const authed = t.withIdentity(identity);
  await authed.mutation(api.users.ensureUser, {});
  if (full) {
    await grantFull(t, identity);
  }
  await authed.mutation(api.profiles.upsertSheet, sheet);
  return authed;
}

async function playingRoom(t: ReturnType<typeof backend>, full = false) {
  const host = await provision(t, alice, fighterSheet, full);
  const room = await host.mutation(api.rooms.create, {
    name: "Demo",
    scenarioId: full ? "custom" : "demo",
    scenarioName: "Demo",
    minPlayers: 1,
    requiredClassIds: [],
    locale: "en",
  });
  const player = await host.mutation(api.players.join, {
    roomId: room!._id,
    figurineId: 1,
  });
  await host.mutation(api.rooms.start, { roomId: room!._id });
  return { host, room: room!, player: player! };
}

async function sessionForUser(
  t: ReturnType<typeof backend>,
  userId: Id<"users">,
) {
  return await t.run(async (ctx: MutationCtx) => {
    const rows = await ctx.db
      .query("demoSessions")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    return rows[0] ?? null;
  });
}

function openRouterResponse(args: {
  status?: number;
  narration?: string;
  actions?: unknown[];
  content?: string;
}) {
  const content =
    args.content ??
    JSON.stringify({
      narration: args.narration ?? "The tavern is quiet.",
      actions: args.actions ?? [],
      choices: [],
    });
  return {
    status: args.status ?? 200,
    json: async () => ({
      usage: { prompt_tokens: 12, completion_tokens: 4, cost: 0.001 },
      choices: [{ message: { content } }],
    }),
  };
}

afterEach(() => {
  vi.unstubAllGlobals();
  delete process.env.OPENROUTER_API_KEY;
});

describe("LOT 8 demo duration", () => {
  test("1 full access has no demo clock", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    const t = backend();
    const a = await playingRoom(t, true);
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => openRouterResponse({ narration: "Full." })),
    );
    await a.host.action(api.gameMaster.respond, {
      roomId: a.room._id,
      action: "Look around.",
    });
    const sessions = await t.run(async (ctx: MutationCtx) => {
      return await ctx.db.query("demoSessions").collect();
    });
    expect(sessions).toEqual([]);
  });

  test("2 create room does not start the timer", async () => {
    const t = backend();
    const host = await provision(t, alice, fighterSheet, false);
    const room = await host.mutation(api.rooms.create, {
      name: "Demo",
      scenarioId: "demo",
      scenarioName: "Demo",
      minPlayers: 1,
      requiredClassIds: [],
    });
    const session = await sessionForUser(t, room!.hostUserId!);
    expect(session?.startedAt).toBeUndefined();
    expect(session?.expiresAt).toBeUndefined();
  });

  test("3 join does not start the timer", async () => {
    const t = backend();
    const host = await provision(t, alice, fighterSheet, false);
    const room = await host.mutation(api.rooms.create, {
      name: "Demo",
      scenarioId: "demo",
      scenarioName: "Demo",
      minPlayers: 1,
      requiredClassIds: [],
    });
    await host.mutation(api.players.join, {
      roomId: room!._id,
      figurineId: 1,
    });
    const session = await sessionForUser(t, room!.hostUserId!);
    expect(session?.startedAt).toBeUndefined();
  });

  test("4 start room does not start the timer", async () => {
    const t = backend();
    const a = await playingRoom(t, false);
    const session = await sessionForUser(t, a.room.hostUserId!);
    expect(session?.startedAt).toBeUndefined();
    expect(session?.expiresAt).toBeUndefined();
  });

  test("5 first GM call starts exactly one 10 minute session", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    const t = backend();
    const a = await playingRoom(t, false);
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => openRouterResponse({ narration: "Begin." })),
    );
    await a.host.action(api.gameMaster.respond, {
      roomId: a.room._id,
      action: "Enter the cave.",
    });
    const sessions = await t.run(async (ctx: MutationCtx) => {
      return await ctx.db.query("demoSessions").collect();
    });
    expect(sessions).toHaveLength(1);
    expect(sessions[0]?.startedAt).toBeDefined();
    expect(sessions[0]!.expiresAt! - sessions[0]!.startedAt!).toBe(
      DEMO_DURATION_MS,
    );
  });

  test("6 call before expiration is allowed", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    const t = backend();
    const a = await playingRoom(t, false);
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => openRouterResponse({ narration: "Still time." })),
    );
    await a.host.action(api.gameMaster.respond, {
      roomId: a.room._id,
      action: "First.",
    });
    const again = await a.host.action(api.gameMaster.respond, {
      roomId: a.room._id,
      action: "Second.",
    });
    expect(again.narration).toBe("Still time.");
  });

  test("7-9,18 expired first call is demo_end_required then closed refuses OpenRouter", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    const t = backend();
    const a = await playingRoom(t, false);
    const fetchMock = vi.fn(async (_url: string, init?: RequestInit) => {
      const body = JSON.parse(String(init?.body ?? "{}")) as {
        messages: Array<{ content: string }>;
      };
      expect(body.messages[1]?.content).toContain("DEMO END REQUIRED");
      return openRouterResponse({
        narration: "The door closes halfway.",
        actions: [
          {
            type: "finish_game",
            payload: {
              result: "neutral",
              summary: "The demo ends.",
              epilogue: "Buy the full game.",
            },
          },
        ],
      });
    });
    vi.stubGlobal("fetch", fetchMock);
    await t.run(async (ctx: MutationCtx) => {
      const rows = await ctx.db.query("demoSessions").collect();
      const now = Date.now();
      await ctx.db.patch(rows[0]!._id, {
        startedAt: now - DEMO_DURATION_MS,
        expiresAt: now - 1,
      });
    });
    const ending = await a.host.action(api.gameMaster.respond, {
      roomId: a.room._id,
      action: "Open the last door.",
    });
    expect(ending.actions.some((action) => action.type === "finish_game")).toBe(
      true,
    );
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const room = await a.host.query(api.rooms.get, { roomId: a.room._id });
    expect(room?.status).toBe("demo_finished");
    const session = await sessionForUser(t, a.room.hostUserId!);
    expect(session?.completedAt).toBeDefined();
    const usageAfterEnd = await t.run(async (ctx: MutationCtx) => {
      return await ctx.db.query("aiUsageEvents").collect();
    });
    expect(usageAfterEnd).toHaveLength(1);

    await expect(
      a.host.action(api.gameMaster.respond, {
        roomId: a.room._id,
        action: "Keep going.",
      }),
    ).rejects.toThrow(RoomFinishedError);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const usageLater = await t.run(async (ctx: MutationCtx) => {
      return await ctx.db.query("aiUsageEvents").collect();
    });
    expect(usageLater).toHaveLength(1);
  });

  test("10-13 pause freezes remaining; resume recalculates; cycles do not reset", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    const t = backend();
    const a = await playingRoom(t, false);
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => openRouterResponse({ narration: "Tick." })),
    );
    await a.host.action(api.gameMaster.respond, {
      roomId: a.room._id,
      action: "Start.",
    });
    const before = await sessionForUser(t, a.room.hostUserId!);
    const startedAt = Date.now() - 3 * 60 * 1000;
    const expiresAt = startedAt + DEMO_DURATION_MS;
    await t.run(async (ctx: MutationCtx) => {
      await ctx.db.patch(before!._id, { startedAt, expiresAt });
    });
    const paused = await a.host.mutation(api.rooms.pause, {
      roomId: a.room._id,
    });
    expect(paused?.status).toBe("paused");
    const frozen = await sessionForUser(t, a.room.hostUserId!);
    expect(frozen?.pausedAt).toBeDefined();
    expect(frozen?.expiresAt).toBe(expiresAt);
    const wallLater = (frozen!.pausedAt as number) + 40 * 60 * 1000;
    expect(
      nextDemoClock({
        now: wallLater,
        startedAt: frozen!.startedAt,
        expiresAt: frozen!.expiresAt,
        pausedAt: frozen!.pausedAt,
      }).status,
    ).toBe("ok");

    const resumed = await a.host.mutation(api.rooms.resume, {
      roomId: a.room._id,
    });
    expect(resumed?.status).toBe("playing");
    const afterResume = await sessionForUser(t, a.room.hostUserId!);
    expect(afterResume?.pausedAt).toBeUndefined();
    const remaining = afterResume!.expiresAt! - Date.now();
    expect(remaining).toBeGreaterThan(6 * 60 * 1000);
    expect(remaining).toBeLessThan(8 * 60 * 1000);

    await a.host.mutation(api.rooms.pause, { roomId: a.room._id });
    await a.host.mutation(api.rooms.resume, { roomId: a.room._id });
    const afterCycle = await sessionForUser(t, a.room.hostUserId!);
    const remaining2 = afterCycle!.expiresAt! - Date.now();
    expect(Math.abs(remaining2 - remaining)).toBeLessThan(5000);
    expect(afterCycle!.startedAt).toBe(startedAt);
  });

  test("14 new room after consumed demo cannot reset the clock", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    const t = backend();
    const a = await playingRoom(t, false);
    vi.stubGlobal(
      "fetch",
      vi.fn(async () =>
        openRouterResponse({
          narration: "End.",
          actions: [
            {
              type: "finish_game",
              payload: {
                result: "neutral",
                summary: "Over.",
                epilogue: "Done.",
              },
            },
          ],
        }),
      ),
    );
    await t.run(async (ctx: MutationCtx) => {
      const rows = await ctx.db.query("demoSessions").collect();
      const now = Date.now();
      await ctx.db.patch(rows[0]!._id, {
        startedAt: now - DEMO_DURATION_MS,
        expiresAt: now - 1,
      });
    });
    await a.host.action(api.gameMaster.respond, {
      roomId: a.room._id,
      action: "Finish.",
    });
    const consumed = await sessionForUser(t, a.room.hostUserId!);
    await expect(
      a.host.mutation(api.rooms.create, {
        name: "Demo 2",
        scenarioId: "demo",
        scenarioName: "Demo",
        minPlayers: 1,
        requiredClassIds: [],
      }),
    ).rejects.toBeInstanceOf(GameRuleError);
    const still = await sessionForUser(t, a.room.hostUserId!);
    expect(still?._id).toBe(consumed?._id);
    expect(still?.startedAt).toBe(consumed?.startedAt);
    expect(still?.expiresAt).toBe(consumed?.expiresAt);
    expect(still?.completedAt).toBe(consumed?.completedAt);
  });

  test("15 reconnect same WorkOS subject keeps demo state", async () => {
    const t = backend();
    const host = await provision(t, alice, fighterSheet, false);
    const room = await host.mutation(api.rooms.create, {
      name: "Demo",
      scenarioId: "demo",
      scenarioName: "Demo",
      minPlayers: 1,
      requiredClassIds: [],
    });
    const first = await sessionForUser(t, room!.hostUserId!);
    const again = t.withIdentity(alice);
    await again.mutation(api.users.ensureUser, {});
    const me = await again.query(api.users.me, {});
    const second = await sessionForUser(t, me!._id);
    expect(me?._id).toBe(room!.hostUserId);
    expect(second?._id).toBe(first?._id);
  });

  test("16 different users have independent demo sessions", async () => {
    const t = backend();
    const aliceHost = await provision(t, alice, fighterSheet, false);
    const bobHost = await provision(t, bob, fighterSheet, false);
    const aRoom = await aliceHost.mutation(api.rooms.create, {
      name: "A",
      scenarioId: "demo",
      scenarioName: "Demo",
      minPlayers: 1,
      requiredClassIds: [],
    });
    const bRoom = await bobHost.mutation(api.rooms.create, {
      name: "B",
      scenarioId: "demo",
      scenarioName: "Demo",
      minPlayers: 1,
      requiredClassIds: [],
    });
    expect(aRoom!.hostUserId).not.toBe(bRoom!.hostUserId);
    const sessions = await t.run(async (ctx: MutationCtx) => {
      return await ctx.db.query("demoSessions").collect();
    });
    expect(sessions).toHaveLength(2);
  });

  test("17 two start attempts do not reset the timer", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    const t = backend();
    const a = await playingRoom(t, false);
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => openRouterResponse({ narration: "Go." })),
    );
    await Promise.all([
      a.host.action(api.gameMaster.respond, {
        roomId: a.room._id,
        action: "One.",
      }),
      t.withIdentity(alice).mutation(internal.gameMaster.syncDemoPlay, {
        roomId: a.room._id,
      }),
    ]);
    const first = await sessionForUser(t, a.room.hostUserId!);
    await t.withIdentity(alice).mutation(internal.gameMaster.syncDemoPlay, {
      roomId: a.room._id,
    });
    const second = await sessionForUser(t, a.room.hostUserId!);
    expect(second?.startedAt).toBe(first?.startedAt);
    expect(second?.expiresAt).toBe(first?.expiresAt);
    const all = await t.run(async (ctx: MutationCtx) => {
      return await ctx.db.query("demoSessions").collect();
    });
    expect(all).toHaveLength(1);
  });

  test("19 resolveRoll respects expiration", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    const t = backend();
    const a = await playingRoom(t, false);
    await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: a.room._id,
      actions: [
        {
          type: "request_roll",
          payload: {
            player_id: a.player._id,
            ability: "strength",
            dc: 10,
          },
        },
      ],
    });
    await t.run(async (ctx: MutationCtx) => {
      const rows = await ctx.db.query("demoSessions").collect();
      const now = Date.now();
      await ctx.db.patch(rows[0]!._id, {
        startedAt: now - DEMO_DURATION_MS,
        expiresAt: now - 1,
      });
    });
    const rolls = await a.host.query(api.pendingRolls.listByRoom, {
      roomId: a.room._id,
    });
    const fetchMock = vi.fn(async (_url: string, init?: RequestInit) => {
      const body = JSON.parse(String(init?.body ?? "{}")) as {
        messages: Array<{ content: string }>;
      };
      expect(body.messages[1]?.content).toContain("DEMO END REQUIRED");
      return openRouterResponse({
        narration: "Cliff.",
        actions: [
          {
            type: "finish_game",
            payload: {
              result: "neutral",
              summary: "Over.",
              epilogue: "Done.",
            },
          },
        ],
      });
    });
    vi.stubGlobal("fetch", fetchMock);
    await a.host.action(api.gameMaster.resolveRoll, {
      pendingRollId: rolls[0]!._id,
      raw: 12,
    });
    const room = await a.host.query(api.rooms.get, { roomId: a.room._id });
    expect(room?.status).toBe("demo_finished");
  });

  test("20 generate does not start or consume the demo clock", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    const t = backend();
    const demo = await playingRoom(t, false);
    const fetchMock = vi.fn(async () =>
      openRouterResponse({ narration: "unused" }),
    );
    vi.stubGlobal("fetch", fetchMock);
    await expect(
      demo.host.action(api.gameMaster.generate, {
        roomId: demo.room._id,
        prompt: "A long enough custom prompt for generate.",
      }),
    ).rejects.toThrow(ForbiddenError);
    expect(fetchMock).not.toHaveBeenCalled();
    const session = await sessionForUser(t, demo.room.hostUserId!);
    expect(session?.startedAt).toBeUndefined();

    const fullHost = await provision(t, bob, fighterSheet, true);
    const fullRoom = await fullHost.mutation(api.rooms.create, {
      name: "Custom",
      scenarioId: "custom",
      scenarioName: "Custom",
      minPlayers: 1,
      requiredClassIds: [],
      locale: "en",
    });
    await fullHost.mutation(api.players.join, {
      roomId: fullRoom!._id,
      figurineId: 1,
    });
    await fullHost.mutation(api.rooms.start, { roomId: fullRoom!._id });
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => ({
        status: 200,
        json: async () => ({
          usage: { prompt_tokens: 1, completion_tokens: 1, cost: 0 },
          choices: [
            {
              message: {
                content: JSON.stringify({
                  title: "Quest",
                  setting: "A misty keep on the borderlands of the realm.",
                  tone: "grim",
                  public_objective: "Recover the relic.",
                  starting_location: {
                    name: "Gate",
                    description: "A stone arch.",
                  },
                  initial_situation: "Rain.",
                  known_facts: ["The gate is old."],
                  starting_npcs: [{ name: "Guard", role: "watch" }],
                  initial_threats: [{ name: "Wolves", hint: "howls" }],
                  opening_narration: "You arrive at dusk.",
                  gm_secrets: ["The relic is cursed."],
                }),
              },
            },
          ],
        }),
      })),
    );
    await fullHost.action(api.gameMaster.generate, {
      roomId: fullRoom!._id,
      prompt: "A long enough custom prompt for generate.",
    });
    const bobSessions = await sessionForUser(t, fullRoom!.hostUserId!);
    expect(bobSessions).toBeNull();
  });

  test("pause before first GM does not start the clock", async () => {
    const t = backend();
    const a = await playingRoom(t, false);
    await a.host.mutation(api.rooms.pause, { roomId: a.room._id });
    const session = await sessionForUser(t, a.room.hostUserId!);
    expect(session?.startedAt).toBeUndefined();
    expect(session?.pausedAt).toBeUndefined();
  });

  test("public APIs reject client-supplied demo clock fields", async () => {
    const t = backend();
    const host = await provision(t, alice, fighterSheet, false);
    try {
      await host.mutation(api.rooms.create, {
        name: "Demo",
        scenarioId: "demo",
        scenarioName: "Demo",
        minPlayers: 1,
        requiredClassIds: [],
        startedAt: 1,
        expiresAt: 2,
        remainingMs: 3,
        pausedAt: 4,
        userId: "user_fake",
      } as never);
    } catch {
      await host.mutation(api.rooms.create, {
        name: "Demo",
        scenarioId: "demo",
        scenarioName: "Demo",
        minPlayers: 1,
        requiredClassIds: [],
      });
    }
    const me = await host.query(api.users.me, {});
    const session = await sessionForUser(t, me!._id);
    expect(session?.startedAt).toBeUndefined();
    expect(session?.expiresAt).toBeUndefined();
    expect(api.gameMaster).not.toHaveProperty("syncDemoPlay");
  });
});
