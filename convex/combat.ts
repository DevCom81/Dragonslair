import type { MutationCtx } from "./_generated/server";
import type { Id } from "./_generated/dataModel";

export async function fetchCombatSession(
  ctx: MutationCtx,
  roomId: Id<"rooms">,
) {
  const rows = await ctx.db
    .query("combatSessions")
    .withIndex("by_room", (q) => q.eq("roomId", roomId))
    .collect();
  if (rows.length === 0) {
    return null;
  }
  return rows.reduce((oldest, row) =>
    row._creationTime < oldest._creationTime ? row : oldest,
  );
}

export async function upsertCombatSession(
  ctx: MutationCtx,
  args: { roomId: Id<"rooms">; active: boolean; round: number },
) {
  const now = Date.now();
  const existing = await fetchCombatSession(ctx, args.roomId);

  if (existing === null) {
    const id = await ctx.db.insert("combatSessions", {
      roomId: args.roomId,
      active: args.active,
      round: args.round,
      startedAt: args.active ? now : undefined,
      endedAt: args.active ? undefined : now,
      updatedAt: now,
    });
    return await ctx.db.get(id);
  }

  const next: {
    roomId: Id<"rooms">;
    active: boolean;
    round: number;
    updatedAt: number;
    startedAt?: number;
    endedAt?: number;
    legacyUuid?: string;
  } = {
    roomId: existing.roomId,
    active: args.active,
    round: args.round,
    updatedAt: now,
  };
  if (existing.legacyUuid !== undefined) {
    next.legacyUuid = existing.legacyUuid;
  }
  if (args.active) {
    next.startedAt =
      existing.active && existing.startedAt !== undefined
        ? existing.startedAt
        : now;
  } else {
    if (existing.startedAt !== undefined) {
      next.startedAt = existing.startedAt;
    }
    next.endedAt = now;
  }
  await ctx.db.replace(existing._id, next);
  return await ctx.db.get(existing._id);
}
