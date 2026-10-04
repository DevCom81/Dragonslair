import { afterEach, beforeAll, describe, expect, test, vi } from "vitest";
import { convexTest } from "convex-test";
import * as jose from "jose";
import type { MutationCtx } from "./_generated/server";
import type { Id } from "./_generated/dataModel";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import {
  GooglePlayConfigError,
  GooglePlayPendingError,
  GooglePlayPurchaseError,
  GooglePlayRtdnError,
  GooglePlayRtdnUnauthorizedError,
  GOOGLE_PLAY_ACCOUNT_MISMATCH,
  GOOGLE_PLAY_PACKAGE_MISMATCH,
  GOOGLE_PLAY_PRODUCT_MISMATCH,
  GOOGLE_PLAY_PURCHASE_INVALID,
  GOOGLE_PLAY_RTDN_INVALID,
  GOOGLE_PLAY_RTDN_UNAUTHORIZED,
  PURCHASE_PENDING,
} from "./lib/errors";
import { UnauthenticatedError } from "./lib/auth";
import { playObfuscatedAccountId } from "./lib/playAccountId";
import {
  decodePubsubPush,
  parseDeveloperNotification,
} from "./lib/googlePlayRtdn";

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

const PACKAGE = "com.jey.dragonslair";
const PRODUCT = "dragons_lair_unlock";
const AUDIENCE = "https://example.convex.site/google-play-rtdn";
const TOKEN = "opaque-play-token-1";
const LEGACY_UUID = "11111111-1111-4111-8111-111111111111";

let serviceAccountJson = "";
let oidcPrivateKey: jose.KeyLike;
let jwks: jose.JSONWebKeySet;

beforeAll(async () => {
  const accountKeys = await jose.generateKeyPair("RS256");
  const pkcs8 = await jose.exportPKCS8(accountKeys.privateKey);
  serviceAccountJson = JSON.stringify({
    private_key: pkcs8,
    client_email: "publisher@test.iam.gserviceaccount.com",
  });
  const oidcKeys = await jose.generateKeyPair("RS256", { extractable: true });
  oidcPrivateKey = oidcKeys.privateKey;
  const publicJwk = await jose.exportJWK(oidcKeys.publicKey);
  jwks = {
    keys: [{ ...publicJwk, kid: "rtdn-test", alg: "RS256", use: "sig" }],
  };
});

async function provision(
  t: ReturnType<typeof backend>,
  identity: typeof alice = alice,
) {
  const authed = t.withIdentity(identity);
  const user = await authed.mutation(api.users.ensureUser, {});
  return { authed, user: user! };
}

function setPlayEnv() {
  process.env.GOOGLE_PLAY_PACKAGE_NAME = PACKAGE;
  process.env.GOOGLE_PLAY_PRODUCT_ID = PRODUCT;
  process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = serviceAccountJson;
  process.env.GOOGLE_PLAY_RTDN_AUDIENCE = AUDIENCE;
}

function purchasePayload(args: {
  accountId: string;
  purchaseState?: number;
  packageName?: string;
  productId?: string;
  acknowledgementState?: number;
}) {
  return {
    purchaseState: args.purchaseState ?? 0,
    packageName: args.packageName ?? PACKAGE,
    productId: args.productId ?? PRODUCT,
    obfuscatedExternalAccountId: args.accountId,
    acknowledgementState: args.acknowledgementState ?? 0,
  };
}

function requestHref(input: RequestInfo | URL): string {
  if (typeof input === "string") {
    return input;
  }
  if (input instanceof URL) {
    return input.href;
  }
  if (typeof Request !== "undefined" && input instanceof Request) {
    return input.url;
  }
  return String(input);
}

function stubGoogle(args: {
  purchase?: Record<string, unknown>;
  lookupStatus?: number;
}) {
  const fetchMock = vi.fn(async (input: RequestInfo | URL) => {
    const href = requestHref(input);
    if (href.includes("/oauth2/v3/certs")) {
      return new Response(JSON.stringify(jwks), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    if (href.includes("oauth2.googleapis.com/token")) {
      return new Response(JSON.stringify({ access_token: "ya29.test-access" }), {
        status: 200,
      });
    }
    if (href.includes(":acknowledge")) {
      return new Response(null, { status: 204 });
    }
    if (href.includes("/purchases/products/")) {
      if ((args.lookupStatus ?? 200) >= 400) {
        return new Response("{}", { status: args.lookupStatus ?? 404 });
      }
      return new Response(JSON.stringify(args.purchase ?? {}), { status: 200 });
    }
    return new Response("missing", { status: 404 });
  });
  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
}

function pubsubBody(payload: Record<string, unknown>) {
  return {
    message: {
      messageId: "msg-1",
      data: btoa(JSON.stringify(payload)),
    },
  };
}

function productNotification(args?: {
  packageName?: string;
  sku?: string;
  purchaseToken?: string;
}) {
  return pubsubBody({
    packageName: args?.packageName ?? PACKAGE,
    oneTimeProductNotification: {
      notificationType: 1,
      purchaseToken: args?.purchaseToken ?? TOKEN,
      sku: args?.sku ?? PRODUCT,
    },
  });
}

async function signPushJwt(args?: {
  audience?: string;
  issuer?: string;
  key?: jose.KeyLike;
}) {
  return await new jose.SignJWT({})
    .setProtectedHeader({ alg: "RS256", kid: "rtdn-test", typ: "JWT" })
    .setIssuer(args?.issuer ?? "https://accounts.google.com")
    .setAudience(args?.audience ?? AUDIENCE)
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(args?.key ?? oidcPrivateKey);
}

async function accessOf(
  t: ReturnType<typeof backend>,
  userId: Id<"users">,
): Promise<string | undefined> {
  return await t.run(async (ctx: MutationCtx) => {
    const rows = await ctx.db
      .query("userEntitlements")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    return rows[0]?.accessLevel;
  });
}

async function playSources(
  t: ReturnType<typeof backend>,
  userId: Id<"users">,
) {
  return await t.run(async (ctx: MutationCtx) => {
    return await ctx.db
      .query("entitlementSources")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
  });
}

afterEach(() => {
  vi.unstubAllGlobals();
  delete process.env.GOOGLE_PLAY_PACKAGE_NAME;
  delete process.env.GOOGLE_PLAY_PRODUCT_ID;
  delete process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;
  delete process.env.GOOGLE_PLAY_RTDN_AUDIENCE;
});

describe("LOT 10 google play", () => {
  test("1 redeem unauthenticated is refused", async () => {
    setPlayEnv();
    const t = backend();
    stubGoogle({});
    await expect(
      t.action(api.googlePlay.redeem, { purchaseToken: TOKEN }),
    ).rejects.toThrow(UnauthenticatedError);
  });

  test("2-3 beneficiary is WorkOS user, client userId is ignored", async () => {
    setPlayEnv();
    const t = backend();
    const { authed, user } = await provision(t);
    const accountId = await playObfuscatedAccountId(alice.subject);
    stubGoogle({ purchase: purchasePayload({ accountId }) });
    try {
      await authed.action(api.googlePlay.redeem, {
        purchaseToken: TOKEN,
        userId: "user_01BOB",
      } as never);
    } catch {
      // Convex rejects extra args; either way beneficiary is not client-chosen.
    }
    const result = await authed.action(api.googlePlay.redeem, {
      purchaseToken: TOKEN,
    });
    expect(result.accessLevel).toBe("full");
    expect(await accessOf(t, user._id)).toBe("full");
    const sources = await playSources(t, user._id);
    expect(sources.filter((row) => row.provider === "google_play")).toHaveLength(
      1,
    );
  });

  test("4 wrong package is refused", async () => {
    setPlayEnv();
    const t = backend();
    const { authed } = await provision(t);
    const accountId = await playObfuscatedAccountId(alice.subject);
    stubGoogle({
      purchase: purchasePayload({
        accountId,
        packageName: "com.other.app",
      }),
    });
    await expect(
      authed.action(api.googlePlay.redeem, { purchaseToken: TOKEN }),
    ).rejects.toThrow(GooglePlayPurchaseError);
    await expect(
      authed.action(api.googlePlay.redeem, { purchaseToken: TOKEN }),
    ).rejects.toThrow(GOOGLE_PLAY_PACKAGE_MISMATCH);
  });

  test("5 wrong productId is refused", async () => {
    setPlayEnv();
    const t = backend();
    const { authed } = await provision(t);
    const accountId = await playObfuscatedAccountId(alice.subject);
    stubGoogle({
      purchase: purchasePayload({
        accountId,
        productId: "other_sku",
      }),
    });
    await expect(
      authed.action(api.googlePlay.redeem, { purchaseToken: TOKEN }),
    ).rejects.toThrow(GOOGLE_PLAY_PRODUCT_MISMATCH);
  });

  test("6 invalid purchaseToken is refused", async () => {
    setPlayEnv();
    const t = backend();
    const { authed } = await provision(t);
    stubGoogle({ lookupStatus: 404 });
    await expect(
      authed.action(api.googlePlay.redeem, { purchaseToken: TOKEN }),
    ).rejects.toThrow(GOOGLE_PLAY_PURCHASE_INVALID);
  });

  test("7 non-purchased does not grant full", async () => {
    setPlayEnv();
    const t = backend();
    const { authed, user } = await provision(t);
    const accountId = await playObfuscatedAccountId(alice.subject);
    stubGoogle({
      purchase: purchasePayload({ accountId, purchaseState: 2 }),
    });
    await expect(
      authed.action(api.googlePlay.redeem, { purchaseToken: TOKEN }),
    ).rejects.toThrow(GooglePlayPendingError);
    await expect(
      authed.action(api.googlePlay.redeem, { purchaseToken: TOKEN }),
    ).rejects.toThrow(PURCHASE_PENDING);
    expect(await accessOf(t, user._id)).toBe("demo");

    stubGoogle({
      purchase: purchasePayload({ accountId, purchaseState: 1 }),
    });
    const revoked = await authed.action(api.googlePlay.redeem, {
      purchaseToken: TOKEN,
    });
    expect(revoked.accessLevel).toBe("demo");
    expect(await accessOf(t, user._id)).toBe("demo");
  });

  test("8 WorkOS hash grants full", async () => {
    setPlayEnv();
    const t = backend();
    const { authed, user } = await provision(t);
    const accountId = await playObfuscatedAccountId(alice.subject);
    stubGoogle({ purchase: purchasePayload({ accountId }) });
    const result = await authed.action(api.googlePlay.redeem, {
      purchaseToken: TOKEN,
    });
    expect(result.accessLevel).toBe("full");
    expect(result.metadata?.provider).toBe("google_play");
    expect(await accessOf(t, user._id)).toBe("full");
  });

  test("9 legacy hash of the same user grants full", async () => {
    setPlayEnv();
    const t = backend();
    const { authed, user } = await provision(t);
    await t.run(async (ctx: MutationCtx) => {
      await ctx.db.patch(user._id, { legacyUuid: LEGACY_UUID });
    });
    const accountId = await playObfuscatedAccountId(LEGACY_UUID);
    stubGoogle({ purchase: purchasePayload({ accountId }) });
    const result = await authed.action(api.googlePlay.redeem, {
      purchaseToken: TOKEN,
    });
    expect(result.accessLevel).toBe("full");
    expect(await accessOf(t, user._id)).toBe("full");
  });

  test("10 legacy hash of another user is refused", async () => {
    setPlayEnv();
    const t = backend();
    const { authed, user } = await provision(t);
    await t.run(async (ctx: MutationCtx) => {
      await ctx.db.patch(user._id, { legacyUuid: LEGACY_UUID });
    });
    const otherLegacy = await playObfuscatedAccountId(
      "22222222-2222-4222-8222-222222222222",
    );
    stubGoogle({ purchase: purchasePayload({ accountId: otherLegacy }) });
    await expect(
      authed.action(api.googlePlay.redeem, { purchaseToken: TOKEN }),
    ).rejects.toThrow(GOOGLE_PLAY_ACCOUNT_MISMATCH);
    expect(await accessOf(t, user._id)).toBe("demo");
  });

  test("11 WorkOS hash of another user is refused", async () => {
    setPlayEnv();
    const t = backend();
    const { authed, user } = await provision(t);
    const bobHash = await playObfuscatedAccountId(bob.subject);
    stubGoogle({ purchase: purchasePayload({ accountId: bobHash }) });
    await expect(
      authed.action(api.googlePlay.redeem, { purchaseToken: TOKEN }),
    ).rejects.toThrow(GOOGLE_PLAY_ACCOUNT_MISMATCH);
    expect(await accessOf(t, user._id)).toBe("demo");
  });

  test("12-13 valid redeem creates google_play source and is idempotent", async () => {
    setPlayEnv();
    const t = backend();
    const { authed, user } = await provision(t);
    const accountId = await playObfuscatedAccountId(alice.subject);
    stubGoogle({ purchase: purchasePayload({ accountId }) });
    await authed.action(api.googlePlay.redeem, { purchaseToken: TOKEN });
    await authed.action(api.googlePlay.redeem, { purchaseToken: TOKEN });
    const sources = (await playSources(t, user._id)).filter(
      (row) => row.provider === "google_play",
    );
    expect(sources).toHaveLength(1);
    expect(sources[0]?.status).toBe("active");
  });

  test("14 same providerRef cannot be granted to two users", async () => {
    setPlayEnv();
    const t = backend();
    const aliceCtx = await provision(t, alice);
    const bobCtx = await provision(t, bob);
    stubGoogle({
      purchase: purchasePayload({
        accountId: await playObfuscatedAccountId(alice.subject),
      }),
    });
    await aliceCtx.authed.action(api.googlePlay.redeem, {
      purchaseToken: TOKEN,
    });
    stubGoogle({
      purchase: purchasePayload({
        accountId: await playObfuscatedAccountId(bob.subject),
      }),
    });
    await expect(
      bobCtx.authed.action(api.googlePlay.redeem, { purchaseToken: TOKEN }),
    ).rejects.toThrow(GOOGLE_PLAY_ACCOUNT_MISMATCH);
    expect(await accessOf(t, bobCtx.user._id)).toBe("demo");
    const bobSources = (await playSources(t, bobCtx.user._id)).filter(
      (row) => row.provider === "google_play",
    );
    expect(bobSources).toHaveLength(0);
  });

  test("15-17 google revoke, stripe remains full, last source drops to demo", async () => {
    setPlayEnv();
    const t = backend();
    const { authed, user } = await provision(t);
    const accountId = await playObfuscatedAccountId(alice.subject);
    stubGoogle({ purchase: purchasePayload({ accountId }) });
    await authed.action(api.googlePlay.redeem, { purchaseToken: TOKEN });
    await t.mutation(internal.entitlements.applyStripeCheckoutGrant, {
      clientReferenceId: user._id,
      metadataUserId: user._id,
      workosSubject: alice.subject,
      sessionId: "cs_play_multi",
      paymentIntentId: "pi_play_multi",
    });
    expect(await accessOf(t, user._id)).toBe("full");
    const jwt = await signPushJwt();
    stubGoogle({
      purchase: purchasePayload({ accountId, purchaseState: 1 }),
    });
    const revoked = await t.action(internal.googlePlay.processRtdn, {
      authorization: `Bearer ${jwt}`,
      body: productNotification(),
    });
    expect(revoked.status).toBe("ok");
    expect(await accessOf(t, user._id)).toBe("full");
    const play = (await playSources(t, user._id)).find(
      (row) => row.provider === "google_play",
    );
    expect(play?.status).toBe("revoked");

    await t.mutation(internal.entitlements.applyStripeRefund, {
      userId: user._id,
      paymentIntentId: "pi_play_multi",
      workosSubject: alice.subject,
    });
    expect(await accessOf(t, user._id)).toBe("demo");
  });

  test("18 RTDN without auth is refused", async () => {
    setPlayEnv();
    const t = backend();
    stubGoogle({});
    await expect(
      t.action(internal.googlePlay.processRtdn, {
        authorization: "",
        body: productNotification(),
      }),
    ).rejects.toThrow(GooglePlayRtdnUnauthorizedError);
    await expect(
      t.action(internal.googlePlay.processRtdn, {
        authorization: "",
        body: productNotification(),
      }),
    ).rejects.toThrow(GOOGLE_PLAY_RTDN_UNAUTHORIZED);
  });

  test("19 RTDN wrong issuer audience or signature is refused", async () => {
    setPlayEnv();
    const t = backend();
    stubGoogle({});
    const otherKeys = await jose.generateKeyPair("RS256");
    const badIssuer = await signPushJwt({ issuer: "https://evil.example" });
    const badAud = await signPushJwt({
      audience: "https://old-railway.example/google-rtdn",
    });
    const badSig = await signPushJwt({ key: otherKeys.privateKey });
    await expect(
      t.action(internal.googlePlay.processRtdn, {
        authorization: `Bearer ${badIssuer}`,
        body: productNotification(),
      }),
    ).rejects.toThrow(GooglePlayRtdnUnauthorizedError);
    await expect(
      t.action(internal.googlePlay.processRtdn, {
        authorization: `Bearer ${badAud}`,
        body: productNotification(),
      }),
    ).rejects.toThrow(GooglePlayRtdnUnauthorizedError);
    await expect(
      t.action(internal.googlePlay.processRtdn, {
        authorization: `Bearer ${badSig}`,
        body: productNotification(),
      }),
    ).rejects.toThrow(GooglePlayRtdnUnauthorizedError);
  });

  test("20-21 authenticated RTDN is accepted; testNotification does not mutate", async () => {
    setPlayEnv();
    const t = backend();
    const { user } = await provision(t);
    const jwt = await signPushJwt();
    stubGoogle({});
    const result = await t.action(internal.googlePlay.processRtdn, {
      authorization: `Bearer ${jwt}`,
      body: pubsubBody({ testNotification: { version: "1.0" } }),
    });
    expect(result).toEqual({ status: "ignored", reason: "test" });
    expect((await playSources(t, user._id)).filter((row) => row.provider === "google_play")).toHaveLength(
      0,
    );
    expect(await accessOf(t, user._id)).toBe("demo");
  });

  test("22 invalid Pub/Sub data is a safe error", async () => {
    setPlayEnv();
    const t = backend();
    stubGoogle({});
    const jwt = await signPushJwt();
    await expect(
      t.action(internal.googlePlay.processRtdn, {
        authorization: `Bearer ${jwt}`,
        body: { not: "pubsub" },
      }),
    ).rejects.toThrow(GooglePlayRtdnError);
    await expect(
      t.action(internal.googlePlay.processRtdn, {
        authorization: `Bearer ${jwt}`,
        body: { not: "pubsub" },
      }),
    ).rejects.toThrow(GOOGLE_PLAY_RTDN_INVALID);
  });

  test("23-24 RTDN wrong package or product does not mutate", async () => {
    setPlayEnv();
    const t = backend();
    const { authed, user } = await provision(t);
    const accountId = await playObfuscatedAccountId(alice.subject);
    stubGoogle({ purchase: purchasePayload({ accountId }) });
    await authed.action(api.googlePlay.redeem, { purchaseToken: TOKEN });
    const before = await playSources(t, user._id);
    const jwt = await signPushJwt();
    const pkg = await t.action(internal.googlePlay.processRtdn, {
      authorization: `Bearer ${jwt}`,
      body: productNotification({ packageName: "com.other.app" }),
    });
    expect(pkg).toEqual({ status: "ignored", reason: "package_mismatch" });
    const sku = await t.action(internal.googlePlay.processRtdn, {
      authorization: `Bearer ${jwt}`,
      body: productNotification({ sku: "other_sku" }),
    });
    expect(sku).toEqual({ status: "ignored", reason: "product_mismatch" });
    const after = await playSources(t, user._id);
    expect(after).toEqual(before);
  });

  test("25-26 RTDN revalidates Google API and is idempotent", async () => {
    setPlayEnv();
    const t = backend();
    const { authed, user } = await provision(t);
    const accountId = await playObfuscatedAccountId(alice.subject);
    const fetchMock = stubGoogle({
      purchase: purchasePayload({ accountId }),
    });
    await authed.action(api.googlePlay.redeem, { purchaseToken: TOKEN });
    fetchMock.mockClear();
    const jwt = await signPushJwt();
    const first = await t.action(internal.googlePlay.processRtdn, {
      authorization: `Bearer ${jwt}`,
      body: productNotification(),
    });
    const second = await t.action(internal.googlePlay.processRtdn, {
      authorization: `Bearer ${jwt}`,
      body: productNotification(),
    });
    expect(first.status).toBe("ok");
    expect(second.status).toBe("ok");
    const publisherCalls = fetchMock.mock.calls.filter((call) =>
      String(call[0]).includes("/purchases/products/"),
    );
    expect(publisherCalls.length).toBeGreaterThan(0);
    const sources = (await playSources(t, user._id)).filter(
      (row) => row.provider === "google_play",
    );
    expect(sources).toHaveLength(1);
    expect(await accessOf(t, user._id)).toBe("full");
  });

  test("27 stale RTDN does not resurrect a revoked source", async () => {
    setPlayEnv();
    const t = backend();
    const { authed, user } = await provision(t);
    const accountId = await playObfuscatedAccountId(alice.subject);
    stubGoogle({ purchase: purchasePayload({ accountId }) });
    await authed.action(api.googlePlay.redeem, { purchaseToken: TOKEN });
    const jwt = await signPushJwt();
    stubGoogle({
      purchase: purchasePayload({ accountId, purchaseState: 1 }),
    });
    await t.action(internal.googlePlay.processRtdn, {
      authorization: `Bearer ${jwt}`,
      body: productNotification(),
    });
    stubGoogle({
      purchase: purchasePayload({ accountId, purchaseState: 0 }),
    });
    await t.action(internal.googlePlay.processRtdn, {
      authorization: `Bearer ${jwt}`,
      body: productNotification(),
    });
    const play = (await playSources(t, user._id)).find(
      (row) => row.provider === "google_play",
    );
    expect(play?.status).toBe("revoked");
    expect(await accessOf(t, user._id)).toBe("demo");
  });

  test("unconfigured google play is unavailable", async () => {
    const t = backend();
    const { authed } = await provision(t);
    await expect(
      authed.action(api.googlePlay.redeem, { purchaseToken: TOKEN }),
    ).rejects.toThrow(GooglePlayConfigError);
  });
});

describe("google play rtdn parse", () => {
  test("parses test, product, and subscription envelopes", () => {
    const testNote = parseDeveloperNotification({
      testNotification: { version: "1" },
    });
    expect(testNote).toEqual({ kind: "test" });
    const product = parseDeveloperNotification({
      packageName: PACKAGE,
      oneTimeProductNotification: {
        sku: PRODUCT,
        purchaseToken: TOKEN,
        notificationType: 1,
      },
    });
    expect(product?.kind).toBe("product");
    expect(parseDeveloperNotification({
      subscriptionNotification: { notificationType: 2 },
    })).toEqual({ kind: "ignored_subscription" });
  });

  test("rejects invalid pubsub envelopes", () => {
    expect(() => decodePubsubPush({})).toThrow(GooglePlayRtdnError);
    expect(() => decodePubsubPush({ message: {} })).toThrow(GooglePlayRtdnError);
  });
});

describe("LOT 13E.0 googlePlay.billingIdentity", () => {
  test("rejects missing auth", async () => {
    const t = backend();
    await expect(
      t.query(api.googlePlay.billingIdentity, {}),
    ).rejects.toBeInstanceOf(UnauthenticatedError);
  });

  test("returns WorkOS hash, not legacyUuid hash or raw ids", async () => {
    const t = backend();
    const { authed, user } = await provision(t);
    await t.run(async (ctx: MutationCtx) => {
      await ctx.db.patch(user._id, { legacyUuid: LEGACY_UUID });
    });
    const first = await authed.query(api.googlePlay.billingIdentity, {});
    const second = await authed.query(api.googlePlay.billingIdentity, {});
    const workosHash = await playObfuscatedAccountId(alice.subject);
    const legacyHash = await playObfuscatedAccountId(LEGACY_UUID);
    expect(first.obfuscatedAccountId).toBe(workosHash);
    expect(second.obfuscatedAccountId).toBe(workosHash);
    expect(first.obfuscatedAccountId).not.toBe(legacyHash);
    expect(first.obfuscatedAccountId).toHaveLength(64);
    const serialized = JSON.stringify(first);
    expect(serialized).not.toContain(alice.subject);
    expect(serialized).not.toContain(LEGACY_UUID);
    expect(serialized).not.toContain(user._id);
    expect(first).not.toHaveProperty("workosHash");
    expect(first).not.toHaveProperty("legacyHash");
    expect(first).not.toHaveProperty("accepted");
  });

  test("distinct users receive distinct billing identities", async () => {
    const t = backend();
    const aliceAuthed = t.withIdentity(alice);
    const bobAuthed = t.withIdentity(bob);
    await aliceAuthed.mutation(api.users.ensureUser, {});
    await bobAuthed.mutation(api.users.ensureUser, {});
    const aliceId = await aliceAuthed.query(api.googlePlay.billingIdentity, {});
    const bobId = await bobAuthed.query(api.googlePlay.billingIdentity, {});
    expect(aliceId.obfuscatedAccountId).not.toBe(bobId.obfuscatedAccountId);
    expect(aliceId.obfuscatedAccountId).toBe(
      await playObfuscatedAccountId(alice.subject),
    );
    expect(bobId.obfuscatedAccountId).toBe(
      await playObfuscatedAccountId(bob.subject),
    );
  });

  test("does not expose redeem internals as public queries", () => {
    expect(api.googlePlay).not.toHaveProperty("processRtdn");
    expect(api.googlePlay).not.toHaveProperty("authedUser");
  });
});
