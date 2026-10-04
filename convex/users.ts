import { mutation, query } from "./_generated/server";
import type { MutationCtx } from "./_generated/server";
import type { Doc, Id } from "./_generated/dataModel";
import {
  findUserByWorkosSubject,
  requireIdentity,
} from "./lib/auth";

async function usersForSubject(ctx: MutationCtx, workosSubject: string) {
  return await ctx.db
    .query("users")
    .withIndex("by_workos_subject", (q) => q.eq("workosSubject", workosSubject))
    .collect();
}

function oldestUser(rows: Doc<"users">[]) {
  return rows.reduce((oldest, row) =>
    row._creationTime < oldest._creationTime ? row : oldest,
  );
}

async function patchEmailIfPresent(
  ctx: MutationCtx,
  user: Doc<"users">,
  email: string | undefined,
) {
  if (!email || user.email === email) {
    return;
  }
  await ctx.db.patch(user._id, { email });
}

async function ensureDemoEntitlementIfAbsent(
  ctx: MutationCtx,
  userId: Id<"users">,
  grantedAt: number,
) {
  const existing = await ctx.db
    .query("userEntitlements")
    .withIndex("by_user", (q) => q.eq("userId", userId))
    .collect();
  if (existing.length > 0) {
    return;
  }
  await ctx.db.insert("userEntitlements", {
    userId,
    accessLevel: "demo",
    source: "default",
    grantedAt,
    metadata: {},
  });
}

async function deleteUserProvision(ctx: MutationCtx, userId: Id<"users">) {
  const entitlements = await ctx.db
    .query("userEntitlements")
    .withIndex("by_user", (q) => q.eq("userId", userId))
    .collect();
  for (const row of entitlements) {
    await ctx.db.delete(row._id);
  }
  await ctx.db.delete(userId);
}

export const ensureUser = mutation({
  args: {},
  handler: async (ctx) => {
    const identity = await requireIdentity(ctx);
    // Migrated users are found by WorkOS subject; legacyUuid is never cleared.
    const existing = await usersForSubject(ctx, identity.subject);
    if (existing.length > 0) {
      const user = oldestUser(existing);
      await patchEmailIfPresent(ctx, user, identity.email);
      await ensureDemoEntitlementIfAbsent(ctx, user._id, Date.now());
      return await ctx.db.get(user._id);
    }

    const now = Date.now();
    const userId = await ctx.db.insert("users", {
      workosSubject: identity.subject,
      ...(identity.email ? { email: identity.email } : {}),
      createdAt: now,
    });
    await ctx.db.insert("userEntitlements", {
      userId,
      accessLevel: "demo",
      source: "default",
      grantedAt: now,
      metadata: {},
    });

    const afterInsert = await usersForSubject(ctx, identity.subject);
    if (afterInsert.length > 1) {
      const canonical = oldestUser(afterInsert);
      if (canonical._id !== userId) {
        await deleteUserProvision(ctx, userId);
        await ensureDemoEntitlementIfAbsent(ctx, canonical._id, now);
        return canonical;
      }
    }

    return await ctx.db.get(userId);
  },
});

export const me = query({
  args: {},
  handler: async (ctx) => {
    const identity = await requireIdentity(ctx);
    return await findUserByWorkosSubject(ctx, identity.subject);
  },
});
