import * as jose from "jose";
import { GooglePlayConfigError, GooglePlayPurchaseError, GOOGLE_PLAY_PURCHASE_INVALID } from "./errors";
import { googlePlayPackageName } from "./googlePlayPurchase";

const ANDROID_PUBLISHER_SCOPE =
  "https://www.googleapis.com/auth/androidpublisher";
const TOKEN_URL = "https://oauth2.googleapis.com/token";
const PUBLISHER_ROOT =
  "https://androidpublisher.googleapis.com/androidpublisher/v3";

function serviceAccountInfo(): {
  private_key: string;
  client_email: string;
} {
  const raw = (process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON ?? "").trim();
  if (!raw) {
    throw new GooglePlayConfigError();
  }
  try {
    const data = JSON.parse(raw) as {
      private_key?: unknown;
      client_email?: unknown;
    };
    const privateKey = String(data.private_key ?? "").trim();
    const clientEmail = String(data.client_email ?? "").trim();
    if (!privateKey || !clientEmail) {
      throw new GooglePlayConfigError();
    }
    return { private_key: privateKey, client_email: clientEmail };
  } catch (error) {
    if (error instanceof GooglePlayConfigError) {
      throw error;
    }
    throw new GooglePlayConfigError();
  }
}

export async function getGooglePlayAccessToken(
  fetchImpl: typeof fetch = fetch,
): Promise<string> {
  const account = serviceAccountInfo();
  const key = await jose.importPKCS8(account.private_key, "RS256");
  const assertion = await new jose.SignJWT({
    scope: ANDROID_PUBLISHER_SCOPE,
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(account.client_email)
    .setSubject(account.client_email)
    .setAudience(TOKEN_URL)
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(key);
  const response = await fetchImpl(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (response.status >= 400) {
    throw new GooglePlayConfigError();
  }
  const payload = (await response.json()) as { access_token?: unknown };
  const token = String(payload.access_token ?? "").trim();
  if (!token) {
    throw new GooglePlayConfigError();
  }
  return token;
}

function productTokenUrl(productId: string, purchaseToken: string) {
  const packageName = encodeURIComponent(googlePlayPackageName());
  const sku = encodeURIComponent(productId);
  const token = encodeURIComponent(purchaseToken);
  return `${PUBLISHER_ROOT}/applications/${packageName}/purchases/products/${sku}/tokens/${token}`;
}

export async function fetchGoogleProductPurchase(args: {
  productId: string;
  purchaseToken: string;
  accessToken: string;
  fetchImpl?: typeof fetch;
}): Promise<Record<string, unknown>> {
  const fetchImpl = args.fetchImpl ?? fetch;
  const response = await fetchImpl(
    productTokenUrl(args.productId, args.purchaseToken),
    {
      headers: { Authorization: `Bearer ${args.accessToken}` },
    },
  );
  if (response.status === 400 || response.status === 404) {
    throw new GooglePlayPurchaseError(GOOGLE_PLAY_PURCHASE_INVALID);
  }
  if (response.status >= 400) {
    throw new GooglePlayConfigError();
  }
  const payload = (await response.json()) as unknown;
  if (payload === null || typeof payload !== "object" || Array.isArray(payload)) {
    throw new GooglePlayPurchaseError(GOOGLE_PLAY_PURCHASE_INVALID);
  }
  return payload as Record<string, unknown>;
}

export async function acknowledgePlayPurchase(args: {
  productId: string;
  purchaseToken: string;
  accessToken: string;
  fetchImpl?: typeof fetch;
}): Promise<void> {
  const fetchImpl = args.fetchImpl ?? fetch;
  const response = await fetchImpl(
    `${productTokenUrl(args.productId, args.purchaseToken)}:acknowledge`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${args.accessToken}`,
        "Content-Type": "application/json",
      },
      body: "{}",
    },
  );
  if (response.status === 204 || response.status === 400) {
    return;
  }
  throw new GooglePlayConfigError();
}
