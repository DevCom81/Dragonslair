import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import type { MutationCtx } from "./_generated/server";
import { internal } from "./_generated/api";
import schema from "./schema";

const modules = import.meta.glob("./**/*.ts");

function backend() {
  return convexTest(schema, modules);
}

describe("migrationAudit snapshot", () => {
  test("returns graph ids without emails or gm secrets", async () => {
    const t = backend();
    await t.run(async (ctx: MutationCtx) => {
      const userId = await ctx.db.insert("users", {
        workosSubject: "user_01ALICE",
        email: "alice@example.com",
        legacyUuid: "11111111-1111-4111-8111-111111111111",
        createdAt: 1,
      });
      const roomId = await ctx.db.insert("rooms", {
        name: "Quest",
        status: "waiting",
        createdAt: 1,
        hostUserId: userId,
        joinCode: "ABC123",
        minPlayers: 1,
        requiredClassIds: [],
        scenarioPrompt: "",
        worldState: {},
        locale: "en",
        ending: {},
        musicMood: "exploration",
        legacyUuid: "44444444-4444-4444-8444-444444444444",
      });
      await ctx.db.insert("roomGmState", {
        roomId,
        gmSecrets: ["do-not-leak"],
        gmState: { secret: true },
        updatedAt: 1,
      });
    });
    const snapshot = await t.query(internal.migrationAudit.snapshot, {});
    expect(JSON.stringify(snapshot)).not.toContain("alice@example.com");
    expect(JSON.stringify(snapshot)).not.toContain("do-not-leak");
    expect(snapshot.users).toHaveLength(1);
    expect(snapshot.users[0]?.legacyUuid).toBe("11111111-1111-4111-8111-111111111111");
    expect(snapshot.gmRooms).toHaveLength(1);
    expect(snapshot.aiUsageCount).toBe(0);
  });
});
