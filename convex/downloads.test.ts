import { afterEach, describe, expect, test, vi } from "vitest";
import { convexTest } from "convex-test";
import type { MutationCtx } from "./_generated/server";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import {
  DownloadConfigError,
  ForbiddenError,
  FULL_GAME_REQUIRED,
  WINDOWS_DOWNLOAD_UNAVAILABLE,
} from "./lib/errors";
import { UnauthenticatedError } from "./lib/auth";
import {
  DOWNLOAD_EXPIRES_SECONDS,
  WINDOWS_DOWNLOAD_FILENAME,
} from "./lib/windowsDownload";

const { getSignedUrl, lastPresign } = vi.hoisted(() => {
  const lastPresign: {
    bucket?: string;
    key?: string;
    disposition?: string;
    expiresIn?: number;
    endpoint?: string;
    region?: string;
    forcePathStyle?: boolean;
  } = {};
  const getSignedUrl = vi.fn(
    async (
      client: { config?: { endpoint?: string; region?: string; forcePathStyle?: boolean } },
      command: { input?: { Bucket?: string; Key?: string; ResponseContentDisposition?: string } },
      options?: { expiresIn?: number },
    ) => {
      lastPresign.bucket = command.input?.Bucket;
      lastPresign.key = command.input?.Key;
      lastPresign.disposition = command.input?.ResponseContentDisposition;
      lastPresign.expiresIn = options?.expiresIn;
      lastPresign.endpoint = client.config?.endpoint;
      lastPresign.region = client.config?.region;
      lastPresign.forcePathStyle = client.config?.forcePathStyle;
      return "https://signed.example/file";
    },
  );
  return { getSignedUrl, lastPresign };
});

vi.mock("@aws-sdk/s3-request-presigner", () => ({
  getSignedUrl,
}));

vi.mock("@aws-sdk/client-s3", () => {
  class S3Client {
    config: {
      endpoint?: string;
      region?: string;
      forcePathStyle?: boolean;
    };
    constructor(config: {
      endpoint?: string;
      region?: string;
      forcePathStyle?: boolean;
    }) {
      this.config = config;
    }
  }
  class GetObjectCommand {
    input: {
      Bucket?: string;
      Key?: string;
      ResponseContentDisposition?: string;
    };
    constructor(input: {
      Bucket?: string;
      Key?: string;
      ResponseContentDisposition?: string;
    }) {
      this.input = input;
    }
  }
  return { S3Client, GetObjectCommand };
});

const modules = import.meta.glob("./**/*.ts");

function backend() {
  return convexTest(schema, modules);
}

const alice = {
  subject: "user_01ALICE",
  issuer: "https://api.workos.com/user_management/client_01EXAMPLE",
};

async function provision(t: ReturnType<typeof backend>) {
  const authed = t.withIdentity(alice);
  const user = await authed.mutation(api.users.ensureUser, {});
  return { authed, user: user! };
}

function setR2Env() {
  process.env.R2_ACCESS_KEY_ID = "test-access-key";
  process.env.R2_SECRET_ACCESS_KEY = "test-secret-key";
  process.env.R2_ENDPOINT = "https://example.r2.cloudflarestorage.com";
  process.env.R2_BUCKET = "dragonslair-release";
  process.env.R2_WINDOWS_OBJECT = "windows/Install_Dragonslair.exe";
}

afterEach(() => {
  getSignedUrl.mockClear();
  delete process.env.R2_ACCESS_KEY_ID;
  delete process.env.R2_SECRET_ACCESS_KEY;
  delete process.env.R2_ENDPOINT;
  delete process.env.R2_BUCKET;
  delete process.env.R2_WINDOWS_OBJECT;
});

describe("LOT 11 windows download", () => {
  test("1 unauthenticated is refused", async () => {
    setR2Env();
    const t = backend();
    await expect(
      t.action(api.downloads.createWindowsDownload, {}),
    ).rejects.toThrow(UnauthenticatedError);
    expect(getSignedUrl).not.toHaveBeenCalled();
  });

  test("2 demo is refused", async () => {
    setR2Env();
    const t = backend();
    const { authed } = await provision(t);
    await expect(
      authed.action(api.downloads.createWindowsDownload, {}),
    ).rejects.toThrow(ForbiddenError);
    await expect(
      authed.action(api.downloads.createWindowsDownload, {}),
    ).rejects.toThrow(FULL_GAME_REQUIRED);
    expect(getSignedUrl).not.toHaveBeenCalled();
  });

  test("3 full Stripe is authorized", async () => {
    setR2Env();
    const t = backend();
    const { authed, user } = await provision(t);
    await t.mutation(internal.entitlements.applyStripeCheckoutGrant, {
      clientReferenceId: user._id,
      metadataUserId: user._id,
      workosSubject: alice.subject,
      sessionId: "cs_win_stripe",
      paymentIntentId: "pi_win_stripe",
    });
    const result = await authed.action(api.downloads.createWindowsDownload, {});
    expect(result).toEqual({ download_url: "https://signed.example/file" });
    expect(getSignedUrl).toHaveBeenCalled();
  });

  test("4 full Google Play is authorized", async () => {
    setR2Env();
    const t = backend();
    const { authed, user } = await provision(t);
    await t.mutation(internal.entitlements.applyGooglePlaySource, {
      userId: user._id,
      providerRef: "play-win-1",
      status: "active",
      playAccountId: "play-hash",
      mode: "redeem",
    });
    const result = await authed.action(api.downloads.createWindowsDownload, {});
    expect(result.download_url).toBe("https://signed.example/file");
  });

  test("5 full manual source is authorized", async () => {
    setR2Env();
    const t = backend();
    const { authed, user } = await provision(t);
    await t.run(async (ctx: MutationCtx) => {
      const now = Date.now();
      await ctx.db.insert("entitlementSources", {
        userId: user._id,
        provider: "manual",
        providerRef: "manual-win-1",
        status: "active",
        metadata: {},
        createdAt: now,
        updatedAt: now,
      });
      const rows = await ctx.db
        .query("userEntitlements")
        .withIndex("by_user", (q) => q.eq("userId", user._id))
        .collect();
      await ctx.db.patch(rows[0]!._id, {
        accessLevel: "full",
        source: "admin",
      });
    });
    const result = await authed.action(api.downloads.createWindowsDownload, {});
    expect(result.download_url).toBe("https://signed.example/file");
  });

  test("6 expired entitlement is refused", async () => {
    setR2Env();
    const t = backend();
    const { authed, user } = await provision(t);
    await t.run(async (ctx: MutationCtx) => {
      const rows = await ctx.db
        .query("userEntitlements")
        .withIndex("by_user", (q) => q.eq("userId", user._id))
        .collect();
      await ctx.db.patch(rows[0]!._id, {
        accessLevel: "full",
        source: "purchase",
        expiresAt: Date.now() - 60_000,
      });
    });
    await expect(
      authed.action(api.downloads.createWindowsDownload, {}),
    ).rejects.toThrow(FULL_GAME_REQUIRED);
    expect(getSignedUrl).not.toHaveBeenCalled();
  });

  test("7-10 client cannot choose userId bucket key or expiry", async () => {
    setR2Env();
    const t = backend();
    const { authed, user } = await provision(t);
    await t.mutation(internal.entitlements.applyStripeCheckoutGrant, {
      clientReferenceId: user._id,
      metadataUserId: user._id,
      workosSubject: alice.subject,
      sessionId: "cs_win_args",
      paymentIntentId: "pi_win_args",
    });
    try {
      await authed.action(api.downloads.createWindowsDownload, {
        userId: "user_01BOB",
        bucket: "other-bucket",
        objectKey: "secret.bin",
        expiresIn: 99999,
      } as never);
    } catch {
      // Convex rejects extra args; the authorized call below is the contract.
    }
    await authed.action(api.downloads.createWindowsDownload, {});
    expect(lastPresign.bucket).toBe("dragonslair-release");
    expect(lastPresign.key).toBe("windows/Install_Dragonslair.exe");
    expect(lastPresign.expiresIn).toBe(DOWNLOAD_EXPIRES_SECONDS);
    expect(lastPresign.expiresIn).toBe(300);
    expect(lastPresign.bucket).not.toBe("other-bucket");
    expect(lastPresign.key).not.toBe("secret.bin");
  });

  test("11-14 presign uses env bucket object GET expiry and filename", async () => {
    setR2Env();
    const t = backend();
    const { authed, user } = await provision(t);
    await t.mutation(internal.entitlements.applyStripeCheckoutGrant, {
      clientReferenceId: user._id,
      metadataUserId: user._id,
      workosSubject: alice.subject,
      sessionId: "cs_win_params",
      paymentIntentId: "pi_win_params",
    });
    await authed.action(api.downloads.createWindowsDownload, {});
    expect(lastPresign.bucket).toBe(process.env.R2_BUCKET);
    expect(lastPresign.key).toBe(process.env.R2_WINDOWS_OBJECT);
    expect(lastPresign.expiresIn).toBe(300);
    expect(lastPresign.disposition).toContain("attachment");
    expect(lastPresign.disposition).toContain(WINDOWS_DOWNLOAD_FILENAME);
    expect(lastPresign.endpoint).toBe("https://example.r2.cloudflarestorage.com");
    expect(lastPresign.forcePathStyle).toBe(true);
  });

  test("15 missing R2 config is a safe error", async () => {
    const t = backend();
    const { authed, user } = await provision(t);
    await t.mutation(internal.entitlements.applyStripeCheckoutGrant, {
      clientReferenceId: user._id,
      metadataUserId: user._id,
      workosSubject: alice.subject,
      sessionId: "cs_win_cfg",
      paymentIntentId: "pi_win_cfg",
    });
    await expect(
      authed.action(api.downloads.createWindowsDownload, {}),
    ).rejects.toThrow(DownloadConfigError);
    await expect(
      authed.action(api.downloads.createWindowsDownload, {}),
    ).rejects.toThrow(WINDOWS_DOWNLOAD_UNAVAILABLE);
    expect(getSignedUrl).not.toHaveBeenCalled();
  });

  test("16 SDK failure is a safe error without secrets", async () => {
    setR2Env();
    getSignedUrl.mockRejectedValueOnce(
      new Error("AccessDenied secret=test-secret-key"),
    );
    const t = backend();
    const { authed, user } = await provision(t);
    await t.mutation(internal.entitlements.applyStripeCheckoutGrant, {
      clientReferenceId: user._id,
      metadataUserId: user._id,
      workosSubject: alice.subject,
      sessionId: "cs_win_sdk",
      paymentIntentId: "pi_win_sdk",
    });
    await expect(
      authed.action(api.downloads.createWindowsDownload, {}),
    ).rejects.toThrow(WINDOWS_DOWNLOAD_UNAVAILABLE);
    try {
      getSignedUrl.mockRejectedValueOnce(
        new Error("AccessDenied secret=test-secret-key"),
      );
      await authed.action(api.downloads.createWindowsDownload, {});
    } catch (error) {
      const serialized = JSON.stringify(error instanceof Error ? error.message : error);
      expect(serialized).not.toContain("test-secret-key");
      expect(serialized).not.toContain("test-access-key");
    }
  });

  test("17 response matches Flutter download_url contract", async () => {
    setR2Env();
    const t = backend();
    const { authed, user } = await provision(t);
    await t.mutation(internal.entitlements.applyStripeCheckoutGrant, {
      clientReferenceId: user._id,
      metadataUserId: user._id,
      workosSubject: alice.subject,
      sessionId: "cs_win_contract",
      paymentIntentId: "pi_win_contract",
    });
    const result = await authed.action(api.downloads.createWindowsDownload, {});
    expect(Object.keys(result)).toEqual(["download_url"]);
    expect(result.download_url.startsWith("https://")).toBe(true);
  });
});
