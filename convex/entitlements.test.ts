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

describe("LOT 13E.0 entitlements.getMine", () => {
  test("rejects missing auth", async () => {
    const t = backend();
    await expect(t.query(api.entitlements.getMine, {})).rejects.toBeInstanceOf(
      UnauthenticatedError,
    );
  });

  test("returns demo/default after ensureUser", async () => {
    const t = backend();
    const authed = t.withIdentity(alice);
    await authed.mutation(api.users.ensureUser, {});
    const mine = await authed.query(api.entitlements.getMine, {});
    expect(mine).toEqual({ accessLevel: "demo", source: "default" });
    expect(mine).not.toHaveProperty("userId");
  });

  test("returns effective FULL from userEntitlements cache", async () => {
    const t = backend();
    const authed = t.withIdentity(alice);
    const user = await authed.mutation(api.users.ensureUser, {});
    await t.run(async (ctx: MutationCtx) => {
      const rows = await ctx.db
        .query("userEntitlements")
        .withIndex("by_user", (q) => q.eq("userId", user!._id))
        .collect();
      await ctx.db.patch(rows[0]!._id, {
        accessLevel: "full",
        source: "purchase",
      });
    });
    await expect(authed.query(api.entitlements.getMine, {})).resolves.toEqual({
      accessLevel: "full",
      source: "purchase",
    });
  });

  test("expired FULL cache is effective demo and keeps expiresAt", async () => {
    const t = backend();
    const authed = t.withIdentity(alice);
    const user = await authed.mutation(api.users.ensureUser, {});
    const expiresAt = Date.now() - 60_000;
    await t.run(async (ctx: MutationCtx) => {
      const rows = await ctx.db
        .query("userEntitlements")
        .withIndex("by_user", (q) => q.eq("userId", user!._id))
        .collect();
      await ctx.db.patch(rows[0]!._id, {
        accessLevel: "full",
        source: "purchase",
        expiresAt,
      });
    });
    await expect(authed.query(api.entitlements.getMine, {})).resolves.toEqual({
      accessLevel: "demo",
      source: "purchase",
      expiresAt,
    });
  });

  test("isolates entitlement between users", async () => {
    const t = backend();
    const aliceAuthed = t.withIdentity(alice);
    const bobAuthed = t.withIdentity(bob);
    const aliceUser = await aliceAuthed.mutation(api.users.ensureUser, {});
    await bobAuthed.mutation(api.users.ensureUser, {});
    await t.run(async (ctx: MutationCtx) => {
      const rows = await ctx.db
        .query("userEntitlements")
        .withIndex("by_user", (q) => q.eq("userId", aliceUser!._id))
        .collect();
      await ctx.db.patch(rows[0]!._id, {
        accessLevel: "full",
        source: "admin",
      });
    });
    await expect(aliceAuthed.query(api.entitlements.getMine, {})).resolves.toEqual(
      {
        accessLevel: "full",
        source: "admin",
      },
    );
    await expect(bobAuthed.query(api.entitlements.getMine, {})).resolves.toEqual({
      accessLevel: "demo",
      source: "default",
    });
  });

  test("does not expose grant internals as public", () => {
    expect(api.entitlements).not.toHaveProperty("applyStripeCheckoutGrant");
    expect(api.entitlements).not.toHaveProperty("applyGooglePlaySource");
  });
});
