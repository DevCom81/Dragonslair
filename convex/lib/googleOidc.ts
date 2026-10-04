import * as jose from "jose";
import {
  GooglePlayRtdnUnauthorizedError,
  GOOGLE_PLAY_RTDN_UNAUTHORIZED,
} from "./errors";

export const GOOGLE_OIDC_ISSUERS = [
  "https://accounts.google.com",
  "accounts.google.com",
] as const;

export const GOOGLE_OIDC_JWKS_URL =
  "https://www.googleapis.com/oauth2/v3/certs";

export function googlePlayRtdnAudience() {
  return (process.env.GOOGLE_PLAY_RTDN_AUDIENCE ?? "").trim();
}

export function isRtdnConfigured() {
  return Boolean(googlePlayRtdnAudience());
}

function isJsonWebKeySet(value: unknown): value is jose.JSONWebKeySet {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  const keys = (value as { keys?: unknown }).keys;
  return Array.isArray(keys);
}

async function loadGoogleOidcJwkSet(): Promise<jose.JWTVerifyGetKey> {
  let response: Response;
  try {
    response = await fetch(GOOGLE_OIDC_JWKS_URL, {
      headers: { Accept: "application/json" },
    });
  } catch {
    throw new GooglePlayRtdnUnauthorizedError(GOOGLE_PLAY_RTDN_UNAUTHORIZED);
  }
  if (response.status !== 200) {
    throw new GooglePlayRtdnUnauthorizedError(GOOGLE_PLAY_RTDN_UNAUTHORIZED);
  }
  let body: unknown;
  try {
    body = await response.json();
  } catch {
    throw new GooglePlayRtdnUnauthorizedError(GOOGLE_PLAY_RTDN_UNAUTHORIZED);
  }
  if (!isJsonWebKeySet(body)) {
    throw new GooglePlayRtdnUnauthorizedError(GOOGLE_PLAY_RTDN_UNAUTHORIZED);
  }
  return jose.createLocalJWKSet(body);
}

export async function verifyPubsubPushJwt(args: {
  authorization: string | null | undefined;
  audience: string;
  jwks?: jose.JWTVerifyGetKey;
}): Promise<void> {
  if (!args.audience) {
    throw new GooglePlayRtdnUnauthorizedError(GOOGLE_PLAY_RTDN_UNAUTHORIZED);
  }
  const header = String(args.authorization ?? "").trim();
  if (!header.startsWith("Bearer ")) {
    throw new GooglePlayRtdnUnauthorizedError(GOOGLE_PLAY_RTDN_UNAUTHORIZED);
  }
  const token = header.slice(7).trim();
  if (!token) {
    throw new GooglePlayRtdnUnauthorizedError(GOOGLE_PLAY_RTDN_UNAUTHORIZED);
  }
  try {
    const jwks = args.jwks ?? (await loadGoogleOidcJwkSet());
    await jose.jwtVerify(token, jwks, {
      audience: args.audience,
      issuer: [...GOOGLE_OIDC_ISSUERS],
    });
  } catch (error) {
    if (error instanceof GooglePlayRtdnUnauthorizedError) {
      throw error;
    }
    throw new GooglePlayRtdnUnauthorizedError(GOOGLE_PLAY_RTDN_UNAUTHORIZED);
  }
}
