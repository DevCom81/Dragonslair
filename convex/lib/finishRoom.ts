import type { MutationCtx } from "../_generated/server";
import type { Doc, Id } from "../_generated/dataModel";
import { accessLevelForUser } from "./access";
import { parseFinishGame } from "./stateEffects";

export async function applyFinishToRoom(
  ctx: MutationCtx,
  roomId: Id<"rooms">,
  payload: unknown,
): Promise<{ room: Doc<"rooms"> | null; summary: string | null }> {
  const ending = parseFinishGame(payload);
  const room = await ctx.db.get(roomId);
  if (room === null) {
    return { room: null, summary: null };
  }
  let accessLevel: "demo" | "full" = "demo";
  if (room.hostUserId) {
    try {
      accessLevel = await accessLevelForUser(ctx, room.hostUserId);
    } catch {
      accessLevel = "demo";
    }
  }
  const demoCut = room.scenarioId === "demo" && accessLevel !== "full";
  const status = demoCut ? "demo_finished" : "finished";
  if (room.status !== "playing" && room.status !== "paused") {
    return { room, summary: null };
  }
  const finishedAt = Date.now();
  await ctx.db.patch(roomId, {
    status,
    finishedAt,
    ending: {
      result: ending.result,
      summary: ending.summary,
      epilogue: ending.epilogue,
    },
  });
  const sessions = await ctx.db
    .query("demoSessions")
    .withIndex("by_room", (q) => q.eq("roomId", roomId))
    .collect();
  for (const session of sessions) {
    if (session.completedAt === undefined) {
      await ctx.db.patch(session._id, { completedAt: finishedAt });
    }
  }
  const next = await ctx.db.get(roomId);
  return {
    room: next,
    summary: `Fin de partie (${ending.result}).`,
  };
}
