import type { Infer } from "convex/values";
import type { GenericMutationCtx, GenericQueryCtx } from "convex/server";
import type { DataModel, Id } from "../_generated/dataModel";
import { accessLevel } from "./validators";

export type AccessLevel = Infer<typeof accessLevel>;

type DbCtx = GenericQueryCtx<DataModel> | GenericMutationCtx<DataModel>;

/** Mirrors public.current_access_level() after entitlement_sources migration. */
export function effectiveAccessLevel(args: {
  accessLevel: AccessLevel;
  expiresAt?: number;
  now?: number;
}): AccessLevel {
  if (args.accessLevel !== "full") {
    return "demo";
  }
  if (args.expiresAt === undefined) {
    return "full";
  }
  const now = args.now ?? Date.now();
  return args.expiresAt > now ? "full" : "demo";
}

export async function accessLevelForUser(
  ctx: DbCtx,
  userId: Id<"users">,
  now?: number,
): Promise<AccessLevel> {
  const rows = await ctx.db
    .query("userEntitlements")
    .withIndex("by_user", (q) => q.eq("userId", userId))
    .collect();
  if (rows.length === 0) {
    return "demo";
  }
  const row = rows[0];
  return effectiveAccessLevel({
    accessLevel: row.accessLevel,
    expiresAt: row.expiresAt,
    now,
  });
}
