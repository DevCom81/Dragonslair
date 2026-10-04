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

describe("ensureUser", () => {
  test("rejects missing auth", async () => {
    const t = backend();
    await expect(t.mutation(api.users.ensureUser, {})).rejects.toBeInstanceOf(
      UnauthenticatedError,
    );
  });

  test("creates one user and a demo entitlement on first sign-in", async () => {
    const t = backend();
    const subject = "user_01ALICE";
    const authed = t.withIdentity({
      subject,
      issuer: "https://api.workos.com/user_management/client_01EXAMPLE",
      email: "alice@example.com",
    });
    const user = await authed.mutation(api.users.ensureUser, {});
    expect(user?.workosSubject).toBe(subject);
    expect(user?.email).toBe("alice@example.com");
    const me = await authed.query(api.users.me, {});
    expect(me?._id).toEqual(user?._id);

    await authed.run(async (ctx: MutationCtx) => {
      const users = await ctx.db.query("users").collect();
      const entitlements = await ctx.db.query("userEntitlements").collect();
      const sources = await ctx.db.query("entitlementSources").collect();
      expect(users).toHaveLength(1);
      expect(entitlements).toHaveLength(1);
      expect(entitlements[0]?.userId).toEqual(user?._id);
      expect(entitlements[0]?.accessLevel).toBe("demo");
      expect(entitlements[0]?.source).toBe("default");
      expect(sources).toHaveLength(0);
    });
  });

  test("is idempotent for the same WorkOS subject", async () => {
    const t = backend();
    const identity = {
      subject: "user_01ALICE",
      issuer: "https://api.workos.com/user_management/client_01EXAMPLE",
    };
    const first = await t
      .withIdentity(identity)
      .mutation(api.users.ensureUser, {});
    const second = await t
      .withIdentity(identity)
      .mutation(api.users.ensureUser, {});
    expect(second?._id).toEqual(first?._id);

    await t.run(async (ctx: MutationCtx) => {
      expect(await ctx.db.query("users").collect()).toHaveLength(1);
      expect(await ctx.db.query("userEntitlements").collect()).toHaveLength(1);
    });
  });

  test("creates distinct users for distinct WorkOS subjects", async () => {
    const t = backend();
    const alice = await t
      .withIdentity({ subject: "user_01ALICE" })
      .mutation(api.users.ensureUser, {});
    const bob = await t
      .withIdentity({ subject: "user_01BOB" })
      .mutation(api.users.ensureUser, {});
    expect(alice?._id).not.toEqual(bob?._id);

    await t.run(async (ctx: MutationCtx) => {
      expect(await ctx.db.query("users").collect()).toHaveLength(2);
      expect(await ctx.db.query("userEntitlements").collect()).toHaveLength(2);
    });
  });

  test("does not duplicate a migrated user and keeps legacyUuid", async () => {
    const t = backend();
    const subject = "user_01MIGRATED";
    const legacyUuid = "11111111-1111-4111-8111-111111111111";
    const userId = await t.run(async (ctx: MutationCtx) => {
      const id = await ctx.db.insert("users", {
        workosSubject: subject,
        email: "migrated@example.com",
        legacyUuid,
        createdAt: 1,
      });
      await ctx.db.insert("userEntitlements", {
        userId: id,
        accessLevel: "full",
        source: "purchase",
        grantedAt: 1,
        metadata: {},
      });
      return id;
    });
    const user = await t
      .withIdentity({
        subject,
        issuer: "https://api.workos.com/user_management/client_01EXAMPLE",
        email: "migrated@example.com",
      })
      .mutation(api.users.ensureUser, {});
    expect(user?._id).toEqual(userId);
    expect(user?.legacyUuid).toBe(legacyUuid);
    expect(user?.workosSubject).toBe(subject);

    await t.run(async (ctx: MutationCtx) => {
      const users = await ctx.db.query("users").collect();
      const entitlements = await ctx.db.query("userEntitlements").collect();
      expect(users).toHaveLength(1);
      expect(entitlements).toHaveLength(1);
      expect(entitlements[0]?.accessLevel).toBe("full");
      expect(entitlements[0]?.source).toBe("purchase");
    });
  });

  test("creates a user when subject is unknown even if an email already exists", async () => {
    const t = backend();
    await t.run(async (ctx: MutationCtx) => {
      await ctx.db.insert("users", {
        workosSubject: "user_01OTHER",
        email: "other@example.com",
        createdAt: 1,
      });
    });
    const user = await t
      .withIdentity({
        subject: "user_01NEW",
        issuer: "https://api.workos.com/user_management/client_01EXAMPLE",
        email: "other@example.com",
      })
      .mutation(api.users.ensureUser, {});
    expect(user?.workosSubject).toBe("user_01NEW");

    await t.run(async (ctx: MutationCtx) => {
      expect(await ctx.db.query("users").collect()).toHaveLength(2);
    });
  });

  test("creates a user when subject is unknown and JWT has no email", async () => {
    const t = backend();
    const user = await t
      .withIdentity({
        subject: "user_01CURRENT",
        issuer: "https://api.workos.com/user_management/client_01EXAMPLE",
      })
      .mutation(api.users.ensureUser, {});
    expect(user?.workosSubject).toBe("user_01CURRENT");

    await t.run(async (ctx: MutationCtx) => {
      expect(await ctx.db.query("users").collect()).toHaveLength(1);
    });
  });
});
