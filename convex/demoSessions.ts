import { query } from "./_generated/server";
import { requireUser } from "./lib/auth";

export const getMine = query({
  args: {},
  handler: async (ctx) => {
    const { user } = await requireUser(ctx);
    const sessions = await ctx.db
      .query("demoSessions")
      .withIndex("by_user", (q) => q.eq("userId", user._id))
      .collect();
    const session = [...sessions].sort((a, b) => a.createdAt - b.createdAt)[0];
    if (session === undefined) {
      return null;
    }
    return {
      ...(session.roomId !== undefined ? { roomId: session.roomId } : {}),
      ...(session.startedAt !== undefined ? { startedAt: session.startedAt } : {}),
      ...(session.expiresAt !== undefined ? { expiresAt: session.expiresAt } : {}),
      ...(session.pausedAt !== undefined ? { pausedAt: session.pausedAt } : {}),
      ...(session.completedAt !== undefined
        ? { completedAt: session.completedAt }
        : {}),
    };
  },
});
