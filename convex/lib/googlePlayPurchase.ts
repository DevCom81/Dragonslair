import { sourceGrantsFull } from "./entitlements";
import {
  GooglePlayPendingError,
  GooglePlayPurchaseError,
  GOOGLE_PLAY_ACCOUNT_MISMATCH,
  GOOGLE_PLAY_PACKAGE_MISMATCH,
  GOOGLE_PLAY_PRODUCT_MISMATCH,
  GOOGLE_PLAY_PURCHASE_INVALID,
  PURCHASE_PENDING,
} from "./errors";
import { playAccountBindingMatches } from "./playAccountId";

export type GooglePlayLifecycle = "active" | "pending" | "revoked";

function asObject(value: unknown): Record<string, unknown> | null {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return null;
}

export function googlePlayPackageName() {
  return (process.env.GOOGLE_PLAY_PACKAGE_NAME ?? "").trim();
}

export function googlePlayProductId() {
  return (process.env.GOOGLE_PLAY_PRODUCT_ID ?? "").trim();
}

export function isGooglePlayConfigured() {
  return Boolean(
    googlePlayPackageName() &&
      googlePlayProductId() &&
      (process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON ?? "").trim(),
  );
}

export function interpretProductLifecycle(
  payload: unknown,
): GooglePlayLifecycle | null {
  const data = asObject(payload);
  if (data === null) {
    return null;
  }
  const state = data.purchaseState;
  if (state === 2) {
    return "pending";
  }
  if (state === 0) {
    return "active";
  }
  if (state === 1) {
    return "revoked";
  }
  return null;
}

export function needsPlayAcknowledgement(payload: unknown): boolean {
  const data = asObject(payload);
  if (data === null) {
    return false;
  }
  return data.acknowledgementState !== 1;
}

export function assertPlayPackage(payload: unknown) {
  const data = asObject(payload);
  if (data === null) {
    return;
  }
  const actual = String(data.packageName ?? "").trim();
  const expected = googlePlayPackageName();
  if (actual && actual !== expected) {
    throw new GooglePlayPurchaseError(GOOGLE_PLAY_PACKAGE_MISMATCH);
  }
}

export function assertPlayProduct(payload: unknown, productId: string) {
  const data = asObject(payload);
  if (data === null) {
    return;
  }
  const actual = String(data.productId ?? "").trim();
  if (actual && actual !== productId) {
    throw new GooglePlayPurchaseError(GOOGLE_PLAY_PRODUCT_MISMATCH);
  }
}

export function obfuscatedAccountIdFromPayload(payload: unknown): string {
  const data = asObject(payload);
  if (data === null) {
    return "";
  }
  return String(data.obfuscatedExternalAccountId ?? "").trim();
}

export function assertPlayAccountBinding(
  payload: unknown,
  acceptedHashes: string[],
) {
  const actual = obfuscatedAccountIdFromPayload(payload);
  if (!playAccountBindingMatches(actual, acceptedHashes)) {
    throw new GooglePlayPurchaseError(GOOGLE_PLAY_ACCOUNT_MISMATCH);
  }
}

export function grantsFullFromLifecycle(status: GooglePlayLifecycle): boolean {
  return sourceGrantsFull({
    provider: "google_play",
    status,
    currentPeriodEnd: undefined,
  });
}

export function assertRedeemableToken(purchaseToken: string): string {
  const token = purchaseToken.trim();
  if (!token || token.length > 4096) {
    throw new GooglePlayPurchaseError(GOOGLE_PLAY_PURCHASE_INVALID);
  }
  return token;
}

export function assertExpectedProductId(productId: string) {
  const expected = googlePlayProductId();
  if (!expected || productId !== expected) {
    throw new GooglePlayPurchaseError(GOOGLE_PLAY_PRODUCT_MISMATCH);
  }
}

export function requireLifecycle(payload: unknown): GooglePlayLifecycle {
  const status = interpretProductLifecycle(payload);
  if (status === null) {
    throw new GooglePlayPurchaseError(GOOGLE_PLAY_PURCHASE_INVALID);
  }
  return status;
}

export function rejectPendingOnRedeem(status: GooglePlayLifecycle) {
  if (status === "pending") {
    throw new GooglePlayPendingError(PURCHASE_PENDING);
  }
}
