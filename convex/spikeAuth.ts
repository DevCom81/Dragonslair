import { action } from "./_generated/server";
import { v } from "convex/values";

const WORKOS_AUTHENTICATE_URL =
  "https://api.workos.com/user_management/authenticate";

const EMAIL_VERIFICATION_GRANT =
  "urn:workos:oauth:grant-type:email-verification:code";

type TokenPair = { accessToken: string; refreshToken: string };

type SignInResult =
  | ({ status: "authenticated" } & TokenPair)
  | {
      status: "email_verification_required";
      email: string;
      pendingAuthenticationToken: string;
    };

export const signInWithPassword = action({
  args: {
    email: v.string(),
    password: v.string(),
  },
  handler: async (_ctx, args): Promise<SignInResult> => {
    const credentials = workosCredentials();
    const email = args.email.trim();
    if (!email || !args.password) {
      throw new Error("Email and password are required.");
    }

    const payload = await postAuthenticate({
      client_id: credentials.clientId,
      client_secret: credentials.apiKey,
      grant_type: "password",
      email,
      password: args.password,
    });

    return toSignInResult(payload);
  },
});

export const verifyEmailCode = action({
  args: {
    code: v.string(),
    pendingAuthenticationToken: v.string(),
  },
  handler: async (_ctx, args): Promise<TokenPair> => {
    const credentials = workosCredentials();
    const code = args.code.trim();
    const pendingAuthenticationToken = args.pendingAuthenticationToken.trim();
    if (!code || !pendingAuthenticationToken) {
      throw new Error("Verification code is required.");
    }

    const payload = await postAuthenticate({
      client_id: credentials.clientId,
      client_secret: credentials.apiKey,
      grant_type: EMAIL_VERIFICATION_GRANT,
      code,
      pending_authentication_token: pendingAuthenticationToken,
    });

    if (!payload.ok) {
      throw new Error(workosPublicError(payload.json, payload.status));
    }
    const accessToken = readAccessToken(payload.json);
    if (!accessToken) {
      throw new Error(
        `WorkOS authentication succeeded without an access token (HTTP ${payload.status}).`,
      );
    }
    const refreshToken = readRefreshToken(payload.json);
    if (!refreshToken) {
      throw new Error(
        `WorkOS authentication succeeded without a refresh token (HTTP ${payload.status}).`,
      );
    }
    return { accessToken, refreshToken };
  },
});

export const refreshSession = action({
  args: {
    refreshToken: v.string(),
  },
  handler: async (_ctx, args): Promise<TokenPair> => {
    const credentials = workosCredentials();
    const refreshToken = args.refreshToken.trim();
    if (!refreshToken) {
      throw new Error("Refresh token is required.");
    }
    const payload = await postAuthenticate({
      client_id: credentials.clientId,
      client_secret: credentials.apiKey,
      grant_type: "refresh_token",
      refresh_token: refreshToken,
    });
    if (!payload.ok) {
      throw new Error(workosPublicError(payload.json, payload.status));
    }
    const accessToken = readAccessToken(payload.json);
    const nextRefresh = readRefreshToken(payload.json) ?? refreshToken;
    if (!accessToken) {
      throw new Error(
        `WorkOS refresh succeeded without an access token (HTTP ${payload.status}).`,
      );
    }
    return { accessToken, refreshToken: nextRefresh };
  },
});

const WORKOS_USERS_URL = "https://api.workos.com/user_management/users";
const WORKOS_PASSWORD_RESET_URL =
  "https://api.workos.com/user_management/password_reset";

export const signUpWithPassword = action({
  args: {
    email: v.string(),
    password: v.string(),
  },
  handler: async (_ctx, args): Promise<SignInResult> => {
    const credentials = workosCredentials();
    const email = args.email.trim();
    if (!email || !args.password) {
      throw new Error("Email and password are required.");
    }

    const created = await postWorkosJson(WORKOS_USERS_URL, {
      apiKey: credentials.apiKey,
      body: { email, password: args.password },
    });
    if (!created.ok && !isExistingUserConflict(created.json)) {
      throw new Error("Unable to create the account.");
    }
    if (!created.ok && isExistingUserConflict(created.json)) {
      throw new Error("Unable to create the account.");
    }

    const payload = await postAuthenticate({
      client_id: credentials.clientId,
      client_secret: credentials.apiKey,
      grant_type: "password",
      email,
      password: args.password,
    });
    return toSignInResult(payload);
  },
});

export const requestPasswordReset = action({
  args: {
    email: v.string(),
  },
  handler: async (_ctx, args): Promise<{ status: "sent" }> => {
    const credentials = workosCredentials();
    const email = args.email.trim();
    if (!email) {
      throw new Error("Email is required.");
    }
    try {
      await postWorkosJson(WORKOS_PASSWORD_RESET_URL, {
        apiKey: credentials.apiKey,
        body: { email },
      });
    } catch {
      // Timing and existence must not leak to the client.
    }
    return { status: "sent" };
  },
});

function workosCredentials(): { apiKey: string; clientId: string } {
  const apiKey = process.env.WORKOS_API_KEY?.trim();
  const clientId = process.env.WORKOS_CLIENT_ID?.trim();
  if (!apiKey || !clientId) {
    throw new Error("WorkOS is not configured on the Convex deployment.");
  }
  return { apiKey, clientId };
}

async function postAuthenticate(
  body: Record<string, string>,
): Promise<{ ok: boolean; status: number; json: unknown }> {
  const response = await fetch(WORKOS_AUTHENTICATE_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const json: unknown = await response.json().catch(() => null);
  return { ok: response.ok, status: response.status, json };
}

async function postWorkosJson(
  url: string,
  args: { apiKey: string; body: Record<string, string> },
): Promise<{ ok: boolean; status: number; json: unknown }> {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${args.apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(args.body),
  });
  const json: unknown = await response.json().catch(() => null);
  return { ok: response.ok, status: response.status, json };
}

function isExistingUserConflict(json: unknown): boolean {
  const code = readStringField(json, "code") ?? readStringField(json, "error");
  return (
    code === "email_not_available" ||
    code === "user_already_exists" ||
    code === "entity_already_exists"
  );
}

function toSignInResult(payload: {
  ok: boolean;
  status: number;
  json: unknown;
}): SignInResult {
  if (isEmailVerificationRequired(payload.json)) {
    const pending = readStringField(
      payload.json,
      "pending_authentication_token",
    );
    const email = readStringField(payload.json, "email") ?? "";
    if (!pending) {
      throw new Error("WorkOS required email verification without a token.");
    }
    return {
      status: "email_verification_required",
      email,
      pendingAuthenticationToken: pending,
    };
  }

  if (!payload.ok) {
    throw new Error(workosPublicError(payload.json, payload.status));
  }
  const accessToken = readAccessToken(payload.json);
  const refreshToken = readRefreshToken(payload.json);
  if (!accessToken) {
    throw new Error("WorkOS did not return an access token.");
  }
  if (!refreshToken) {
    throw new Error("WorkOS did not return a refresh token.");
  }
  return { status: "authenticated", accessToken, refreshToken };
}

function isEmailVerificationRequired(json: unknown): boolean {
  return readStringField(json, "code") === "email_verification_required";
}

function readAccessToken(json: unknown): string | null {
  return readStringField(json, "access_token");
}

function readRefreshToken(json: unknown): string | null {
  return readStringField(json, "refresh_token");
}

function readStringField(json: unknown, key: string): string | null {
  if (json === null || typeof json !== "object") {
    return null;
  }
  const value = (json as Record<string, unknown>)[key];
  if (typeof value !== "string" || !value.trim()) {
    return null;
  }
  return value.trim();
}

function workosPublicError(payload: unknown, status: number): string {
  const code = readStringField(payload, "code") ?? readStringField(payload, "error");
  const message = readStringField(payload, "message");
  const parts = [`HTTP ${status}`];
  if (code) {
    parts.push(code);
  }
  if (message) {
    parts.push(message);
  }
  return parts.join(" — ");
}
