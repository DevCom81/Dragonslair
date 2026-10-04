import { query } from "./_generated/server";
import type { MutationCtx } from "./_generated/server";
import { v } from "convex/values";
import type { Id } from "./_generated/dataModel";
import { requireRoomMember } from "./lib/auth";

export async function insertSystemEvent(
  ctx: MutationCtx,
  args: {
    roomId: Id<"rooms">;
    content: string;
    createdAt: number;
  },
) {
  return await ctx.db.insert("gameEvents", {
    roomId: args.roomId,
    type: "system",
    content: args.content,
    createdAt: args.createdAt,
  });
}

export async function insertActionEvent(
  ctx: MutationCtx,
  args: {
    roomId: Id<"rooms">;
    playerId: Id<"players">;
    content: string;
    createdAt: number;
  },
) {
  return await ctx.db.insert("gameEvents", {
    roomId: args.roomId,
    playerId: args.playerId,
    type: "action",
    content: args.content,
    createdAt: args.createdAt,
  });
}

export const listByRoom = query({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, args) => {
    await requireRoomMember(ctx, args.roomId);
    return await ctx.db
      .query("gameEvents")
      .withIndex("by_room_and_created", (q) => q.eq("roomId", args.roomId))
      .collect();
  },
});
