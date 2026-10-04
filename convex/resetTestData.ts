import { internalMutation } from "./_generated/server";
import type { MutationCtx } from "./_generated/server";
import type { TableNames } from "./_generated/dataModel";
import { v } from "convex/values";

export const RESET_TEST_DATA_CONFIRM = "RESET_DRAGONSLAIR_TEST_DATA";

export class ResetConfirmationError extends Error {
  constructor() {
    super("Reset confirmation mismatch.");
    this.name = "ResetConfirmationError";
  }
}

/** All applicative tables in convex/schema.ts. Delete children before parents. */
export const APPLICATIVE_TABLES = [
  "pendingRolls",
  "gameEvents",
  "enemies",
  "combatSessions",
  "roomGmState",
  "demoSessions",
  "aiUsageEvents",
  "players",
  "rooms",
  "profiles",
  "userEntitlements",
  "entitlementSources",
  "identityMap",
  "users",
] as const satisfies readonly TableNames[];

async function deleteTable(ctx: MutationCtx, table: TableNames) {
  const rows = await ctx.db.query(table).collect();
  for (const row of rows) {
    await ctx.db.delete(row._id);
  }
  return rows.length;
}

export const purgeAll = internalMutation({
  args: {
    confirm: v.string(),
  },
  handler: async (ctx, args) => {
    if (args.confirm !== RESET_TEST_DATA_CONFIRM) {
      throw new ResetConfirmationError();
    }
    const deleted: Record<(typeof APPLICATIVE_TABLES)[number], number> = {
      pendingRolls: 0,
      gameEvents: 0,
      enemies: 0,
      combatSessions: 0,
      roomGmState: 0,
      demoSessions: 0,
      aiUsageEvents: 0,
      players: 0,
      rooms: 0,
      profiles: 0,
      userEntitlements: 0,
      entitlementSources: 0,
      identityMap: 0,
      users: 0,
    };
    for (const table of APPLICATIVE_TABLES) {
      deleted[table] = await deleteTable(ctx, table);
    }
    const remaining: Record<(typeof APPLICATIVE_TABLES)[number], number> = {
      pendingRolls: 0,
      gameEvents: 0,
      enemies: 0,
      combatSessions: 0,
      roomGmState: 0,
      demoSessions: 0,
      aiUsageEvents: 0,
      players: 0,
      rooms: 0,
      profiles: 0,
      userEntitlements: 0,
      entitlementSources: 0,
      identityMap: 0,
      users: 0,
    };
    for (const table of APPLICATIVE_TABLES) {
      remaining[table] = (await ctx.db.query(table).collect()).length;
    }
    return { deleted, remaining };
  },
});
