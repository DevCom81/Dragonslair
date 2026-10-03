import { query } from "./_generated/server";
import { v } from "convex/values";
import { requireRoomMember } from "./lib/auth";

export const getForRoom = query({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, args) => {
    await requireRoomMember(ctx, args.roomId);
    const rows = await ctx.db
      .query("combatSessions")
      .withIndex("by_room", (q) => q.eq("roomId", args.roomId))
      .collect();
    return rows[0] ?? null;
  },
});
