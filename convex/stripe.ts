import { action, internalAction, internalQuery } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { accessLevelForUser } from "./lib/access";
import { requireUser } from "./lib/auth";
import {
  GameRuleError,
  PurchaseSignatureError,
  PurchaseUnavailableError,
  PURCHASE_ALREADY_FULL,
} from "./lib/errors";
import {
  parseCheckoutSession,
  parseRefundCharge,
  priceIdsFromSession,
  sessionHasExpectedPrice,
} from "./lib/stripeEvents";
import { constructStripeEvent } from "./lib/stripeWebhook";

const STRIPE_API = "https://api.stripe.com/v1";

function stripeSecretKey() {
  return (process.env.STRIPE_SECRET_KEY ?? "").trim();
}

function stripeWebhookSecret() {
  return (process.env.STRIPE_WEBHOOK_SECRET ?? "").trim();
}

function stripePriceId() {
  return (process.env.STRIPE_DRAGONSLAIR_PRICE_ID ?? "").trim();
}

function checkoutSuccessUrl() {
  return (process.env.CHECKOUT_SUCCESS_URL ?? "").trim();
}

function checkoutCancelUrl() {
  return (process.env.CHECKOUT_CANCEL_URL ?? "").trim();
}

function isHttpsUrl(value: string) {
  return value.startsWith("https://");
}

function isCheckoutConfigured() {
  const success = checkoutSuccessUrl();
  return Boolean(stripeSecretKey() && stripePriceId() && isHttpsUrl(success));
}

function basicAuthHeader(secret: string) {
  const token = btoa(`${secret}:`);
  return `Basic ${token}`;
}

export const authedUser = internalQuery({
  args: {},
  handler: async (ctx) => {
    const { user } = await requireUser(ctx);
    const access = await accessLevelForUser(ctx, user._id);
    return {
      userId: user._id,
      workosSubject: user.workosSubject,
      access,
    };
  },
});

async function retrieveStripeOffer(): Promise<{
  currency: string;
  unitAmount: number;
}> {
  if (!isCheckoutConfigured()) {
    throw new PurchaseUnavailableError();
  }
  const priceId = stripePriceId();
  const response = await fetch(
    `${STRIPE_API}/prices/${encodeURIComponent(priceId)}`,
    {
      headers: {
        Authorization: basicAuthHeader(stripeSecretKey()),
      },
    },
  );
  if (response.status >= 400) {
    throw new PurchaseUnavailableError();
  }
  const payload = (await response.json()) as Record<string, unknown>;
  const unitAmount = payload.unit_amount;
  const currency = String(payload.currency ?? "")
    .trim()
    .toLowerCase();
  if (
    typeof unitAmount !== "number" ||
    !Number.isInteger(unitAmount) ||
    unitAmount < 0 ||
    !currency
  ) {
    throw new PurchaseUnavailableError();
  }
  return { currency, unitAmount };
}

async function createStripeCheckoutSession(args: {
  userId: string;
  workosSubject: string;
}): Promise<string> {
  const success = checkoutSuccessUrl();
  const cancel = isHttpsUrl(checkoutCancelUrl())
    ? checkoutCancelUrl()
    : success;
  const body = new URLSearchParams({
    mode: "payment",
    client_reference_id: args.userId,
    "metadata[user_id]": args.userId,
    "metadata[workos_subject]": args.workosSubject,
    "payment_intent_data[metadata][user_id]": args.userId,
    "payment_intent_data[metadata][workos_subject]": args.workosSubject,
    "line_items[0][price]": stripePriceId(),
    "line_items[0][quantity]": "1",
    success_url: success,
    cancel_url: cancel,
  });
  const response = await fetch(`${STRIPE_API}/checkout/sessions`, {
    method: "POST",
    headers: {
      Authorization: basicAuthHeader(stripeSecretKey()),
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });
  if (response.status >= 400) {
    throw new PurchaseUnavailableError();
  }
  const payload = (await response.json()) as { url?: unknown };
  const url = payload.url;
  if (typeof url !== "string" || !url.startsWith("https://")) {
    throw new PurchaseUnavailableError();
  }
  return url;
}

async function retrieveCheckoutPriceIds(sessionId: string): Promise<string[]> {
  const response = await fetch(
    `${STRIPE_API}/checkout/sessions/${encodeURIComponent(sessionId)}?expand[]=line_items`,
    {
      headers: {
        Authorization: basicAuthHeader(stripeSecretKey()),
      },
    },
  );
  if (response.status >= 400) {
    throw new Error("Unable to load Stripe checkout session.");
  }
  const payload = (await response.json()) as Record<string, unknown>;
  return priceIdsFromSession(payload);
}

export const getOffer = action({
  args: {},
  handler: async (ctx): Promise<{ currency: string; unitAmount: number }> => {
    await ctx.runQuery(internal.stripe.authedUser, {});
    return await retrieveStripeOffer();
  },
});

export const createCheckout = action({
  args: {},
  handler: async (ctx): Promise<{ checkout_url: string }> => {
    if (!isCheckoutConfigured()) {
      throw new PurchaseUnavailableError();
    }
    const user = await ctx.runQuery(internal.stripe.authedUser, {});
    if (user.access === "full") {
      throw new GameRuleError(PURCHASE_ALREADY_FULL);
    }
    const checkout_url = await createStripeCheckoutSession({
      userId: user.userId,
      workosSubject: user.workosSubject,
    });
    return { checkout_url };
  },
});

export const processWebhook = internalAction({
  args: {
    payload: v.string(),
    signature: v.string(),
  },
  handler: async (
    ctx,
    args,
  ): Promise<{ status: "ok" | "ignored"; reason?: string }> => {
    const event = await constructStripeEvent({
      payload: args.payload,
      signature: args.signature,
      secret: stripeWebhookSecret(),
    });
    const record = event as unknown as Record<string, unknown>;
    const checkout = parseCheckoutSession(record);
    if (checkout !== null) {
      if (checkout.mode !== null && checkout.mode !== "payment") {
        return { status: "ignored" as const };
      }
      let priceIds = checkout.priceIds;
      if (priceIds.length === 0) {
        priceIds = await retrieveCheckoutPriceIds(checkout.sessionId);
      }
      const expected = stripePriceId();
      if (!expected || !sessionHasExpectedPrice(priceIds, expected)) {
        return { status: "ignored" as const };
      }
      if (
        !checkout.clientReferenceId &&
        !checkout.metadataUserId &&
        !checkout.workosSubject
      ) {
        return { status: "ignored" as const };
      }
      return await ctx.runMutation(internal.entitlements.applyStripeCheckoutGrant, {
        clientReferenceId: checkout.clientReferenceId ?? undefined,
        metadataUserId: checkout.metadataUserId ?? undefined,
        workosSubject: checkout.workosSubject ?? undefined,
        sessionId: checkout.sessionId,
        paymentIntentId: checkout.paymentIntentId ?? undefined,
      });
    }
    const refund = parseRefundCharge(record);
    if (refund === null) {
      return { status: "ignored" as const };
    }
    return await ctx.runMutation(internal.entitlements.applyStripeRefund, {
      userId: refund.userId ?? undefined,
      workosSubject: refund.workosSubject ?? undefined,
      paymentIntentId: refund.paymentIntentId ?? undefined,
    });
  },
});
