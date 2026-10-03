import { query } from "./_generated/server";
import { v } from "convex/values";
import { requireRoomMember } from "./lib/auth";

export const listByRoom = query({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, args) => {
    await requireRoomMember(ctx, args.roomId);
    const rows = await ctx.db
      .query("pendingRolls")
      .withIndex("by_room", (q) => q.eq("roomId", args.roomId))
      .collect();
    return rows.sort((a, b) => a.createdAt - b.createdAt);
  },
});
