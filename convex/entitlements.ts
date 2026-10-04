import { internalMutation, internalQuery, query } from "./_generated/server";
import type { MutationCtx } from "./_generated/server";
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { requireUser, findUserByWorkosSubject } from "./lib/auth";
import { accessLevelForUser } from "./lib/access";
import { computeGlobalEntitlement } from "./lib/entitlements";
import { checkoutIdentityMatchesContract } from "./lib/stripeEvents";

export const getMine = query({
  args: {},
  handler: async (ctx) => {
    const { user } = await requireUser(ctx);
    const accessLevel = await accessLevelForUser(ctx, user._id);
    const rows = await ctx.db
      .query("userEntitlements")
      .withIndex("by_user", (q) => q.eq("userId", user._id))
      .collect();
    const row = rows[0];
    return {
      accessLevel,
      source: row?.source ?? "default",
      ...(row?.expiresAt !== undefined ? { expiresAt: row.expiresAt } : {}),
    };
  },
});

async function sourcesForUser(ctx: MutationCtx, userId: Id<"users">) {
  return await ctx.db
    .query("entitlementSources")
    .withIndex("by_user", (q) => q.eq("userId", userId))
    .collect();
}

async function persistComputedEntitlement(
  ctx: MutationCtx,
  userId: Id<"users">,
  now: number,
) {
  const sources = await sourcesForUser(ctx, userId);
  const computed = computeGlobalEntitlement({
    sources: sources.map((row) => ({
      provider: row.provider,
      status: row.status,
      currentPeriodEnd: row.currentPeriodEnd,
    })),
    now,
  });
  const existing = await ctx.db
    .query("userEntitlements")
    .withIndex("by_user", (q) => q.eq("userId", userId))
    .collect();
  const fields = {
    userId,
    accessLevel: computed.accessLevel,
    source: computed.source,
    grantedAt: existing[0]?.grantedAt ?? now,
    metadata: computed.metadata,
    ...(computed.expiresAt !== undefined
      ? { expiresAt: computed.expiresAt }
      : {}),
  };
  if (existing[0]) {
    await ctx.db.patch(existing[0]._id, {
      accessLevel: fields.accessLevel,
      source: fields.source,
      metadata: fields.metadata,
      expiresAt: computed.expiresAt,
    });
  } else {
    await ctx.db.insert("userEntitlements", fields);
  }
  return computed;
}

function sourceMetadata(
  row: Doc<"entitlementSources">,
): Record<string, unknown> {
  if (
    row.metadata !== null &&
    typeof row.metadata === "object" &&
    !Array.isArray(row.metadata)
  ) {
    return row.metadata as Record<string, unknown>;
  }
  return {};
}

export const applyStripeCheckoutGrant = internalMutation({
  args: {
    clientReferenceId: v.optional(v.string()),
    metadataUserId: v.optional(v.string()),
    workosSubject: v.optional(v.string()),
    sessionId: v.string(),
    paymentIntentId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const identity = {
      clientReferenceId: args.clientReferenceId?.trim() || null,
      metadataUserId: args.metadataUserId?.trim() || null,
      workosSubject: args.workosSubject?.trim() || null,
    };
    if (!checkoutIdentityMatchesContract(identity)) {
      return { status: "ignored" as const, reason: "unknown_user" };
    }
    let user: Doc<"users"> | null = null;
    try {
      user = await ctx.db.get(identity.clientReferenceId as Id<"users">);
    } catch {
      user = null;
    }
    if (user === null || user.workosSubject !== identity.workosSubject) {
      return { status: "ignored" as const, reason: "unknown_user" };
    }
    const target = user;
    const now = Date.now();
    const existing = await ctx.db
      .query("entitlementSources")
      .withIndex("by_user_provider_ref", (q) =>
        q
          .eq("userId", target._id)
          .eq("provider", "stripe")
          .eq("providerRef", args.sessionId),
      )
      .collect();
    const byRef = await ctx.db
      .query("entitlementSources")
      .withIndex("by_provider_ref", (q) =>
        q.eq("provider", "stripe").eq("providerRef", args.sessionId),
      )
      .collect();
    const current = existing[0] ?? byRef.find((row) => row.userId === target._id);
    if (current?.status === "revoked") {
      await persistComputedEntitlement(ctx, target._id, now);
      return { status: "ok" as const, reason: "already_revoked" };
    }
    const metadata = {
      provider: "stripe",
      stripe_session_id: args.sessionId.slice(0, 120),
      ...(args.paymentIntentId
        ? { payment_intent_id: args.paymentIntentId }
        : {}),
    };
    if (current) {
      await ctx.db.patch(current._id, {
        status: "active",
        metadata,
        updatedAt: now,
      });
    } else {
      const raced = await ctx.db
        .query("entitlementSources")
        .withIndex("by_user_provider_ref", (q) =>
          q
            .eq("userId", target._id)
            .eq("provider", "stripe")
            .eq("providerRef", args.sessionId),
        )
        .collect();
      if (raced.length === 0) {
        await ctx.db.insert("entitlementSources", {
          userId: target._id,
          provider: "stripe",
          providerRef: args.sessionId,
          status: "active",
          metadata,
          createdAt: now,
          updatedAt: now,
        });
      }
    }
    await persistComputedEntitlement(ctx, target._id, now);
    return { status: "ok" as const, reason: "granted" };
  },
});

export const applyStripeRefund = internalMutation({
  args: {
    userId: v.optional(v.string()),
    workosSubject: v.optional(v.string()),
    paymentIntentId: v.optional(v.string()),
    sessionId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    let user: Doc<"users"> | null = null;
    if (args.userId) {
      try {
        user = await ctx.db.get(args.userId as Id<"users">);
      } catch {
        user = null;
      }
    }
    if (user === null && args.workosSubject) {
      user = await findUserByWorkosSubject(ctx, args.workosSubject);
    }
    if (user === null && args.sessionId) {
      const sessionId = args.sessionId;
      const byRef = await ctx.db
        .query("entitlementSources")
        .withIndex("by_provider_ref", (q) =>
          q.eq("provider", "stripe").eq("providerRef", sessionId),
        )
        .collect();
      const match = byRef[0];
      if (match) {
        user = await ctx.db.get(match.userId);
      }
    }
    if (user === null) {
      return { status: "ignored" as const, reason: "unknown_source" };
    }
    const target = user;
    const sources = (await sourcesForUser(ctx, target._id)).filter(
      (row) => row.provider === "stripe",
    );
    if (sources.length === 0) {
      return { status: "ignored" as const, reason: "unknown_source" };
    }
    const bySession = args.sessionId
      ? sources.filter((row) => row.providerRef === args.sessionId)
      : [];
    const byPi = args.paymentIntentId
      ? sources.filter(
          (row) =>
            sourceMetadata(row).payment_intent_id === args.paymentIntentId,
        )
      : [];
    const targets =
      bySession.length > 0
        ? bySession
        : byPi.length > 0
          ? byPi
          : sources;
    const now = Date.now();
    for (const row of targets) {
      await ctx.db.patch(row._id, {
        status: "revoked",
        updatedAt: now,
      });
    }
    await persistComputedEntitlement(ctx, target._id, now);
    return { status: "ok" as const, reason: "revoked" };
  },
});

export const applyGooglePlaySource = internalMutation({
  args: {
    userId: v.id("users"),
    providerRef: v.string(),
    status: v.union(
      v.literal("active"),
      v.literal("pending"),
      v.literal("revoked"),
    ),
    playAccountId: v.string(),
    legacyPlayAccountId: v.optional(v.string()),
    mode: v.union(v.literal("redeem"), v.literal("rtdn")),
  },
  handler: async (ctx, args) => {
    const byRef = await ctx.db
      .query("entitlementSources")
      .withIndex("by_provider_ref", (q) =>
        q.eq("provider", "google_play").eq("providerRef", args.providerRef),
      )
      .collect();
    const owned = byRef.find((row) => row.userId === args.userId);
    const foreign = byRef.find((row) => row.userId !== args.userId);
    if (foreign) {
      return { status: "ignored" as const, reason: "other_user" };
    }
    const now = Date.now();
    if (owned?.status === "revoked" && args.mode === "rtdn" && args.status === "active") {
      const computed = await persistComputedEntitlement(ctx, args.userId, now);
      return {
        status: "ok" as const,
        reason: "already_revoked",
        accessLevel: computed.accessLevel,
        source: computed.source,
        metadata: computed.metadata,
      };
    }
    const metadata = {
      provider: "google_play",
      play_account_id: args.playAccountId,
      ...(args.legacyPlayAccountId
        ? { legacy_play_account_id: args.legacyPlayAccountId }
        : {}),
    };
    if (owned) {
      await ctx.db.patch(owned._id, {
        status: args.status,
        metadata,
        updatedAt: now,
      });
    } else {
      const raced = await ctx.db
        .query("entitlementSources")
        .withIndex("by_user_provider_ref", (q) =>
          q
            .eq("userId", args.userId)
            .eq("provider", "google_play")
            .eq("providerRef", args.providerRef),
        )
        .collect();
      if (raced.length === 0) {
        await ctx.db.insert("entitlementSources", {
          userId: args.userId,
          provider: "google_play",
          providerRef: args.providerRef,
          status: args.status,
          metadata,
          createdAt: now,
          updatedAt: now,
        });
      }
    }
    const computed = await persistComputedEntitlement(ctx, args.userId, now);
    return {
      status: "ok" as const,
      reason: "applied",
      accessLevel: computed.accessLevel,
      source: computed.source,
      metadata: computed.metadata,
    };
  },
});

export const findGooglePlayUserByRef = internalQuery({
  args: { providerRef: v.string() },
  handler: async (ctx, args) => {
    const rows = await ctx.db
      .query("entitlementSources")
      .withIndex("by_provider_ref", (q) =>
        q.eq("provider", "google_play").eq("providerRef", args.providerRef),
      )
      .collect();
    const row = rows[0];
    if (!row) {
      return null;
    }
    return { userId: row.userId, status: row.status };
  },
});

export const findGooglePlayUserByAccountId = internalQuery({
  args: { playAccountId: v.string() },
  handler: async (ctx, args) => {
    const rows = await ctx.db
      .query("entitlementSources")
      .withIndex("by_provider_ref", (q) => q.eq("provider", "google_play"))
      .collect();
    const match = rows.find((row) => {
      const meta = sourceMetadata(row);
      const current = String(meta.play_account_id ?? "").trim();
      const legacy = String(meta.legacy_play_account_id ?? "").trim();
      return (
        current === args.playAccountId || legacy === args.playAccountId
      );
    });
    if (!match) {
      return null;
    }
    return { userId: match.userId, status: match.status };
  },
});
