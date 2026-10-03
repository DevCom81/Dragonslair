import { afterEach, describe, expect, test, vi } from "vitest";
import { convexTest } from "convex-test";
import type { MutationCtx } from "./_generated/server";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { ForbiddenError, RateLimitedError } from "./lib/errors";
import { UnauthenticatedError } from "./lib/auth";

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
const carol = {
  subject: "user_01CAROL",
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
const wizardSheet = {
  displayName: "Myrddin",
  classId: "wizard",
  strength: 8,
  dexterity: 10,
  constitution: 12,
  intelligence: 16,
  wisdom: 14,
  charisma: 10,
};
const clericSheet = {
  displayName: "Clara",
  classId: "cleric",
  strength: 10,
  dexterity: 8,
  constitution: 14,
  intelligence: 10,
  wisdom: 16,
  charisma: 12,
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

async function playingRoom(t: ReturnType<typeof backend>, full = true) {
  const host = await provision(t, alice, fighterSheet, full);
  const room = await host.mutation(api.rooms.create, {
    name: "GM",
    scenarioId: full ? "custom" : "demo",
    scenarioName: "GM",
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

function openRouterResponse(args: {
  status?: number;
  narration?: string;
  actions?: unknown[];
  content?: string;
  usage?: Record<string, unknown>;
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
      usage: args.usage ?? {
        prompt_tokens: 12,
        completion_tokens: 4,
        cost: 0.001,
      },
      choices: [{ message: { content } }],
    }),
  };
}

afterEach(() => {
  vi.unstubAllGlobals();
  delete process.env.OPENROUTER_API_KEY;
  delete process.env.RATE_LIMIT_PER_MINUTE;
  delete process.env.RATE_LIMIT_PER_HOUR;
});

describe("LOT 7 game master", () => {
  test("unauthenticated respond is refused", async () => {
    const t = backend();
    const a = await playingRoom(t);
    await expect(
      t.action(api.gameMaster.respond, {
        roomId: a.room._id,
        action: "Look around.",
      }),
    ).rejects.toThrow(UnauthenticatedError);
  });

  test("stranger cannot load another room context", async () => {
    const t = backend();
    const a = await playingRoom(t);
    const outsider = await provision(t, carol, clericSheet);
    await expect(
      outsider.query(internal.gameMaster.loadTurnContext, {
        roomId: a.room._id,
        action: "Look around.",
      }),
    ).rejects.toThrow(ForbiddenError);
  });

  test("demo host can play GM; context is room-scoped", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    const t = backend();
    const demo = await playingRoom(t, false);
    const other = await playingRoom(t, true);
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => openRouterResponse({ narration: "A door creaks." })),
    );
    const response = await demo.host.action(api.gameMaster.respond, {
      roomId: demo.room._id,
      action: "Inspect the barrel.",
    });
    expect(response.narration).toBe("A door creaks.");
    const events = await demo.host.query(api.gameEvents.listByRoom, {
      roomId: demo.room._id,
    });
    expect(events.some((row) => row.content === "A door creaks.")).toBe(true);
    const otherEvents = await other.host.query(api.gameEvents.listByRoom, {
      roomId: other.room._id,
    });
    expect(otherEvents.some((row) => row.content === "A door creaks.")).toBe(
      false,
    );
  });

  test("valid actions go through applyActions; other-room refs no-op", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    const t = backend();
    const a = await playingRoom(t);
    const other = await playingRoom(t);
    await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: other.room._id,
      actions: [{ type: "spawn_enemy", payload: { name: "Spy", hp: 8 } }],
    });
    const otherEnemies = await other.host.query(api.enemies.listByRoom, {
      roomId: other.room._id,
    });
    vi.stubGlobal(
      "fetch",
      vi.fn(async () =>
        openRouterResponse({
          narration: "An orc steps forward.",
          actions: [
            { type: "spawn_enemy", payload: { name: "Orc", hp: 12 } },
            {
              type: "damage_enemy",
              payload: { enemy_id: otherEnemies[0]!._id, amount: 7 },
            },
          ],
        }),
      ),
    );
    await a.host.action(api.gameMaster.respond, {
      roomId: a.room._id,
      action: "Draw steel.",
    });
    const mine = await a.host.query(api.enemies.listByRoom, {
      roomId: a.room._id,
    });
    expect(mine).toHaveLength(1);
    expect(mine[0]?.name).toBe("Orc");
    const still = await other.host.query(api.enemies.listByRoom, {
      roomId: other.room._id,
    });
    expect(still[0]?.hp).toBe(8);
  });

  test("invalid JSON records usage and does not persist narration", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    const t = backend();
    const a = await playingRoom(t);
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => openRouterResponse({ content: "not-json" })),
    );
    await expect(
      a.host.action(api.gameMaster.respond, {
        roomId: a.room._id,
        action: "Wait.",
      }),
    ).rejects.toThrow(/invalid JSON/);
    const events = await a.host.query(api.gameEvents.listByRoom, {
      roomId: a.room._id,
    });
    expect(events).toEqual([]);
    const usage = await t.run(async (ctx: MutationCtx) => {
      return await ctx.db.query("aiUsageEvents").collect();
    });
    expect(usage).toHaveLength(1);
    expect(usage[0]?.inputTokens).toBe(12);
  });

  test("unknown action type does not apply engine effects", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    const t = backend();
    const a = await playingRoom(t);
    vi.stubGlobal(
      "fetch",
      vi.fn(async () =>
        openRouterResponse({
          narration: "Nope",
          actions: [{ type: "explode", payload: {} }],
        }),
      ),
    );
    await expect(
      a.host.action(api.gameMaster.respond, {
        roomId: a.room._id,
        action: "Cast.",
      }),
    ).rejects.toThrow(/invalid game master payload/);
    const enemies = await a.host.query(api.enemies.listByRoom, {
      roomId: a.room._id,
    });
    expect(enemies).toEqual([]);
  });

  test("resolveRoll uses server dice result in the GM prompt", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    const t = backend();
    const a = await playingRoom(t);
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
    const rolls = await a.host.query(api.pendingRolls.listByRoom, {
      roomId: a.room._id,
    });
    const fetchMock = vi.fn(async (_url: string, init?: RequestInit) => {
      const body = JSON.parse(String(init?.body ?? "{}")) as {
        messages: Array<{ content: string }>;
      };
      expect(body.messages[1]?.content).toContain("ROLL RESULT");
      expect(body.messages[1]?.content).toContain('"raw":12');
      expect(body.messages[1]?.content).toContain('"success":true');
      expect(body.messages[1]?.content).not.toContain('"success":false');
      return openRouterResponse({ narration: "The door yields." });
    });
    vi.stubGlobal("fetch", fetchMock);
    const response = await a.host.action(api.gameMaster.resolveRoll, {
      pendingRollId: rolls[0]!._id,
      raw: 12,
    });
    expect(response.narration).toBe("The door yields.");
    expect(fetchMock).toHaveBeenCalled();
  });

  test("successful turn records ai usage tokens", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    const t = backend();
    const a = await playingRoom(t);
    vi.stubGlobal(
      "fetch",
      vi.fn(async () =>
        openRouterResponse({
          narration: "A torch flares.",
          usage: { prompt_tokens: 50, completion_tokens: 9, cost: 0.002 },
        }),
      ),
    );
    await a.host.action(api.gameMaster.respond, {
      roomId: a.room._id,
      action: "Light a torch.",
    });
    const usage = await t.run(async (ctx: MutationCtx) => {
      return await ctx.db.query("aiUsageEvents").collect();
    });
    expect(usage).toHaveLength(1);
    expect(usage[0]?.kind).toBe("game_master");
    expect(usage[0]?.inputTokens).toBe(50);
    expect(usage[0]?.outputTokens).toBe(9);
    expect(usage[0]?.cost).toBe(0.002);
    expect(usage[0]?.costSource).toBe("openrouter");
    expect(usage[0]?.roomId).toBe(a.room._id);
  });

  test("rate limit under default allows a turn", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    const t = backend();
    const a = await playingRoom(t);
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => openRouterResponse({ narration: "Ok." })),
    );
    await expect(
      a.host.action(api.gameMaster.respond, {
        roomId: a.room._id,
        action: "Nod.",
      }),
    ).resolves.toMatchObject({ narration: "Ok." });
  });

  test("rate limit exceeded is RATE_LIMITED", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    process.env.RATE_LIMIT_PER_MINUTE = "2";
    process.env.RATE_LIMIT_PER_HOUR = "100";
    const t = backend();
    const a = await playingRoom(t);
    await t.run(async (ctx: MutationCtx) => {
      const now = Date.now();
      for (let index = 0; index < 2; index += 1) {
        await ctx.db.insert("aiUsageEvents", {
          userId: a.player.userId,
          roomId: a.room._id,
          model: "m",
          kind: "game_master",
          costSource: "none",
          createdAt: now - 1000,
        });
      }
    });
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => openRouterResponse({ narration: "Should not run." })),
    );
    await expect(
      a.host.action(api.gameMaster.respond, {
        roomId: a.room._id,
        action: "Again.",
      }),
    ).rejects.toThrow(RateLimitedError);
    const events = await a.host.query(api.gameEvents.listByRoom, {
      roomId: a.room._id,
    });
    expect(events).toEqual([]);
  });

  test("OpenRouter HTTP error does not persist engine changes", async () => {
    process.env.OPENROUTER_API_KEY = "test-key";
    const t = backend();
    const a = await playingRoom(t);
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => openRouterResponse({ status: 502, narration: "no" })),
    );
    await expect(
      a.host.action(api.gameMaster.respond, {
        roomId: a.room._id,
        action: "Attack.",
      }),
    ).rejects.toThrow(/status 502/);
    const usage = await t.run(async (ctx: MutationCtx) => {
      return await ctx.db.query("aiUsageEvents").collect();
    });
    expect(usage).toEqual([]);
    const enemies = await a.host.query(api.enemies.listByRoom, {
      roomId: a.room._id,
    });
    expect(enemies).toEqual([]);
  });

  test("memory is updated after enough events", async () => {
    const t = backend();
    const a = await playingRoom(t);
    await t.run(async (ctx: MutationCtx) => {
      const now = Date.now();
      for (let index = 0; index < 19; index += 1) {
        await ctx.db.insert("gameEvents", {
          roomId: a.room._id,
          type: "narration",
          content: `fait ${index}`,
          createdAt: now + index,
        });
      }
    });
    await t.mutation(internal.gameMaster.persistGmResponse, {
      roomId: a.room._id,
      narration: "fait 19",
      actions: [],
    });
    const gm = await t.run(async (ctx: MutationCtx) => {
      const rows = await ctx.db
        .query("roomGmState")
        .withIndex("by_room", (q) => q.eq("roomId", a.room._id))
        .collect();
      return rows[0];
    });
    expect(gm?.gmState).toMatchObject({
      summarized_event_count: 12,
    });
  });
});
