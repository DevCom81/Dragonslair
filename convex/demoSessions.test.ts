import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import type { MutationCtx } from "./_generated/server";
import { api } from "./_generated/api";
import schema from "./schema";
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

describe("LOT 13E.0 demoSessions.getMine", () => {
  test("rejects missing auth", async () => {
    const t = backend();
    await expect(t.query(api.demoSessions.getMine, {})).rejects.toBeInstanceOf(
      UnauthenticatedError,
    );
  });

  test("returns null when no session exists and does not insert one", async () => {
    const t = backend();
    const authed = t.withIdentity(alice);
    await authed.mutation(api.users.ensureUser, {});
    await expect(authed.query(api.demoSessions.getMine, {})).resolves.toBeNull();
    const count = await t.run(async (ctx: MutationCtx) => {
      return (await ctx.db.query("demoSessions").collect()).length;
    });
    expect(count).toBe(0);
  });

  test("returns persisted active clock fields without rewriting them", async () => {
    const t = backend();
    const authed = t.withIdentity(alice);
    const user = await authed.mutation(api.users.ensureUser, {});
    const startedAt = 1_700_000_000_000;
    const expiresAt = startedAt + 10 * 60_000;
    await t.run(async (ctx: MutationCtx) => {
      await ctx.db.insert("demoSessions", {
        userId: user!._id,
        startedAt,
        expiresAt,
        createdAt: startedAt,
      });
    });
    const mine = await authed.query(api.demoSessions.getMine, {});
    expect(mine).toEqual({ startedAt, expiresAt });
    const after = await t.run(async (ctx: MutationCtx) => {
      return await ctx.db.query("demoSessions").collect();
    });
    expect(after).toHaveLength(1);
    expect(after[0]?.startedAt).toBe(startedAt);
    expect(after[0]?.expiresAt).toBe(expiresAt);
    expect(after[0]?.pausedAt).toBeUndefined();
    expect(after[0]?.completedAt).toBeUndefined();
  });

  test("returns expired timestamps as stored without completing the session", async () => {
    const t = backend();
    const authed = t.withIdentity(alice);
    const user = await authed.mutation(api.users.ensureUser, {});
    const startedAt = 1_600_000_000_000;
    const expiresAt = startedAt + 10 * 60_000;
    await t.run(async (ctx: MutationCtx) => {
      await ctx.db.insert("demoSessions", {
        userId: user!._id,
        startedAt,
        expiresAt,
        createdAt: startedAt,
      });
    });
    await expect(authed.query(api.demoSessions.getMine, {})).resolves.toEqual({
      startedAt,
      expiresAt,
    });
    const after = await t.run(async (ctx: MutationCtx) => {
      return await ctx.db.query("demoSessions").collect();
    });
    expect(after[0]?.completedAt).toBeUndefined();
  });

  test("returns paused and completed timestamps as stored", async () => {
    const t = backend();
    const authed = t.withIdentity(alice);
    const user = await authed.mutation(api.users.ensureUser, {});
    const startedAt = 1_700_000_100_000;
    const expiresAt = startedAt + 10 * 60_000;
    const pausedAt = startedAt + 60_000;
    const completedAt = startedAt + 90_000;
    await t.run(async (ctx: MutationCtx) => {
      await ctx.db.insert("demoSessions", {
        userId: user!._id,
        startedAt,
        expiresAt,
        pausedAt,
        completedAt,
        createdAt: startedAt,
      });
    });
    await expect(authed.query(api.demoSessions.getMine, {})).resolves.toEqual({
      startedAt,
      expiresAt,
      pausedAt,
      completedAt,
    });
  });

  test("isolates sessions between users", async () => {
    const t = backend();
    const aliceAuthed = t.withIdentity(alice);
    const bobAuthed = t.withIdentity(bob);
    const aliceUser = await aliceAuthed.mutation(api.users.ensureUser, {});
    await bobAuthed.mutation(api.users.ensureUser, {});
    const startedAt = 1_700_000_200_000;
    await t.run(async (ctx: MutationCtx) => {
      await ctx.db.insert("demoSessions", {
        userId: aliceUser!._id,
        startedAt,
        expiresAt: startedAt + 10 * 60_000,
        createdAt: startedAt,
      });
    });
    expect(await aliceAuthed.query(api.demoSessions.getMine, {})).toMatchObject({
      startedAt,
    });
    await expect(bobAuthed.query(api.demoSessions.getMine, {})).resolves.toBeNull();
  });

  test("does not expose syncDemoPlay publicly", () => {
    expect(api.gameMaster).not.toHaveProperty("syncDemoPlay");
  });
});
