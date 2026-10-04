import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import type { MutationCtx } from "./_generated/server";
import { internal } from "./_generated/api";
import schema from "./schema";
import {
  APPLICATIVE_TABLES,
  RESET_TEST_DATA_CONFIRM,
  ResetConfirmationError,
} from "./resetTestData";

const modules = import.meta.glob("./**/*.ts");

function backend() {
  return convexTest(schema, modules);
}

async function seedGraph(ctx: MutationCtx) {
  const userId = await ctx.db.insert("users", {
    workosSubject: "user_01TEST",
    email: "test@example.com",
    legacyUuid: "11111111-1111-4111-8111-111111111111",
    createdAt: 1,
  });
  await ctx.db.insert("profiles", {
    userId,
    displayName: "Aldric",
    classId: "fighter",
    sheetConfirmed: true,
    createdAt: 1,
    strength: 10,
    dexterity: 10,
    constitution: 10,
    intelligence: 10,
    wisdom: 10,
    charisma: 10,
  });
  await ctx.db.insert("userEntitlements", {
    userId,
    accessLevel: "demo",
    source: "default",
    grantedAt: 1,
    metadata: {},
  });
  await ctx.db.insert("entitlementSources", {
    userId,
    provider: "manual",
    providerRef: "test",
    status: "active",
    metadata: {},
    createdAt: 1,
    updatedAt: 1,
  });
  const roomId = await ctx.db.insert("rooms", {
    name: "Tavern",
    scenarioId: "demo",
    status: "waiting",
    createdAt: 1,
    hostUserId: userId,
    joinCode: "ABC123",
    minPlayers: 1,
    requiredClassIds: [],
    scenarioPrompt: "",
    worldState: {},
    locale: "fr",
    ending: {},
    musicMood: "tavern",
  });
  const playerId = await ctx.db.insert("players", {
    roomId,
    userId,
    figurineId: 1,
    figurineName: "Aldric",
    positionX: 0.5,
    positionY: 0.5,
    hp: 20,
    inventory: [],
    joinedAt: 1,
    classId: "fighter",
    effects: [],
    strength: 10,
    dexterity: 10,
    constitution: 10,
    intelligence: 10,
    wisdom: 10,
    charisma: 10,
  });
  await ctx.db.insert("pendingRolls", {
    roomId,
    playerId,
    ability: "strength",
    dc: 10,
    reason: "door",
    status: "pending",
    createdAt: 1,
  });
  await ctx.db.insert("gameEvents", {
    roomId,
    playerId,
    type: "action",
    content: "I open the door.",
    createdAt: 1,
  });
  await ctx.db.insert("enemies", {
    roomId,
    name: "Goblin",
    enemyType: "goblin",
    positionX: 0.2,
    positionY: 0.3,
    hp: 8,
    maxHp: 8,
    status: "active",
    metadata: {},
    createdAt: 1,
    updatedAt: 1,
  });
  await ctx.db.insert("combatSessions", {
    roomId,
    active: true,
    round: 1,
    updatedAt: 1,
  });
  await ctx.db.insert("roomGmState", {
    roomId,
    gmSecrets: {},
    gmState: {},
    updatedAt: 1,
  });
  await ctx.db.insert("demoSessions", {
    userId,
    roomId,
    createdAt: 1,
  });
  await ctx.db.insert("aiUsageEvents", {
    userId,
    roomId,
    model: "test",
    kind: "game_master",
    costSource: "none",
    createdAt: 1,
  });
  await ctx.db.insert("identityMap", {
    supabaseUserId: "11111111-1111-4111-8111-111111111111",
    workosSubject: "user_01TEST",
    convexUserId: userId,
  });
}

describe("resetTestData.purgeAll", () => {
  test("is reachable only through the internal API", () => {
    expect(internal.resetTestData.purgeAll).toBeDefined();
  });

  test("rejects a wrong confirmation and deletes nothing", async () => {
    const t = backend();
    await t.run(seedGraph);
    await expect(
      t.mutation(internal.resetTestData.purgeAll, { confirm: "nope" }),
    ).rejects.toBeInstanceOf(ResetConfirmationError);

    await t.run(async (ctx: MutationCtx) => {
      for (const table of APPLICATIVE_TABLES) {
        expect(
          await ctx.db.query(table).collect(),
          table,
        ).not.toHaveLength(0);
      }
    });
  });

  test("empties every applicative table when confirmation matches", async () => {
    const t = backend();
    await t.run(seedGraph);
    const result = await t.mutation(internal.resetTestData.purgeAll, {
      confirm: RESET_TEST_DATA_CONFIRM,
    });
    expect(result.deleted).toEqual({
      pendingRolls: 1,
      gameEvents: 1,
      enemies: 1,
      combatSessions: 1,
      roomGmState: 1,
      demoSessions: 1,
      aiUsageEvents: 1,
      players: 1,
      rooms: 1,
      profiles: 1,
      userEntitlements: 1,
      entitlementSources: 1,
      identityMap: 1,
      users: 1,
    });
    expect(result.remaining).toEqual({
      pendingRolls: 0,
      gameEvents: 0,
      enemies: 0,
      combatSessions: 0,
      roomGmState: 0,
      demoSessions: 0,
      aiUsageEvents: 0,
      players: 0,
      rooms: 0,
      profiles: 0,
      userEntitlements: 0,
      entitlementSources: 0,
      identityMap: 0,
      users: 0,
    });

    await t.run(async (ctx: MutationCtx) => {
      for (const table of APPLICATIVE_TABLES) {
        expect(await ctx.db.query(table).collect()).toHaveLength(0);
      }
    });
  });
});
