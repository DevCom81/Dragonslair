import { action, internalAction, internalQuery, query } from "./_generated/server";
import type { ActionCtx } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { requireUser } from "./lib/auth";
import type { AccessLevel } from "./lib/access";
import type {
  ComputedEntitlement,
  EntitlementGrantSource,
} from "./lib/entitlements";

type GooglePlayAuthedUser = {
  userId: Id<"users">;
  workosSubject: string;
  legacyUuid?: string;
};

type GooglePlaySourceApplyResult =
  | { status: "ignored"; reason: string }
  | {
      status: "ok";
      reason: string;
      accessLevel: AccessLevel;
      source: EntitlementGrantSource;
      metadata: ComputedEntitlement["metadata"];
    };

type GooglePlayRedeemResult = {
  accessLevel: AccessLevel;
  source: EntitlementGrantSource;
  metadata: ComputedEntitlement["metadata"];
};
import {
  GooglePlayConfigError,
  GooglePlayPurchaseError,
  GOOGLE_PLAY_ACCOUNT_MISMATCH,
  GOOGLE_PLAY_RTDN_UNAVAILABLE,
} from "./lib/errors";
import {
  assertExpectedProductId,
  assertPlayAccountBinding,
  assertPlayPackage,
  assertPlayProduct,
  assertRedeemableToken,
  googlePlayPackageName,
  googlePlayProductId,
  grantsFullFromLifecycle,
  isGooglePlayConfigured,
  needsPlayAcknowledgement,
  obfuscatedAccountIdFromPayload,
  rejectPendingOnRedeem,
  requireLifecycle,
} from "./lib/googlePlayPurchase";
import {
  googlePlayRtdnAudience,
  verifyPubsubPushJwt,
} from "./lib/googleOidc";
import {
  acknowledgePlayPurchase,
  fetchGoogleProductPurchase,
  getGooglePlayAccessToken,
} from "./lib/googlePlayPublisher";
import {
  decodePubsubPush,
  parseDeveloperNotification,
} from "./lib/googlePlayRtdn";
import {
  playAccountHashesForUser,
  purchaseTokenFingerprint,
} from "./lib/playAccountId";

export const authedUser = internalQuery({
  args: {},
  handler: async (ctx): Promise<GooglePlayAuthedUser> => {
    const { user } = await requireUser(ctx);
    return {
      userId: user._id,
      workosSubject: user.workosSubject,
      legacyUuid: user.legacyUuid,
    };
  },
});

export const billingIdentity = query({
  args: {},
  handler: async (ctx): Promise<{ obfuscatedAccountId: string }> => {
    const { user } = await requireUser(ctx);
    const hashes = await playAccountHashesForUser({
      workosSubject: user.workosSubject,
      legacyUuid: user.legacyUuid,
    });
    return { obfuscatedAccountId: hashes.workosHash };
  },
});

export const loadGooglePlayUser = internalQuery({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (user === null) {
      return null;
    }
    return {
      userId: user._id,
      workosSubject: user.workosSubject,
      legacyUuid: user.legacyUuid,
    };
  },
});

async function inspectPurchase(args: {
  productId: string;
  purchaseToken: string;
}) {
  const accessToken = await getGooglePlayAccessToken();
  const payload = await fetchGoogleProductPurchase({
    productId: args.productId,
    purchaseToken: args.purchaseToken,
    accessToken,
  });
  assertPlayPackage(payload);
  assertPlayProduct(payload, args.productId);
  const status = requireLifecycle(payload);
  return { payload, status, accessToken };
}

async function resolveRtdnUser(
  ctx: ActionCtx,
  args: { purchaseToken: string; productId: string },
) {
  const providerRef = await purchaseTokenFingerprint(args.purchaseToken);
  const byRef = await ctx.runQuery(
    internal.entitlements.findGooglePlayUserByRef,
    { providerRef },
  );
  if (byRef) {
    return await ctx.runQuery(internal.googlePlay.loadGooglePlayUser, {
      userId: byRef.userId,
    });
  }
  let payload: Record<string, unknown>;
  try {
    const inspected = await inspectPurchase({
      productId: args.productId,
      purchaseToken: args.purchaseToken,
    });
    payload = inspected.payload;
  } catch {
    return null;
  }
  const accountId = obfuscatedAccountIdFromPayload(payload);
  if (!accountId) {
    return null;
  }
  const byAccount = await ctx.runQuery(
    internal.entitlements.findGooglePlayUserByAccountId,
    { playAccountId: accountId },
  );
  if (!byAccount) {
    return null;
  }
  return await ctx.runQuery(internal.googlePlay.loadGooglePlayUser, {
    userId: byAccount.userId,
  });
}

export const redeem = action({
  args: {
    purchaseToken: v.string(),
  },
  handler: async (ctx, args): Promise<GooglePlayRedeemResult> => {
    if (!isGooglePlayConfigured()) {
      throw new GooglePlayConfigError();
    }
    const user: GooglePlayAuthedUser = await ctx.runQuery(
      internal.googlePlay.authedUser,
      {},
    );
    const productId = googlePlayProductId();
    assertExpectedProductId(productId);
    const purchaseToken = assertRedeemableToken(args.purchaseToken);
    const inspected = await inspectPurchase({ productId, purchaseToken });
    rejectPendingOnRedeem(inspected.status);
    const hashes = await playAccountHashesForUser({
      workosSubject: user.workosSubject,
      legacyUuid: user.legacyUuid,
    });
    assertPlayAccountBinding(inspected.payload, hashes.accepted);
    if (
      grantsFullFromLifecycle(inspected.status) &&
      needsPlayAcknowledgement(inspected.payload)
    ) {
      await acknowledgePlayPurchase({
        productId,
        purchaseToken,
        accessToken: inspected.accessToken,
      });
    }
    const providerRef = await purchaseTokenFingerprint(purchaseToken);
    const applied: GooglePlaySourceApplyResult = await ctx.runMutation(
      internal.entitlements.applyGooglePlaySource,
      {
        userId: user.userId,
        providerRef,
        status: inspected.status,
        playAccountId: hashes.workosHash,
        legacyPlayAccountId: hashes.legacyHash,
        mode: "redeem",
      },
    );
    if (applied.status === "ignored") {
      throw new GooglePlayPurchaseError(GOOGLE_PLAY_ACCOUNT_MISMATCH);
    }
    return {
      accessLevel: applied.accessLevel,
      source: applied.source,
      metadata: applied.metadata,
    };
  },
});

export const processRtdn = internalAction({
  args: {
    authorization: v.string(),
    body: v.any(),
  },
  handler: async (ctx, args): Promise<{
    status: string;
    reason?: string;
    access_level?: string;
  }> => {
    if (!isGooglePlayConfigured() || !googlePlayRtdnAudience()) {
      throw new GooglePlayConfigError(GOOGLE_PLAY_RTDN_UNAVAILABLE);
    }
    await verifyPubsubPushJwt({
      authorization: args.authorization,
      audience: googlePlayRtdnAudience(),
    });
    const envelope = decodePubsubPush(args.body);
    const parsed = parseDeveloperNotification(envelope.payload);
    if (parsed === null) {
      return { status: "ignored", reason: "unknown_notification" };
    }
    if (parsed.kind === "test") {
      return { status: "ignored", reason: "test" };
    }
    if (parsed.kind === "ignored_subscription") {
      return { status: "ignored", reason: "subscription_not_supported" };
    }
    const expectedPackage = googlePlayPackageName();
    if (parsed.packageName && parsed.packageName !== expectedPackage) {
      return { status: "ignored", reason: "package_mismatch" };
    }
    const expectedProduct = googlePlayProductId();
    if (!expectedProduct || parsed.productId !== expectedProduct) {
      return { status: "ignored", reason: "product_mismatch" };
    }
    const purchaseToken = assertRedeemableToken(parsed.purchaseToken);
    const linked = await resolveRtdnUser(ctx, {
      purchaseToken,
      productId: parsed.productId,
    });
    if (linked === null) {
      return { status: "ignored", reason: "user_not_linked" };
    }
    let inspected;
    try {
      inspected = await inspectPurchase({
        productId: parsed.productId,
        purchaseToken,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : "";
      return {
        status: "ignored",
        reason: message || "google_play_inspect_failed",
      };
    }
    const hashes = await playAccountHashesForUser({
      workosSubject: linked.workosSubject,
      legacyUuid: linked.legacyUuid,
    });
    try {
      assertPlayAccountBinding(inspected.payload, hashes.accepted);
    } catch {
      return { status: "ignored", reason: "account_mismatch" };
    }
    if (
      grantsFullFromLifecycle(inspected.status) &&
      needsPlayAcknowledgement(inspected.payload)
    ) {
      try {
        await acknowledgePlayPurchase({
          productId: parsed.productId,
          purchaseToken,
          accessToken: inspected.accessToken,
        });
      } catch (error) {
        const message = error instanceof Error ? error.message : "";
        return { status: "ignored", reason: message || "acknowledge_failed" };
      }
    }
    const providerRef = await purchaseTokenFingerprint(purchaseToken);
    const applied = await ctx.runMutation(
      internal.entitlements.applyGooglePlaySource,
      {
        userId: linked.userId,
        providerRef,
        status: inspected.status,
        playAccountId: hashes.workosHash,
        legacyPlayAccountId: hashes.legacyHash,
        mode: "rtdn",
      },
    );
    if (applied.status === "ignored") {
      return { status: "ignored", reason: "other_user" };
    }
    return {
      status: "ok",
      access_level: applied.accessLevel,
    };
  },
});
