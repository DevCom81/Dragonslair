import { GooglePlayRtdnError, GOOGLE_PLAY_RTDN_INVALID } from "./errors";

function asObject(value: unknown): Record<string, unknown> | null {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return null;
}

function decodeBase64(raw: string): string {
  const normalized = raw.replace(/-/g, "+").replace(/_/g, "/");
  const pad = normalized.length % 4 === 0 ? "" : "=".repeat(4 - (normalized.length % 4));
  const binary = atob(normalized + pad);
  return binary;
}

export function decodePubsubPush(body: unknown): {
  payload: Record<string, unknown>;
  messageId: string;
} {
  const root = asObject(body);
  if (root === null) {
    throw new GooglePlayRtdnError(GOOGLE_PLAY_RTDN_INVALID);
  }
  const message = asObject(root.message);
  if (message === null) {
    throw new GooglePlayRtdnError(GOOGLE_PLAY_RTDN_INVALID);
  }
  const rawData = message.data;
  if (typeof rawData !== "string" || !rawData.trim()) {
    throw new GooglePlayRtdnError(GOOGLE_PLAY_RTDN_INVALID);
  }
  try {
    const decoded = decodeBase64(rawData.trim());
    const payload = JSON.parse(decoded) as unknown;
    const data = asObject(payload);
    if (data === null) {
      throw new GooglePlayRtdnError(GOOGLE_PLAY_RTDN_INVALID);
    }
    return {
      payload: data,
      messageId: String(message.messageId ?? "").trim(),
    };
  } catch (error) {
    if (error instanceof GooglePlayRtdnError) {
      throw error;
    }
    throw new GooglePlayRtdnError(GOOGLE_PLAY_RTDN_INVALID);
  }
}

export type ParsedDeveloperNotification =
  | { kind: "test" }
  | { kind: "ignored_subscription" }
  | {
      kind: "product";
      packageName: string;
      productId: string;
      purchaseToken: string;
      notificationType: unknown;
    };

export function parseDeveloperNotification(
  payload: unknown,
): ParsedDeveloperNotification | null {
  const data = asObject(payload);
  if (data === null) {
    return null;
  }
  if (asObject(data.testNotification)) {
    return { kind: "test" };
  }
  if (asObject(data.subscriptionNotification)) {
    return { kind: "ignored_subscription" };
  }
  const product = asObject(data.oneTimeProductNotification);
  if (product === null) {
    return null;
  }
  const purchaseToken = String(product.purchaseToken ?? "").trim();
  const productId = String(product.sku ?? "").trim();
  if (!purchaseToken || !productId) {
    return null;
  }
  return {
    kind: "product",
    packageName: String(data.packageName ?? "").trim(),
    productId,
    purchaseToken,
    notificationType: product.notificationType,
  };
}
