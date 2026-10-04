import type { Infer } from "convex/values";
import {
  entitlementGrantSource,
  entitlementProvider,
  entitlementSourceStatus,
} from "./validators";
import type { AccessLevel } from "./access";

export type EntitlementProvider = Infer<typeof entitlementProvider>;
export type EntitlementSourceStatus = Infer<typeof entitlementSourceStatus>;
export type EntitlementGrantSource = Infer<typeof entitlementGrantSource>;

const BILLING_PROVIDERS = new Set<EntitlementProvider>([
  "stripe",
  "google_play",
  "manual",
]);
const PURCHASE_PROVIDERS = new Set<EntitlementProvider>([
  "stripe",
  "google_play",
]);
const VALID_GRANT_STATUSES = new Set<EntitlementSourceStatus>([
  "active",
  "canceled",
]);
const NEVER_GRANT_STATUSES = new Set<EntitlementSourceStatus>([
  "pending",
  "expired",
  "on_hold",
  "revoked",
]);
const STATUS_ALIASES: Record<string, EntitlementSourceStatus> = {
  cancelled: "canceled",
  suspended: "on_hold",
  refunded: "revoked",
};

export type EntitlementSourceInput = {
  provider: unknown;
  status: unknown;
  currentPeriodEnd?: number;
};

export type ComputedEntitlement = {
  accessLevel: AccessLevel;
  source: EntitlementGrantSource;
  expiresAt?: number;
  metadata: {
    active_sources: EntitlementProvider[];
    provider?: EntitlementProvider;
  };
};

export function normalizeBillingProvider(
  value: unknown,
): EntitlementProvider | null {
  const raw = String(value ?? "")
    .trim()
    .toLowerCase();
  if (BILLING_PROVIDERS.has(raw as EntitlementProvider)) {
    return raw as EntitlementProvider;
  }
  return null;
}

export function normalizeSourceStatus(value: unknown): EntitlementSourceStatus {
  const raw = String(value ?? "")
    .trim()
    .toLowerCase();
  const mapped = STATUS_ALIASES[raw] ?? raw;
  if (
    VALID_GRANT_STATUSES.has(mapped as EntitlementSourceStatus) ||
    NEVER_GRANT_STATUSES.has(mapped as EntitlementSourceStatus)
  ) {
    return mapped as EntitlementSourceStatus;
  }
  return "pending";
}

export function sourceGrantsFull(
  source: EntitlementSourceInput,
  now = Date.now(),
): boolean {
  const status = normalizeSourceStatus(source.status);
  if (!VALID_GRANT_STATUSES.has(status)) {
    return false;
  }
  if (status === "canceled" && source.currentPeriodEnd === undefined) {
    return false;
  }
  if (
    source.currentPeriodEnd !== undefined &&
    source.currentPeriodEnd <= now
  ) {
    return false;
  }
  return true;
}

export function computeGlobalEntitlement(args: {
  sources: EntitlementSourceInput[];
  now?: number;
}): ComputedEntitlement {
  const now = args.now ?? Date.now();
  const valid = args.sources.filter((item) => sourceGrantsFull(item, now));
  const providers: EntitlementProvider[] = [];
  for (const item of valid) {
    const provider = normalizeBillingProvider(item.provider);
    if (provider && !providers.includes(provider)) {
      providers.push(provider);
    }
  }
  providers.sort();
  if (valid.length === 0) {
    return {
      accessLevel: "demo",
      source: "default",
      metadata: { active_sources: [] },
    };
  }
  const periodEnds = valid.map((item) => item.currentPeriodEnd);
  const expiresAt = periodEnds.every((end) => end !== undefined)
    ? Math.max(...(periodEnds as number[]))
    : undefined;
  const grantSource: EntitlementGrantSource = providers.some((provider) =>
    PURCHASE_PROVIDERS.has(provider),
  )
    ? "purchase"
    : "admin";
  const metadata: ComputedEntitlement["metadata"] = {
    active_sources: providers,
  };
  if (providers.includes("stripe")) {
    metadata.provider = "stripe";
  } else if (providers.includes("google_play")) {
    metadata.provider = "google_play";
  } else if (providers[0]) {
    metadata.provider = providers[0];
  }
  return {
    accessLevel: "full",
    source: grantSource,
    ...(expiresAt !== undefined ? { expiresAt } : {}),
    metadata,
  };
}
