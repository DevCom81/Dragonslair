import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import type { MutationCtx } from "./_generated/server";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { ForbiddenError, GameRuleError } from "./lib/errors";

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

async function playingRoom(t: ReturnType<typeof backend>) {
  const host = await provision(t, alice, fighterSheet);
  const guest = await provision(t, bob, wizardSheet);
  const room = await host.mutation(api.rooms.create, {
    name: "Engine",
    scenarioId: "custom",
    scenarioName: "Engine",
    minPlayers: 1,
    requiredClassIds: [],
    locale: "en",
  });
  const alicePlayer = await host.mutation(api.players.join, {
    roomId: room!._id,
    figurineId: 1,
  });
  const bobPlayer = await guest.mutation(api.players.join, {
    roomId: room!._id,
    figurineId: 2,
  });
  await host.mutation(api.rooms.start, { roomId: room!._id });
  return { host, guest, room: room!, alicePlayer: alicePlayer!, bobPlayer: bobPlayer! };
}

type PublicApi = typeof api;
type HasPublicApplyGameMasterActions = PublicApi extends {
  applyActions: { applyGameMasterActions: unknown };
}
  ? true
  : false;
type ForbiddenPublicEnemyKeys = Extract<
  keyof typeof api.enemies,
  "createEnemy" | "damageEnemy" | "healEnemy" | "moveEnemy" | "setEnemyStatus"
>;
type ForbiddenPublicPlayerKeys = Extract<
  keyof typeof api.players,
  "damagePlayer" | "healPlayer" | "spawnEnemy"
>;

describe("LOT 6 game engine", () => {
  test("public API does not expose GM applyActions or engine primitives", () => {
    const applyActionsIsNotPublic: HasPublicApplyGameMasterActions = false;
    const noPublicEnemyEngineMutations: ForbiddenPublicEnemyKeys extends never
      ? true
      : false = true;
    const noPublicPlayerEngineMutations: ForbiddenPublicPlayerKeys extends never
      ? true
      : false = true;
    expect(applyActionsIsNotPublic).toBe(false);
    expect(noPublicEnemyEngineMutations).toBe(true);
    expect(noPublicPlayerEngineMutations).toBe(true);
    expect(internal.applyActions.applyGameMasterActions).toBeDefined();
  });

  test("spawn, damage, defeat enemy and refuse other-room refs", async () => {
    const t = backend();
    const a = await playingRoom(t);
    const other = await playingRoom(t);

    const spawned = await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: a.room._id,
      actions: [
        {
          type: "spawn_enemy",
          payload: { name: "Orc", type: "orc", hp: 12, x: 0.2, y: 0.8 },
        },
      ],
    });
    expect(spawned[0]).toContain("Orc apparait");

    const enemies = await a.host.query(api.enemies.listByRoom, {
      roomId: a.room._id,
    });
    expect(enemies).toHaveLength(1);
    expect(enemies[0]?.hp).toBe(12);
    expect(enemies[0]?.status).toBe("active");

    await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: a.room._id,
      actions: [
        { type: "damage_enemy", payload: { enemy_id: enemies[0]!._id, amount: 4 } },
        { type: "heal_enemy", payload: { enemy_id: enemies[0]!._id, amount: 2 } },
      ],
    });
    const afterHit = await a.host.query(api.enemies.listByRoom, {
      roomId: a.room._id,
    });
    expect(afterHit[0]?.hp).toBe(10);

    const otherEnemies = await other.host.query(api.enemies.listByRoom, {
      roomId: other.room._id,
    });
    await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: other.room._id,
      actions: [{ type: "spawn_enemy", payload: { name: "Gobelin", hp: 6 } }],
    });
    const otherSpawned = await other.host.query(api.enemies.listByRoom, {
      roomId: other.room._id,
    });

    await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: a.room._id,
      actions: [
        {
          type: "damage_enemy",
          payload: { enemy_id: otherSpawned[0]!._id, amount: 3 },
        },
        {
          type: "damage_player",
          payload: { player_id: other.alicePlayer._id, amount: 10 },
        },
      ],
    });
    const still = await a.host.query(api.enemies.listByRoom, {
      roomId: a.room._id,
    });
    expect(still[0]?.hp).toBe(10);
    const otherStill = await other.host.query(api.enemies.listByRoom, {
      roomId: other.room._id,
    });
    expect(otherStill[0]?.hp).toBe(6);
    const otherPlayers = await other.host.query(api.players.listByRoom, {
      roomId: other.room._id,
    });
    expect(otherPlayers[0]?.hp).toBe(100);

    await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: a.room._id,
      actions: [
        { type: "damage_enemy", payload: { name: "Orc", amount: 20 } },
      ],
    });
    const defeated = await a.host.query(api.enemies.listByRoom, {
      roomId: a.room._id,
    });
    expect(defeated[0]?.hp).toBe(0);
    expect(defeated[0]?.status).toBe("defeated");
    expect(otherEnemies).toEqual([]);
  });

  test("damage and heal player sequentially then tick effects", async () => {
    const t = backend();
    const a = await playingRoom(t);
    const summaries = await t.mutation(
      internal.applyActions.applyGameMasterActions,
      {
        roomId: a.room._id,
        actions: [
          {
            type: "damage_player",
            payload: { player_id: a.alicePlayer._id, amount: 30 },
          },
          {
            type: "heal_player",
            payload: { player_id: a.alicePlayer._id, amount: 10 },
          },
          {
            type: "apply_effect",
            payload: {
              player_id: a.alicePlayer._id,
              id: "bless",
              name: "Bless",
              remaining: 1,
            },
          },
        ],
      },
    );
    const players = await a.host.query(api.players.listByRoom, {
      roomId: a.room._id,
    });
    const aldric = players.find((row) => row._id === a.alicePlayer._id);
    expect(aldric?.hp).toBe(80);
    expect(aldric?.effects).toEqual([]);
    expect(summaries.some((line) => line.includes("se dissipe"))).toBe(true);
  });

  test("potion with stock heals and potion without stock is a no-op", async () => {
    const t = backend();
    const a = await playingRoom(t);
    await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: a.room._id,
      actions: [
        {
          type: "damage_player",
          payload: { player_id: a.alicePlayer._id, amount: 50 },
        },
        {
          type: "give_item",
          payload: {
            player_id: a.alicePlayer._id,
            item: {
              id: "potion",
              name: "Potion",
              type: "potion",
              quantity: 1,
              heal: 20,
            },
          },
        },
      ],
    });
    await a.host.mutation(api.players.usePotion, {
      roomId: a.room._id,
      itemId: "potion",
    });
    let players = await a.host.query(api.players.listByRoom, {
      roomId: a.room._id,
    });
    let aldric = players.find((row) => row._id === a.alicePlayer._id);
    expect(aldric?.hp).toBe(70);
    expect(aldric?.inventory).toEqual([]);

    await a.host.mutation(api.players.usePotion, {
      roomId: a.room._id,
      itemId: "potion",
    });
    players = await a.host.query(api.players.listByRoom, {
      roomId: a.room._id,
    });
    aldric = players.find((row) => row._id === a.alicePlayer._id);
    expect(aldric?.hp).toBe(70);

    await expect(
      a.guest.mutation(api.players.usePotion, {
        roomId: a.room._id,
        itemId: "potion",
      }),
    ).resolves.toBeTruthy();
  });

  test("start and end combat keep a single session per room", async () => {
    const t = backend();
    const a = await playingRoom(t);
    await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: a.room._id,
      actions: [{ type: "start_combat", payload: {} }],
    });
    let combat = await a.host.query(api.combatSessions.getForRoom, {
      roomId: a.room._id,
    });
    expect(combat?.active).toBe(true);
    expect(combat?.round).toBe(1);

    await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: a.room._id,
      actions: [{ type: "start_combat", payload: {} }],
    });
    combat = await a.host.query(api.combatSessions.getForRoom, {
      roomId: a.room._id,
    });
    expect(combat?.round).toBe(2);

    await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: a.room._id,
      actions: [{ type: "end_combat", payload: {} }],
    });
    combat = await a.host.query(api.combatSessions.getForRoom, {
      roomId: a.room._id,
    });
    expect(combat?.active).toBe(false);
    expect(combat?.round).toBe(2);

    const sessions = await t.run(async (ctx: MutationCtx) => {
      return await ctx.db
        .query("combatSessions")
        .withIndex("by_room", (q) => q.eq("roomId", a.room._id))
        .collect();
    });
    expect(sessions).toHaveLength(1);
  });

  test("request_roll skips other mutations, cancels prior pending, and resolves for owner only", async () => {
    const t = backend();
    const a = await playingRoom(t);
    await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: a.room._id,
      actions: [
        {
          type: "damage_player",
          payload: { player_id: a.alicePlayer._id, amount: 10 },
        },
        {
          type: "request_roll",
          payload: {
            player_id: a.alicePlayer._id,
            ability: "strength",
            dc: 14,
            reason: "forcer la porte",
          },
        },
        { type: "start_combat", payload: {} },
      ],
    });
    let players = await a.host.query(api.players.listByRoom, {
      roomId: a.room._id,
    });
    expect(players.find((row) => row._id === a.alicePlayer._id)?.hp).toBe(100);
    const combat = await a.host.query(api.combatSessions.getForRoom, {
      roomId: a.room._id,
    });
    expect(combat?.active).toBe(true);

    await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: a.room._id,
      actions: [
        {
          type: "request_roll",
          payload: {
            player_id: a.alicePlayer._id,
            stat: "wisdom",
            difficulty: 40,
            reason: "percevoir",
          },
        },
      ],
    });
    const rolls = await a.host.query(api.pendingRolls.listByRoom, {
      roomId: a.room._id,
    });
    const pending = rolls.filter((row) => row.status === "pending");
    expect(pending).toHaveLength(1);
    expect(pending[0]?.ability).toBe("wisdom");
    expect(pending[0]?.dc).toBe(25);
    expect(rolls.filter((row) => row.status === "cancelled")).toHaveLength(1);

    await expect(
      a.guest.mutation(api.rolls.resolve, {
        pendingRollId: pending[0]!._id,
        raw: 17,
      }),
    ).rejects.toThrow(GameRuleError);

    const resolved = await a.host.mutation(api.rolls.resolve, {
      pendingRollId: pending[0]!._id,
      raw: 12,
    });
    expect(resolved.raw).toBe(12);
    expect(resolved.modifier).toBe(1);
    expect(resolved.total).toBe(13);
    expect(resolved.success).toBe(false);

    await expect(
      a.host.mutation(api.rolls.resolve, {
        pendingRollId: pending[0]!._id,
        raw: 18,
      }),
    ).rejects.toThrow(GameRuleError);
  });

  test("finish_game marks finished for full host and demo_finished for demo host", async () => {
    const t = backend();
    const full = await playingRoom(t);
    await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: full.room._id,
      actions: [
        {
          type: "finish_game",
          payload: { result: "victory", summary: "Le prince est a l abri." },
        },
      ],
    });
    const finished = await full.host.query(api.rooms.get, {
      roomId: full.room._id,
    });
    expect(finished?.status).toBe("finished");
    expect((finished?.ending as { result: string }).result).toBe("victory");

    const demoHost = await provision(t, { ...alice, subject: "user_01DEMO" }, clericSheet, false);
    const demoRoom = await demoHost.mutation(api.rooms.create, {
      name: "Demo",
      scenarioId: "demo",
      scenarioName: "Demo",
      minPlayers: 1,
      requiredClassIds: [],
      locale: "en",
    });
    await demoHost.mutation(api.players.join, {
      roomId: demoRoom!._id,
      figurineId: 3,
    });
    await demoHost.mutation(api.rooms.start, { roomId: demoRoom!._id });
    await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: demoRoom!._id,
      actions: [{ type: "finish_game", payload: { result: "draw" } }],
    });
    const demoFinished = await demoHost.query(api.rooms.get, {
      roomId: demoRoom!._id,
    });
    expect(demoFinished?.status).toBe("demo_finished");
    expect((demoFinished?.ending as { result: string }).result).toBe("neutral");
  });

  test("stranger cannot resolve another room roll", async () => {
    const t = backend();
    const a = await playingRoom(t);
    await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: a.room._id,
      actions: [
        {
          type: "request_roll",
          payload: {
            player_id: a.alicePlayer._id,
            ability: "dexterity",
            dc: 10,
          },
        },
      ],
    });
    const rolls = await a.host.query(api.pendingRolls.listByRoom, {
      roomId: a.room._id,
    });
    const outsider = await provision(t, { ...alice, subject: "user_01OUT" }, clericSheet);
    await expect(
      outsider.mutation(api.rolls.resolve, {
        pendingRollId: rolls[0]!._id,
        raw: 10,
      }),
    ).rejects.toThrow(ForbiddenError);
  });
});
