import { afterEach, describe, expect, test, vi } from "vitest";
import { convexTest } from "convex-test";
import Stripe from "stripe";
import type { MutationCtx } from "./_generated/server";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import {
  GameRuleError,
  PurchaseSignatureError,
  PurchaseUnavailableError,
  PURCHASE_ALREADY_FULL,
} from "./lib/errors";
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

const PRICE = "price_test_dragons";
const SECRET = "whsec_test_secret";
const SUCCESS_URL = "https://example.com/play?purchase=success";
const CANCEL_URL = "https://example.com/play?purchase=cancel";
const stripeTestCrypto = Stripe.createSubtleCryptoProvider();

function stripeHeader(payload: string): Promise<string> {
  return Stripe.webhooks.generateTestHeaderStringAsync({
    payload,
    secret: SECRET,
    cryptoProvider: stripeTestCrypto,
  });
}

function paidEvent(args: {
  userId: string;
  clientReferenceId?: string;
  metadataUserId?: string;
  workosSubject?: string;
  sessionId?: string;
  priceId?: string;
  paymentStatus?: string;
  mode?: string;
  paymentIntentId?: string;
}) {
  return JSON.stringify({
    type: "checkout.session.completed",
    data: {
      object: {
        id: args.sessionId ?? "cs_test",
        payment_status: args.paymentStatus ?? "paid",
        mode: args.mode ?? "payment",
        client_reference_id: args.clientReferenceId ?? args.userId,
        metadata: {
          user_id: args.metadataUserId ?? args.userId,
          workos_subject: args.workosSubject ?? alice.subject,
        },
        payment_intent: args.paymentIntentId ?? "pi_test",
        line_items: {
          data: [
            {
              price: { id: args.priceId ?? PRICE },
            },
          ],
        },
      },
    },
  });
}

function refundEvent(args: {
  userId?: string;
  workosSubject?: string;
  paymentIntentId?: string;
  refunded?: boolean;
}) {
  return JSON.stringify({
    type: "charge.refunded",
    data: {
      object: {
        id: "ch_test",
        refunded: args.refunded ?? true,
        payment_intent: args.paymentIntentId ?? "pi_test",
        metadata: {
          ...(args.userId ? { user_id: args.userId } : {}),
          ...(args.workosSubject
            ? { workos_subject: args.workosSubject }
            : {}),
        },
      },
    },
  });
}

async function provision(t: ReturnType<typeof backend>, identity = alice) {
  const authed = t.withIdentity(identity);
  const user = await authed.mutation(api.users.ensureUser, {});
  return { authed, user: user! };
}

function setStripeEnv() {
  process.env.STRIPE_SECRET_KEY = "sk_test_fake";
  process.env.STRIPE_WEBHOOK_SECRET = SECRET;
  process.env.STRIPE_DRAGONSLAIR_PRICE_ID = PRICE;
  process.env.CHECKOUT_SUCCESS_URL = SUCCESS_URL;
  process.env.CHECKOUT_CANCEL_URL = CANCEL_URL;
}

afterEach(() => {
  vi.unstubAllGlobals();
  delete process.env.STRIPE_SECRET_KEY;
  delete process.env.STRIPE_WEBHOOK_SECRET;
  delete process.env.STRIPE_DRAGONSLAIR_PRICE_ID;
  delete process.env.CHECKOUT_SUCCESS_URL;
  delete process.env.CHECKOUT_CANCEL_URL;
});

describe("LOT 9 stripe", () => {
  test("1 createCheckout unauthenticated is refused", async () => {
    setStripeEnv();
    const t = backend();
    await expect(t.action(api.stripe.createCheckout, {})).rejects.toThrow(
      UnauthenticatedError,
    );
  });

  test("2-5 createCheckout uses WorkOS user, server price, identity metadata", async () => {
    setStripeEnv();
    const t = backend();
    const { authed, user } = await provision(t);
    const fetchMock = vi.fn(async (_url: string, init?: RequestInit) => {
      const params = new URLSearchParams(String(init?.body ?? ""));
      expect(params.get("client_reference_id")).toBe(user._id);
      expect(params.get("metadata[user_id]")).toBe(user._id);
      expect(params.get("metadata[workos_subject]")).toBe(alice.subject);
      expect(params.get("payment_intent_data[metadata][user_id]")).toBe(
        user._id,
      );
      expect(params.get("payment_intent_data[metadata][workos_subject]")).toBe(
        alice.subject,
      );
      expect(params.get("line_items[0][price]")).toBe(PRICE);
      expect(params.get("line_items[0][quantity]")).toBe("1");
      expect(params.get("mode")).toBe("payment");
      expect(params.get("success_url")).toBe(SUCCESS_URL);
      expect(params.get("cancel_url")).toBe(CANCEL_URL);
      return {
        status: 200,
        json: async () => ({
          url: "https://checkout.stripe.com/c/pay/cs_test_ok",
        }),
      };
    });
    vi.stubGlobal("fetch", fetchMock);
    const result = await authed.action(api.stripe.createCheckout, {});
    expect(result.checkout_url).toBe(
      "https://checkout.stripe.com/c/pay/cs_test_ok",
    );
    expect(fetchMock).toHaveBeenCalled();
    const serialized = JSON.stringify(result);
    expect(serialized).not.toContain("sk_test");
    expect(serialized).not.toContain(SECRET);
  });

  test("3 client cannot buy for another userId", async () => {
    setStripeEnv();
    const t = backend();
    const { authed, user } = await provision(t);
    const fetchMock = vi.fn(async (_url: string, init?: RequestInit) => {
      const params = new URLSearchParams(String(init?.body ?? ""));
      expect(params.get("client_reference_id")).toBe(user._id);
      expect(params.get("client_reference_id")).not.toBe("user_01BOB");
      return {
        status: 200,
        json: async () => ({
          url: "https://checkout.stripe.com/c/pay/cs_test_ok",
        }),
      };
    });
    vi.stubGlobal("fetch", fetchMock);
    try {
      await authed.action(api.stripe.createCheckout, {
        userId: "user_01BOB",
      } as never);
    } catch {
      expect(fetchMock).not.toHaveBeenCalled();
      return;
    }
    expect(fetchMock).toHaveBeenCalled();
  });

  test("createCheckout already full is PURCHASE_ALREADY_FULL", async () => {
    setStripeEnv();
    const t = backend();
    const { authed, user } = await provision(t);
    await t.run(async (ctx: MutationCtx) => {
      const rows = await ctx.db
        .query("userEntitlements")
        .withIndex("by_user", (q) => q.eq("userId", user._id))
        .collect();
      await ctx.db.patch(rows[0]!._id, {
        accessLevel: "full",
        source: "admin",
      });
    });
    vi.stubGlobal("fetch", vi.fn());
    await expect(authed.action(api.stripe.createCheckout, {})).rejects.toThrow(
      GameRuleError,
    );
    await expect(authed.action(api.stripe.createCheckout, {})).rejects.toThrow(
      PURCHASE_ALREADY_FULL,
    );
    expect(fetch).not.toHaveBeenCalled();
  });

  test("6 invalid webhook signature is refused", async () => {
    setStripeEnv();
    const t = backend();
    const payload = paidEvent({ userId: "skip" });
    await expect(
      t.action(internal.stripe.processWebhook, {
        payload,
        signature: "t=1700000000,v1=deadbeef",
      }),
    ).rejects.toThrow(PurchaseSignatureError);
    const response = await t.fetch("/stripe-webhook", {
      method: "POST",
      headers: { "Stripe-Signature": "t=1700000000,v1=deadbeef" },
      body: payload,
    });
    expect(response.status).toBe(400);
    const text = await response.text();
    expect(text).not.toContain(SECRET);
    expect(text).not.toContain("sk_test");
  });

  test("7-9 completed grants full and is idempotent", async () => {
    setStripeEnv();
    const t = backend();
    const { user } = await provision(t);
    const payload = paidEvent({
      userId: user._id,
      workosSubject: alice.subject,
    });
    const signature = await stripeHeader(payload);
    const first = await t.action(internal.stripe.processWebhook, {
      payload,
      signature,
    });
    const second = await t.action(internal.stripe.processWebhook, {
      payload,
      signature,
    });
    expect(first.status).toBe("ok");
    expect(second.status).toBe("ok");
    const state = await t.run(async (ctx: MutationCtx) => {
      const sources = await ctx.db.query("entitlementSources").collect();
      const entitlements = await ctx.db.query("userEntitlements").collect();
      return { sources, entitlements };
    });
    expect(state.sources).toHaveLength(1);
    expect(state.sources[0]?.provider).toBe("stripe");
    expect(state.sources[0]?.providerRef).toBe("cs_test");
    expect(state.sources[0]?.status).toBe("active");
    expect(state.entitlements[0]?.accessLevel).toBe("full");
    expect(state.entitlements[0]?.source).toBe("purchase");
  });

  test("10 wrong price does not grant full", async () => {
    setStripeEnv();
    const t = backend();
    const { user } = await provision(t);
    const payload = paidEvent({
      userId: user._id,
      priceId: "price_other",
    });
    const signature = await stripeHeader(payload);
    const result = await t.action(internal.stripe.processWebhook, {
      payload,
      signature,
    });
    expect(result.status).toBe("ignored");
    const entitlements = await t.run(async (ctx: MutationCtx) => {
      return await ctx.db.query("userEntitlements").collect();
    });
    expect(entitlements[0]?.accessLevel).toBe("demo");
  });

  test("11 unpaid session does not grant full", async () => {
    setStripeEnv();
    const t = backend();
    const { user } = await provision(t);
    const payload = paidEvent({
      userId: user._id,
      paymentStatus: "unpaid",
    });
    const signature = await stripeHeader(payload);
    const result = await t.action(internal.stripe.processWebhook, {
      payload,
      signature,
    });
    expect(result.status).toBe("ignored");
  });

  test("12 unknown metadata does not grant full", async () => {
    setStripeEnv();
    const t = backend();
    await provision(t);
    const payload = paidEvent({
      userId: "not-a-real-user",
      workosSubject: "user_01UNKNOWN",
    });
    const signature = await stripeHeader(payload);
    const result = await t.action(internal.stripe.processWebhook, {
      payload,
      signature,
    });
    expect(result).toMatchObject({ status: "ignored" });
    const sources = await t.run(async (ctx: MutationCtx) => {
      return await ctx.db.query("entitlementSources").collect();
    });
    expect(sources).toEqual([]);
  });

  test("contradictory checkout identity refs do not grant full", async () => {
    setStripeEnv();
    const t = backend();
    const aliceUser = await provision(t, alice);
    const bobUser = await provision(t, bob);
    const mixedSubject = paidEvent({
      userId: aliceUser.user._id,
      workosSubject: bob.subject,
      sessionId: "cs_mixed_subject",
    });
    const mixedIds = paidEvent({
      userId: aliceUser.user._id,
      metadataUserId: bobUser.user._id,
      workosSubject: alice.subject,
      sessionId: "cs_mixed_ids",
    });
    for (const payload of [mixedSubject, mixedIds]) {
      const result = await t.action(internal.stripe.processWebhook, {
        payload,
        signature: await stripeHeader(payload),
      });
      expect(result).toMatchObject({ status: "ignored" });
    }
    const state = await t.run(async (ctx: MutationCtx) => {
      const sources = await ctx.db.query("entitlementSources").collect();
      const entitlements = await ctx.db.query("userEntitlements").collect();
      return { sources, entitlements };
    });
    expect(state.sources).toEqual([]);
    expect(
      state.entitlements.every((row) => row.accessLevel === "demo"),
    ).toBe(true);
  });

  test("13-14 refund revokes stripe source idempotently", async () => {
    setStripeEnv();
    const t = backend();
    const { user } = await provision(t);
    const paid = paidEvent({
      userId: user._id,
      paymentIntentId: "pi_test",
    });
    await t.action(internal.stripe.processWebhook, {
      payload: paid,
      signature: await stripeHeader(paid),
    });
    const refund = refundEvent({
      userId: user._id,
      paymentIntentId: "pi_test",
    });
    const signature = await stripeHeader(refund);
    const first = await t.action(internal.stripe.processWebhook, {
      payload: refund,
      signature,
    });
    const second = await t.action(internal.stripe.processWebhook, {
      payload: refund,
      signature,
    });
    expect(first.status).toBe("ok");
    expect(second.status).toBe("ok");
    const state = await t.run(async (ctx: MutationCtx) => {
      const sources = await ctx.db.query("entitlementSources").collect();
      const entitlements = await ctx.db.query("userEntitlements").collect();
      return { sources, entitlements };
    });
    expect(state.sources).toHaveLength(1);
    expect(state.sources[0]?.status).toBe("revoked");
    expect(state.entitlements[0]?.accessLevel).toBe("demo");
  });

  test("15 refund of unknown source is ignored safely", async () => {
    setStripeEnv();
    const t = backend();
    await provision(t);
    const refund = refundEvent({ userId: "missing" });
    const result = await t.action(internal.stripe.processWebhook, {
      payload: refund,
      signature: await stripeHeader(refund),
    });
    expect(result).toMatchObject({ status: "ignored" });
  });

  test("16 refund stripe keeps full when google_play is active", async () => {
    setStripeEnv();
    const t = backend();
    const { user } = await provision(t);
    const paid = paidEvent({ userId: user._id });
    await t.action(internal.stripe.processWebhook, {
      payload: paid,
      signature: await stripeHeader(paid),
    });
    await t.run(async (ctx: MutationCtx) => {
      await ctx.db.insert("entitlementSources", {
        userId: user._id,
        provider: "google_play",
        providerRef: "play_token",
        status: "active",
        metadata: {},
        createdAt: Date.now(),
        updatedAt: Date.now(),
      });
    });
    const refund = refundEvent({ userId: user._id });
    await t.action(internal.stripe.processWebhook, {
      payload: refund,
      signature: await stripeHeader(refund),
    });
    const state = await t.run(async (ctx: MutationCtx) => {
      const sources = await ctx.db.query("entitlementSources").collect();
      const entitlements = await ctx.db.query("userEntitlements").collect();
      return { sources, entitlements };
    });
    expect(
      state.sources.find((row) => row.provider === "stripe")?.status,
    ).toBe("revoked");
    expect(
      state.sources.find((row) => row.provider === "google_play")?.status,
    ).toBe("active");
    expect(state.entitlements[0]?.accessLevel).toBe("full");
    expect(state.entitlements[0]?.metadata).toMatchObject({
      active_sources: ["google_play"],
    });
  });

  test("17 last full source refund returns to demo", async () => {
    setStripeEnv();
    const t = backend();
    const { user } = await provision(t);
    const paid = paidEvent({ userId: user._id });
    await t.action(internal.stripe.processWebhook, {
      payload: paid,
      signature: await stripeHeader(paid),
    });
    const refund = refundEvent({ userId: user._id });
    await t.action(internal.stripe.processWebhook, {
      payload: refund,
      signature: await stripeHeader(refund),
    });
    const entitlements = await t.run(async (ctx: MutationCtx) => {
      return await ctx.db.query("userEntitlements").collect();
    });
    expect(entitlements[0]?.accessLevel).toBe("demo");
    expect(entitlements[0]?.source).toBe("default");
  });

  test("18 irrelevant event changes nothing", async () => {
    setStripeEnv();
    const t = backend();
    await provision(t);
    const payload = JSON.stringify({
      type: "invoice.paid",
      data: { object: { id: "in_test" } },
    });
    const result = await t.action(internal.stripe.processWebhook, {
      payload,
      signature: await stripeHeader(payload),
    });
    expect(result.status).toBe("ignored");
    const sources = await t.run(async (ctx: MutationCtx) => {
      return await ctx.db.query("entitlementSources").collect();
    });
    expect(sources).toEqual([]);
  });

  test("duplicate completed after refund does not resurrect", async () => {
    setStripeEnv();
    const t = backend();
    const { user } = await provision(t);
    const paid = paidEvent({ userId: user._id, sessionId: "cs_once" });
    const signaturePaid = await stripeHeader(paid);
    await t.action(internal.stripe.processWebhook, {
      payload: paid,
      signature: signaturePaid,
    });
    const refund = refundEvent({ userId: user._id });
    await t.action(internal.stripe.processWebhook, {
      payload: refund,
      signature: await stripeHeader(refund),
    });
    await t.action(internal.stripe.processWebhook, {
      payload: paid,
      signature: signaturePaid,
    });
    const state = await t.run(async (ctx: MutationCtx) => {
      const sources = await ctx.db.query("entitlementSources").collect();
      const entitlements = await ctx.db.query("userEntitlements").collect();
      return { sources, entitlements };
    });
    expect(state.sources[0]?.status).toBe("revoked");
    expect(state.entitlements[0]?.accessLevel).toBe("demo");
  });

  test("http webhook completed returns 2xx", async () => {
    setStripeEnv();
    const t = backend();
    const { user } = await provision(t, bob);
    const payload = paidEvent({
      userId: user._id,
      workosSubject: bob.subject,
      sessionId: "cs_http",
    });
    const response = await t.fetch("/stripe-webhook", {
      method: "POST",
      headers: {
        "Stripe-Signature": await stripeHeader(payload),
        "Content-Type": "application/json",
      },
      body: payload,
    });
    expect(response.status).toBe(200);
    const body = await response.text();
    expect(body).not.toContain(SECRET);
    expect(body).not.toContain("sk_test");
  });

  test("missing checkout config is unavailable", async () => {
    const t = backend();
    const { authed } = await provision(t);
    await expect(authed.action(api.stripe.createCheckout, {})).rejects.toThrow(
      PurchaseUnavailableError,
    );
  });

  test("13E.0 getOffer unauthenticated is refused", async () => {
    setStripeEnv();
    const t = backend();
    await expect(t.action(api.stripe.getOffer, {})).rejects.toThrow(
      UnauthenticatedError,
    );
  });

  test("13E.0 getOffer reads the same configured Stripe price as checkout", async () => {
    setStripeEnv();
    const t = backend();
    const { authed } = await provision(t);
    const fetchMock = vi.fn(async (url: string) => {
      expect(String(url)).toBe(`https://api.stripe.com/v1/prices/${PRICE}`);
      return {
        status: 200,
        json: async () => ({
          id: PRICE,
          unit_amount: 1999,
          currency: "EUR",
        }),
      };
    });
    vi.stubGlobal("fetch", fetchMock);
    const offer = await authed.action(api.stripe.getOffer, {});
    expect(offer).toEqual({ currency: "eur", unitAmount: 1999 });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const serialized = JSON.stringify(offer);
    expect(serialized).not.toContain("sk_test");
    expect(serialized).not.toContain(PRICE);
    expect(serialized).not.toContain(SECRET);
    expect(offer).not.toHaveProperty("priceId");
    expect(offer).not.toHaveProperty("price_id");
  });

  test("13E.0 getOffer ignores client amount args", async () => {
    setStripeEnv();
    const t = backend();
    const { authed } = await provision(t);
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => ({
        status: 200,
        json: async () => ({ unit_amount: 1999, currency: "eur" }),
      })),
    );
    let offer: { currency: string; unitAmount: number };
    try {
      offer = await authed.action(api.stripe.getOffer, {
        unitAmount: 1,
        currency: "usd",
      } as never);
    } catch {
      offer = await authed.action(api.stripe.getOffer, {});
    }
    expect(offer).toEqual({ currency: "eur", unitAmount: 1999 });
  });

  test("13E.0 getOffer missing config is unavailable", async () => {
    const t = backend();
    const { authed } = await provision(t);
    vi.stubGlobal("fetch", vi.fn());
    await expect(authed.action(api.stripe.getOffer, {})).rejects.toThrow(
      PurchaseUnavailableError,
    );
    expect(fetch).not.toHaveBeenCalled();
  });

  test("13E.0 processWebhook stays internal", () => {
    expect(api.stripe).not.toHaveProperty("processWebhook");
    expect(api.stripe).not.toHaveProperty("authedUser");
  });
});
