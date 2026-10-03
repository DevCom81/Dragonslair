import { mutation } from "./_generated/server";
import type { MutationCtx } from "./_generated/server";
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { requirePlayer } from "./lib/auth";
import { GameRuleError, NotFoundError } from "./lib/errors";
import { isPendingRollDie } from "./lib/validators";
import {
  asInt,
  canResolvePendingRoll,
  effectiveModifierFromRow,
  resolveRollTotal,
  type JsonMap,
} from "./lib/stateEffects";

export async function createPendingRoll(
  ctx: MutationCtx,
  args: {
    roomId: Id<"rooms">;
    playerId: Id<"players">;
    ability: "strength" | "dexterity" | "constitution" | "intelligence" | "wisdom" | "charisma";
    dc: number;
    reason: string;
  },
) {
  const open = await ctx.db
    .query("pendingRolls")
    .withIndex("by_player_and_status", (q) =>
      q.eq("playerId", args.playerId).eq("status", "pending"),
    )
    .collect();
  for (const row of open) {
    if (row.roomId !== args.roomId) {
      continue;
    }
    await ctx.db.patch(row._id, { status: "cancelled" });
  }
  const now = Date.now();
  return await ctx.db.insert("pendingRolls", {
    roomId: args.roomId,
    playerId: args.playerId,
    ability: args.ability,
    dc: args.dc,
    reason: args.reason,
    status: "pending",
    createdAt: now,
  });
}

function playerRowAsMap(player: Doc<"players">): JsonMap {
  return {
    strength: player.strength,
    dexterity: player.dexterity,
    constitution: player.constitution,
    intelligence: player.intelligence,
    wisdom: player.wisdom,
    charisma: player.charisma,
    inventory: player.inventory,
    effects: player.effects,
  };
}

export async function resolvePendingRoll(
  ctx: MutationCtx,
  args: { pendingRollId: Id<"pendingRolls">; raw: number },
) {
  if (!isPendingRollDie(args.raw)) {
    throw new GameRuleError("Raw must be between 1 and 20.");
  }
  const roll = await ctx.db.get(args.pendingRollId);
  if (roll === null) {
    throw new NotFoundError("Pending roll not found.");
  }
  const { player } = await requirePlayer(ctx, roll.roomId);
  if (
    !canResolvePendingRoll({
      status: roll.status,
      rollPlayerId: roll.playerId,
      actorPlayerId: player._id,
    })
  ) {
    throw new GameRuleError("This roll is not pending or cannot be resolved.");
  }
  const ability = roll.ability;
  const dc = asInt(roll.dc, 0);
  const modifier = effectiveModifierFromRow(playerRowAsMap(player), ability);
  const resolved = resolveRollTotal({ raw: args.raw, modifier, dc });
  const now = Date.now();
  await ctx.db.patch(roll._id, {
    status: "resolved",
    result: resolved.raw,
    modifier: resolved.modifier,
    total: resolved.total,
    success: resolved.success,
    resolvedAt: now,
  });
  const name = player.figurineName || "Aventurier";
  const outcome = resolved.success ? "succes" : "echec";
  const sign =
    resolved.modifier >= 0 ? `+${resolved.modifier}` : String(resolved.modifier);
  const content =
    `${name} : 1d20=${resolved.raw} ${sign} = ${resolved.total} ` +
    `vs DD ${dc}. ${outcome}.`;
  await ctx.db.insert("gameEvents", {
    roomId: roll.roomId,
    playerId: player._id,
    type: "action",
    content,
    createdAt: now,
  });
  return {
    pendingRollId: roll._id,
    playerId: player._id,
    roomId: roll.roomId,
    ability,
    dc,
    raw: resolved.raw,
    modifier: resolved.modifier,
    total: resolved.total,
    success: resolved.success,
    reason: roll.reason,
    content,
    playerName: name,
  };
}

export const resolve = mutation({
  args: {
    pendingRollId: v.id("pendingRolls"),
    raw: v.number(),
  },
  handler: async (ctx, args) => {
    return await resolvePendingRoll(ctx, args);
  },
});
