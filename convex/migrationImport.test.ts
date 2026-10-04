import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import type { MutationCtx } from "./_generated/server";
import { api, internal } from "./_generated/api";
import schema from "./schema";

const modules = import.meta.glob("./**/*.ts");
const LEGACY_USER = "11111111-1111-4111-8111-111111111111";
const LEGACY_ROOM = "44444444-4444-4444-8444-444444444444";
const LEGACY_PLAYER = "55555555-5555-4555-8555-555555555555";
const SUBJECT = "user_01ALICE";

function backend() {
  return convexTest(schema, modules);
}

async function importUser(t: ReturnType<typeof backend>) {
  return await t.mutation(internal.migrationImport.upsertUser, {
    legacyUuid: LEGACY_USER,
    workosSubject: SUBJECT,
    email: "alice@example.com",
    createdAt: 1,
  });
}

describe("migrationImport", () => {
  test("stores legacyUuid, remaps FKs, and is idempotent", async () => {
    const t = backend();
    const userId = await importUser(t);
    expect(String(userId)).not.toBe(LEGACY_USER);
    expect(String(userId)).not.toBe(SUBJECT);
    const again = await importUser(t);
    expect(again).toEqual(userId);

    await t.mutation(internal.migrationImport.upsertProfile, {
      legacyUuid: LEGACY_USER,
      userLegacyUuid: LEGACY_USER,
      displayName: "Alice",
      sheetConfirmed: true,
      createdAt: 1,
      strength: 10,
      dexterity: 10,
      constitution: 10,
      intelligence: 10,
      wisdom: 10,
      charisma: 10,
    });
    await t.mutation(internal.migrationImport.upsertEntitlementSource, {
      legacyUuid: "src-stripe-1",
      userLegacyUuid: LEGACY_USER,
      provider: "stripe",
      providerRef: "legacy",
      status: "active",
      metadata: {},
      createdAt: 1,
      updatedAt: 1,
    });
    const entitlement = await t.mutation(
      internal.migrationImport.recomputeUserEntitlement,
      { userLegacyUuid: LEGACY_USER },
    );
    expect(entitlement.accessLevel).toBe("full");
    expect(entitlement.source).toBe("purchase");

    const roomId = await t.mutation(internal.migrationImport.upsertRoom, {
      legacyUuid: LEGACY_ROOM,
      hostLegacyUuid: LEGACY_USER,
      name: "Quest",
      status: "waiting",
      createdAt: 1,
      joinCode: "ABC123",
      minPlayers: 1,
      requiredClassIds: [],
      scenarioPrompt: "",
      worldState: {},
      locale: "en",
      ending: {},
      musicMood: "exploration",
    });
    const playerId = await t.mutation(internal.migrationImport.upsertPlayer, {
      legacyUuid: LEGACY_PLAYER,
      roomLegacyUuid: LEGACY_ROOM,
      userLegacyUuid: LEGACY_USER,
      figurineId: 1,
      figurineName: "Alice",
      positionX: 0.5,
      positionY: 0.5,
      hp: 100,
      inventory: [],
      joinedAt: 1,
      effects: [],
      strength: 10,
      dexterity: 10,
      constitution: 10,
      intelligence: 10,
      wisdom: 10,
      charisma: 10,
    });
    expect(String(roomId)).not.toBe(LEGACY_ROOM);
    expect(String(playerId)).not.toBe(LEGACY_PLAYER);

    await t.mutation(internal.migrationImport.upsertEventBatch, {
      events: [
        {
          legacyUuid: "evt-1",
          roomLegacyUuid: LEGACY_ROOM,
          playerLegacyUuid: LEGACY_PLAYER,
          type: "action",
          content: "looks around",
          createdAt: 1,
        },
      ],
    });

    await t.run(async (ctx: MutationCtx) => {
      const users = await ctx.db.query("users").collect();
      const rooms = await ctx.db.query("rooms").collect();
      const players = await ctx.db.query("players").collect();
      const events = await ctx.db.query("gameEvents").collect();
      const ai = await ctx.db.query("aiUsageEvents").collect();
      expect(users).toHaveLength(1);
      expect(users[0]?.legacyUuid).toBe(LEGACY_USER);
      expect(rooms[0]?.hostUserId).toEqual(userId);
      expect(players[0]?.roomId).toEqual(roomId);
      expect(players[0]?.userId).toEqual(userId);
      expect(events[0]?.roomId).toEqual(roomId);
      expect(events[0]?.playerId).toEqual(playerId);
      expect(ai).toHaveLength(0);
    });
  });

  test("Stripe providerRef=legacy stays scoped to the user", async () => {
    const t = backend();
    const alice = await importUser(t);
    const other = await t.mutation(internal.migrationImport.upsertUser, {
      legacyUuid: "22222222-2222-4222-8222-222222222222",
      workosSubject: "user_01BOB",
      createdAt: 1,
    });
    const first = await t.mutation(internal.migrationImport.upsertEntitlementSource, {
      legacyUuid: "src-a",
      userLegacyUuid: LEGACY_USER,
      provider: "stripe",
      providerRef: "legacy",
      status: "active",
      metadata: {},
      createdAt: 1,
      updatedAt: 1,
    });
    const second = await t.mutation(internal.migrationImport.upsertEntitlementSource, {
      legacyUuid: "src-b",
      userLegacyUuid: "22222222-2222-4222-8222-222222222222",
      provider: "stripe",
      providerRef: "legacy",
      status: "active",
      metadata: {},
      createdAt: 1,
      updatedAt: 1,
    });
    expect(first).not.toEqual(second);
    await t.run(async (ctx: MutationCtx) => {
      const sources = await ctx.db.query("entitlementSources").collect();
      expect(sources).toHaveLength(2);
      expect(sources.map((row) => String(row.userId)).sort()).toEqual(
        [String(alice), String(other)].sort(),
      );
    });
  });

  test("incompatible parent collision is blocked", async () => {
    const t = backend();
    await importUser(t);
    await t.mutation(internal.migrationImport.upsertUser, {
      legacyUuid: "22222222-2222-4222-8222-222222222222",
      workosSubject: "user_01BOB",
      createdAt: 1,
    });
    await t.mutation(internal.migrationImport.upsertRoom, {
      legacyUuid: LEGACY_ROOM,
      hostLegacyUuid: LEGACY_USER,
      name: "Quest",
      status: "waiting",
      createdAt: 1,
      joinCode: "ABC123",
      minPlayers: 1,
      requiredClassIds: [],
      scenarioPrompt: "",
      worldState: {},
      locale: "en",
      ending: {},
      musicMood: "exploration",
    });
    await expect(
      t.mutation(internal.migrationImport.upsertRoom, {
        legacyUuid: LEGACY_ROOM,
        hostLegacyUuid: "22222222-2222-4222-8222-222222222222",
        name: "Quest",
        status: "waiting",
        createdAt: 1,
        joinCode: "ABC123",
        minPlayers: 1,
        requiredClassIds: [],
        scenarioPrompt: "",
        worldState: {},
        locale: "en",
        ending: {},
        musicMood: "exploration",
      }),
    ).rejects.toThrow(/different host/);
  });

  test("ensureUser after import keeps the same user", async () => {
    const t = backend();
    const userId = await importUser(t);
    await t.mutation(internal.migrationImport.upsertEntitlementSource, {
      legacyUuid: "src-play",
      userLegacyUuid: LEGACY_USER,
      provider: "google_play",
      providerRef: "fp_alice",
      status: "active",
      metadata: {},
      createdAt: 1,
      updatedAt: 1,
    });
    await t.mutation(internal.migrationImport.recomputeUserEntitlement, {
      userLegacyUuid: LEGACY_USER,
    });
    const user = await t
      .withIdentity({
        subject: SUBJECT,
        issuer: "https://api.workos.com/user_management/client_01EXAMPLE",
        email: "alice@example.com",
      })
      .mutation(api.users.ensureUser, {});
    expect(user?._id).toEqual(userId);
    expect(user?.legacyUuid).toBe(LEGACY_USER);
    await t.run(async (ctx: MutationCtx) => {
      expect(await ctx.db.query("users").collect()).toHaveLength(1);
      const entitlements = await ctx.db.query("userEntitlements").collect();
      expect(entitlements).toHaveLength(1);
      expect(entitlements[0]?.accessLevel).toBe("full");
    });
  });
});
