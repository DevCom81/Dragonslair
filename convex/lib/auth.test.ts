import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import type { MutationCtx } from "../_generated/server";
import schema from "../schema";
import { requireIdentity, UnauthenticatedError } from "./auth";

function testBackend() {
  return convexTest(schema);
}

describe("requireIdentity", () => {
  test("rejects missing auth", async () => {
    const t = testBackend();
    await t.run(async (ctx: MutationCtx) => {
      await expect(requireIdentity(ctx)).rejects.toBeInstanceOf(
        UnauthenticatedError,
      );
    });
  });

  test("returns the WorkOS subject from Convex identity", async () => {
    const t = testBackend();
    const subject = "user_01WORKOSSUBJECT";
    const issuer =
      "https://api.workos.com/user_management/client_01EXAMPLE";
    await t.withIdentity({ subject, issuer }).run(async (ctx: MutationCtx) => {
      await expect(requireIdentity(ctx)).resolves.toEqual({
        subject,
        issuer,
      });
    });
  });
});

describe("schema inserts", () => {
  test("accepts a production user/room/player graph", async () => {
    const t = testBackend();
    await t.run(async (ctx: MutationCtx) => {
      const userId = await ctx.db.insert("users", {
        workosSubject: "user_01WORKOSSUBJECT",
        email: "player@example.com",
        legacyUuid: "11111111-1111-1111-1111-111111111111",
        createdAt: 1,
      });
      await ctx.db.insert("profiles", {
        userId,
        displayName: "Aldric",
        classId: "fighter",
        avatarFigurineId: 3,
        sheetConfirmed: true,
        createdAt: 1,
        strength: 16,
        dexterity: 10,
        constitution: 14,
        intelligence: 8,
        wisdom: 12,
        charisma: 10,
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
        figurineId: 3,
        figurineName: "Aldric",
        positionX: 0.5,
        positionY: 0.5,
        hp: 100,
        inventory: [],
        joinedAt: 1,
        classId: "fighter",
        effects: [],
        strength: 16,
        dexterity: 10,
        constitution: 14,
        intelligence: 8,
        wisdom: 12,
        charisma: 10,
      });
      await ctx.db.insert("gameEvents", {
        roomId,
        playerId,
        type: "action",
        content: "I search the room.",
        createdAt: 1,
      });
      await ctx.db.insert("enemies", {
        roomId,
        name: "Goblin",
        enemyType: "goblin",
        positionX: 0.2,
        positionY: 0.8,
        hp: 8,
        maxHp: 8,
        status: "active",
        metadata: {},
        createdAt: 1,
        updatedAt: 1,
      });
      await ctx.db.insert("combatSessions", {
        roomId,
        active: false,
        round: 0,
        updatedAt: 1,
      });
      await ctx.db.insert("pendingRolls", {
        roomId,
        playerId,
        ability: "wisdom",
        dc: 12,
        reason: "Notice",
        status: "pending",
        createdAt: 1,
      });
      await ctx.db.insert("roomGmState", {
        roomId,
        gmSecrets: [],
        gmState: { campaign_summary: "" },
        updatedAt: 1,
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
        provider: "stripe",
        providerRef: "cs_test",
        status: "active",
        metadata: {},
        createdAt: 1,
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
        model: "test-model",
        kind: "game_master",
        costSource: "none",
        createdAt: 1,
      });
      await ctx.db.insert("identityMap", {
        supabaseUserId: "11111111-1111-1111-1111-111111111111",
        workosSubject: "user_01WORKOSSUBJECT",
        convexUserId: userId,
      });
      const byCode = await ctx.db
        .query("rooms")
        .withIndex("by_join_code", (q) => q.eq("joinCode", "ABC123"))
        .unique();
      expect(byCode?._id).toEqual(roomId);
    });
  });

  test("rejects a room status that is not in the live contract", async () => {
    const t = testBackend();
    await t.run(async (ctx: MutationCtx) => {
      const invalidRoom = {
        name: "Bad",
        status: "archived",
        createdAt: 1,
        joinCode: "ZZZ999",
        minPlayers: 1,
        requiredClassIds: [] as string[],
        scenarioPrompt: "",
        worldState: {},
        locale: "en" as const,
        ending: {},
        musicMood: "exploration" as const,
      };
      await expect(
        ctx.db.insert("rooms", invalidRoom as never),
      ).rejects.toThrow();
    });
  });
});
