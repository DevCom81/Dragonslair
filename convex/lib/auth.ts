import type { GenericActionCtx, GenericMutationCtx, GenericQueryCtx } from "convex/server";
import type { DataModel, Id } from "../_generated/dataModel";
import { ForbiddenError, NotFoundError } from "./errors";

type AuthCtx =
  | GenericQueryCtx<DataModel>
  | GenericMutationCtx<DataModel>
  | GenericActionCtx<DataModel>;

export class UnauthenticatedError extends Error {
  constructor() {
    super("Unauthenticated");
    this.name = "UnauthenticatedError";
  }
}

export type AuthIdentity = {
  subject: string;
  issuer: string;
  email?: string;
};

type DbCtx = GenericQueryCtx<DataModel> | GenericMutationCtx<DataModel>;

export class UserNotFoundError extends Error {
  constructor() {
    super("User not found");
    this.name = "UserNotFoundError";
  }
}

export async function requireIdentity(ctx: AuthCtx): Promise<AuthIdentity> {
  const identity = await ctx.auth.getUserIdentity();
  if (identity === null) {
    throw new UnauthenticatedError();
  }
  const subject = identity.subject.trim();
  if (!subject) {
    throw new UnauthenticatedError();
  }
  const email = identity.email?.trim();
  return {
    subject,
    issuer: identity.issuer,
    ...(email ? { email } : {}),
  };
}

export async function findUserByAuthSubject(
  ctx: DbCtx,
  authSubject: string,
) {
  const matches = await ctx.db
    .query("users")
    .withIndex("by_workos_subject", (q) => q.eq("workosSubject", authSubject))
    .collect();
  if (matches.length === 0) {
    return null;
  }
  return matches.reduce((oldest, row) =>
    row._creationTime < oldest._creationTime ? row : oldest,
  );
}

export const findUserByWorkosSubject = findUserByAuthSubject;

export async function requireUser(ctx: DbCtx) {
  const identity = await requireIdentity(ctx);
  const user = await findUserByAuthSubject(ctx, identity.subject);
  if (user === null) {
    throw new UserNotFoundError();
  }
  return { identity, user };
}

export async function requireRoom(ctx: DbCtx, roomId: Id<"rooms">) {
  const room = await ctx.db.get(roomId);
  if (room === null) {
    throw new NotFoundError("Room not found");
  }
  return room;
}

export async function requireHost(ctx: DbCtx, roomId: Id<"rooms">) {
  const { user } = await requireUser(ctx);
  const room = await requireRoom(ctx, roomId);
  if (room.hostUserId !== user._id) {
    throw new ForbiddenError("Host only");
  }
  return { user, room };
}

export async function findPlayerInRoom(
  ctx: DbCtx,
  roomId: Id<"rooms">,
  userId: Id<"users">,
) {
  const matches = await ctx.db
    .query("players")
    .withIndex("by_room_and_user", (q) =>
      q.eq("roomId", roomId).eq("userId", userId),
    )
    .collect();
  if (matches.length === 0) {
    return null;
  }
  return matches.reduce((oldest, row) =>
    row._creationTime < oldest._creationTime ? row : oldest,
  );
}

export async function requirePlayer(ctx: DbCtx, roomId: Id<"rooms">) {
  const { user } = await requireUser(ctx);
  const room = await requireRoom(ctx, roomId);
  const player = await findPlayerInRoom(ctx, roomId, user._id);
  if (player === null) {
    throw new ForbiddenError("Player only");
  }
  return { user, room, player };
}

async function viewerForRoom(ctx: DbCtx, roomId: Id<"rooms">) {
  const { user } = await requireUser(ctx);
  const room = await requireRoom(ctx, roomId);
  const player = await findPlayerInRoom(ctx, room._id, user._id);
  const isHost = room.hostUserId === user._id;
  return { user, room, player, isHost };
}

/** Room row: host, participant, or public waiting (non-demo). */
export async function requireReadableRoom(ctx: DbCtx, roomId: Id<"rooms">) {
  const view = await viewerForRoom(ctx, roomId);
  if (
    view.isHost ||
    view.player !== null ||
    (view.room.status === "waiting" && view.room.scenarioId !== "demo")
  ) {
    return view;
  }
  throw new ForbiddenError("Forbidden");
}

/** Players: host, participant, or any waiting room (SQL players_select). */
export async function requireReadablePlayers(ctx: DbCtx, roomId: Id<"rooms">) {
  const view = await viewerForRoom(ctx, roomId);
  if (view.isHost || view.player !== null || view.room.status === "waiting") {
    return view;
  }
  throw new ForbiddenError("Forbidden");
}

/** Events / enemies / combat / rolls: host or participant only. */
export async function requireRoomMember(ctx: DbCtx, roomId: Id<"rooms">) {
  const view = await viewerForRoom(ctx, roomId);
  if (view.isHost || view.player !== null) {
    return view;
  }
  throw new ForbiddenError("Forbidden");
}
