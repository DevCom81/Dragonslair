import { createHash } from "node:crypto";
import type {
  DemoSessionRow,
  EntitlementSourceRow,
  PlayerRow,
  RoomRow,
  SanitizedAuthUser,
  UserCategory,
  UserEntitlementRow,
} from "./types";

const PAID_SOURCE_PROVIDERS = new Set(["stripe", "google_play", "manual"]);

export function playObfuscatedAccountId(rawId: string): string {
  const trimmed = rawId.trim();
  if (!trimmed) {
    return "";
  }
  return createHash("sha256")
    .update(`dragons_lair:${trimmed}`, "utf8")
    .digest("hex");
}

export function normalizeEmail(email: string | null | undefined): string | null {
  const value = String(email ?? "")
    .trim()
    .toLowerCase();
  return value ? value : null;
}

export function sourceGrantsFull(source: EntitlementSourceRow, now = Date.now()): boolean {
  const status = String(source.status ?? "")
    .trim()
    .toLowerCase();
  if (status !== "active" && status !== "canceled") {
    return false;
  }
  if (status === "canceled" && !source.current_period_end) {
    return false;
  }
  if (source.current_period_end) {
    const end = Date.parse(source.current_period_end);
    if (!Number.isNaN(end) && end <= now) {
      return false;
    }
  }
  return true;
}

export function entitlementCacheIsFull(
  row: UserEntitlementRow,
  now = Date.now(),
): boolean {
  if (String(row.access_level ?? "").trim().toLowerCase() !== "full") {
    return false;
  }
  if (!row.expires_at) {
    return true;
  }
  const end = Date.parse(row.expires_at);
  return Number.isNaN(end) || end > now;
}

export function isPaidPurchaseSource(source: EntitlementSourceRow): boolean {
  const provider = String(source.provider ?? "")
    .trim()
    .toLowerCase();
  if (PAID_SOURCE_PROVIDERS.has(provider)) {
    return true;
  }
  return provider === "full";
}

export function isAnonymousAuthUser(user: SanitizedAuthUser): boolean {
  return normalizeEmail(user.email) === null;
}

export function userHasBusinessValue(args: {
  userId: string;
  sources: EntitlementSourceRow[];
  entitlements: UserEntitlementRow[];
  rooms: RoomRow[];
  players: PlayerRow[];
  demos: DemoSessionRow[];
}): boolean {
  if (args.sources.some((row) => row.user_id === args.userId)) {
    return true;
  }
  if (
    args.entitlements.some(
      (row) => row.user_id === args.userId && entitlementCacheIsFull(row),
    )
  ) {
    return true;
  }
  if (args.rooms.some((row) => row.host_id === args.userId)) {
    return true;
  }
  if (args.players.some((row) => row.user_id === args.userId)) {
    return true;
  }
  return args.demos.some(
    (row) =>
      row.user_id === args.userId &&
      Boolean(row.started_at || row.completed_at || row.paused_at),
  );
}

export function classifyAuthUsers(args: {
  authUsers: SanitizedAuthUser[];
  sources: EntitlementSourceRow[];
  entitlements: UserEntitlementRow[];
  rooms: RoomRow[];
  players: PlayerRow[];
  demos: DemoSessionRow[];
}): Record<string, UserCategory> {
  const byEmail = new Map<string, string[]>();
  for (const user of args.authUsers) {
    const email = normalizeEmail(user.email);
    if (!email) {
      continue;
    }
    const list = byEmail.get(email) ?? [];
    list.push(user.id);
    byEmail.set(email, list);
  }
  const classified: Record<string, UserCategory> = {};
  for (const user of args.authUsers) {
    const email = normalizeEmail(user.email);
    if (email && (byEmail.get(email)?.length ?? 0) > 1) {
      classified[user.id] = "ambiguous_identity";
      continue;
    }
    if (isAnonymousAuthUser(user)) {
      classified[user.id] = "ignored_anonymous";
      continue;
    }
    classified[user.id] = "migratable_email";
  }
  return classified;
}
