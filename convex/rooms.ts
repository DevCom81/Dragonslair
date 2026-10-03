import { mutation, query } from "./_generated/server";
import type { MutationCtx } from "./_generated/server";
import { v } from "convex/values";
import { accessLevelForUser } from "./lib/access";
import { requireHost, requireIdentity, requireReadableRoom, requireUser } from "./lib/auth";
import { GameRuleError, NotFoundError } from "./lib/errors";
import { roomLocale } from "./lib/validators";
import { insertSystemEvent } from "./gameEvents";
import type { Id } from "./_generated/dataModel";

const JOIN_CODE_LENGTH = 6;
const JOIN_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const HIDDEN_WORLD_KEYS = new Set([
  "gm_secrets",
  "gm_state",
  "secrets",
  "secret",
]);

const PAUSED_EVENT: Record<"fr" | "en" | "de" | "es", string> = {
  fr: "Partie en pause",
  en: "Game paused",
  de: "Spiel pausiert",
  es: "Partida en pausa",
};

function sanitizeWorldState(value: unknown): unknown {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  const input = value as Record<string, unknown>;
  const output: Record<string, unknown> = {};
  for (const [key, item] of Object.entries(input)) {
    if (HIDDEN_WORLD_KEYS.has(key)) {
      continue;
    }
    output[key] = item;
  }
  return output;
}

function normalizeJoinCode(value: string) {
  return value.trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
}

function randomJoinCode() {
  let code = "";
  for (let i = 0; i < JOIN_CODE_LENGTH; i += 1) {
    const index = Math.floor(Math.random() * JOIN_CODE_ALPHABET.length);
    code += JOIN_CODE_ALPHABET[index];
  }
  return code;
}

async function isJoinCodeTaken(ctx: MutationCtx, joinCode: string) {
  const existing = await ctx.db
    .query("rooms")
    .withIndex("by_join_code", (q) => q.eq("joinCode", joinCode))
    .collect();
  return existing.length > 0;
}

async function allocateJoinCode(ctx: MutationCtx) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const joinCode = randomJoinCode();
    if (!(await isJoinCodeTaken(ctx, joinCode))) {
      return joinCode;
    }
  }
  throw new GameRuleError("Impossible de creer la partie.");
}

async function demoSessionsForRoom(ctx: MutationCtx, roomId: Id<"rooms">) {
  return await ctx.db
    .query("demoSessions")
    .withIndex("by_room", (q) => q.eq("roomId", roomId))
    .collect();
}

async function freezeDemoClockOnPause(
  ctx: MutationCtx,
  roomId: Id<"rooms">,
  now: number,
) {
  const rows = await demoSessionsForRoom(ctx, roomId);
  for (const row of rows) {
    if (
      row.startedAt !== undefined &&
      row.completedAt === undefined &&
      row.pausedAt === undefined
    ) {
      await ctx.db.patch(row._id, { pausedAt: now });
    }
  }
}

async function unfreezeDemoClockOnResume(
  ctx: MutationCtx,
  roomId: Id<"rooms">,
  now: number,
) {
  const rows = await demoSessionsForRoom(ctx, roomId);
  for (const row of rows) {
    if (row.pausedAt !== undefined && row.expiresAt !== undefined) {
      await ctx.db.patch(row._id, {
        expiresAt: row.expiresAt + (now - row.pausedAt),
        pausedAt: undefined,
      });
    }
  }
}

async function bindDemoSessionIfNeeded(
  ctx: MutationCtx,
  args: {
    userId: Id<"users">;
    roomId: Id<"rooms">;
    scenarioId: string;
    access: "demo" | "full";
  },
) {
  if (args.access === "full" || args.scenarioId !== "demo") {
    return;
  }
  const existing = await ctx.db
    .query("demoSessions")
    .withIndex("by_user", (q) => q.eq("userId", args.userId))
    .collect();
  if (existing.length > 0) {
    throw new GameRuleError("La demo a deja ete utilisee.");
  }
  await ctx.db.insert("demoSessions", {
    userId: args.userId,
    roomId: args.roomId,
    createdAt: Date.now(),
  });
}

async function playersInRoom(ctx: MutationCtx, roomId: Id<"rooms">) {
  return await ctx.db
    .query("players")
    .withIndex("by_room", (q) => q.eq("roomId", roomId))
    .collect();
}

function assertCanStart(
  playerCount: number,
  minPlayers: number,
  requiredClassIds: string[],
  takenClassIds: Array<string | undefined>,
) {
  if (playerCount < minPlayers) {
    throw new GameRuleError(
      `Pas assez de joueurs (${playerCount} / ${minPlayers}).`,
    );
  }
  const taken = new Set(
    takenClassIds.filter((classId): classId is string => classId !== undefined),
  );
  for (const classId of requiredClassIds) {
    if (!taken.has(classId)) {
      throw new GameRuleError(`Classe obligatoire manquante: ${classId}`);
    }
  }
}

export const get = query({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, args) => {
    const { room } = await requireReadableRoom(ctx, args.roomId);
    return room;
  },
});

export const getByJoinCode = query({
  args: { joinCode: v.string() },
  handler: async (ctx, args) => {
    await requireIdentity(ctx);
    const joinCode = normalizeJoinCode(args.joinCode);
    if (joinCode.length !== JOIN_CODE_LENGTH) {
      throw new GameRuleError("Code de partie invalide.");
    }
    const matches = await ctx.db
      .query("rooms")
      .withIndex("by_join_code", (q) => q.eq("joinCode", joinCode))
      .collect();
    return matches[0] ?? null;
  },
});

export const listWaiting = query({
  args: {},
  handler: async (ctx) => {
    await requireUser(ctx);
    const waiting = await ctx.db
      .query("rooms")
      .withIndex("by_status", (q) => q.eq("status", "waiting"))
      .collect();
    return waiting
      .filter((room) => room.scenarioId !== "demo")
      .sort((a, b) => a.createdAt - b.createdAt);
  },
});

export const listMineContinuable = query({
  args: {},
  handler: async (ctx) => {
    const { user } = await requireUser(ctx);
    const hosted = await ctx.db
      .query("rooms")
      .withIndex("by_host", (q) => q.eq("hostUserId", user._id))
      .collect();
    const memberships = await ctx.db
      .query("players")
      .withIndex("by_user", (q) => q.eq("userId", user._id))
      .collect();
    const byId = new Map<string, (typeof hosted)[number]>();
    for (const room of hosted) {
      byId.set(room._id, room);
    }
    for (const membership of memberships) {
      if (byId.has(membership.roomId)) {
        continue;
      }
      const room = await ctx.db.get(membership.roomId);
      if (room !== null) {
        byId.set(room._id, room);
      }
    }
    return [...byId.values()]
      .filter((room) => room.status === "playing" || room.status === "paused")
      .sort((a, b) => b.createdAt - a.createdAt);
  },
});

export const create = mutation({
  args: {
    name: v.string(),
    scenarioId: v.string(),
    scenarioName: v.string(),
    minPlayers: v.number(),
    requiredClassIds: v.array(v.string()),
    scenarioPrompt: v.optional(v.string()),
    worldState: v.optional(v.any()),
    locale: v.optional(roomLocale),
  },
  handler: async (ctx, args) => {
    const { user } = await requireUser(ctx);
    const name = args.name.trim();
    if (name.length === 0) {
      throw new GameRuleError("Impossible de creer la partie.");
    }
    if (!Number.isInteger(args.minPlayers) || args.minPlayers < 1) {
      throw new GameRuleError("Impossible de creer la partie.");
    }
    const access = await accessLevelForUser(ctx, user._id);
    const scenarioPrompt = (args.scenarioPrompt ?? "").trim();
    if (access !== "full") {
      if (
        args.scenarioId !== "demo" ||
        args.minPlayers !== 1 ||
        args.requiredClassIds.length > 0 ||
        scenarioPrompt !== ""
      ) {
        throw new GameRuleError("La demo est limitee au scenario solo.");
      }
    }
    const now = Date.now();
    const joinCode = await allocateJoinCode(ctx);
    const roomId = await ctx.db.insert("rooms", {
      name,
      scenario: args.scenarioName,
      scenarioId: args.scenarioId,
      status: "waiting",
      createdAt: now,
      hostUserId: user._id,
      joinCode,
      minPlayers: args.minPlayers,
      requiredClassIds: args.requiredClassIds,
      scenarioPrompt,
      worldState: sanitizeWorldState(args.worldState),
      locale: args.locale ?? "en",
      ending: {},
      musicMood: "exploration",
    });
    await bindDemoSessionIfNeeded(ctx, {
      userId: user._id,
      roomId,
      scenarioId: args.scenarioId,
      access,
    });
    return await ctx.db.get(roomId);
  },
});

export const start = mutation({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, args) => {
    const { room } = await requireHost(ctx, args.roomId);
    if (room.status !== "waiting") {
      throw new GameRuleError("Impossible de demarrer la partie.");
    }
    const players = await playersInRoom(ctx, room._id);
    assertCanStart(
      players.length,
      room.minPlayers,
      room.requiredClassIds,
      players.map((player) => player.classId),
    );
    await ctx.db.patch(room._id, {
      status: "playing",
      gamePhase: "exploration",
      musicMood: "exploration",
      startedAt: Date.now(),
    });
    return await ctx.db.get(room._id);
  },
});

export const pause = mutation({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, args) => {
    const { room } = await requireHost(ctx, args.roomId);
    if (room.status !== "playing") {
      throw new GameRuleError("Impossible de mettre la partie en pause.");
    }
    const now = Date.now();
    await ctx.db.patch(room._id, { status: "paused" });
    await freezeDemoClockOnPause(ctx, room._id, now);
    await insertSystemEvent(ctx, {
      roomId: room._id,
      content: PAUSED_EVENT[room.locale],
      createdAt: now,
    });
    return await ctx.db.get(room._id);
  },
});

export const resume = mutation({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, args) => {
    const { room } = await requireHost(ctx, args.roomId);
    if (room.status !== "paused") {
      throw new GameRuleError("Impossible de reprendre la partie.");
    }
    const now = Date.now();
    await ctx.db.patch(room._id, { status: "playing" });
    await unfreezeDemoClockOnResume(ctx, room._id, now);
    return await ctx.db.get(room._id);
  },
});
