import { query } from "./_generated/server";
import type { MutationCtx } from "./_generated/server";
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { requireRoomMember } from "./lib/auth";
import {
  applyEnemyDamage,
  applyEnemyHeal,
  asInt,
  enemyStatusForHp,
} from "./lib/stateEffects";

export const listByRoom = query({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, args) => {
    await requireRoomMember(ctx, args.roomId);
    const enemies = await ctx.db
      .query("enemies")
      .withIndex("by_room", (q) => q.eq("roomId", args.roomId))
      .collect();
    return enemies.sort((a, b) => a.createdAt - b.createdAt);
  },
});

async function getEnemyInRoom(
  ctx: MutationCtx,
  roomId: Id<"rooms">,
  enemyId: string,
): Promise<Doc<"enemies"> | null> {
  try {
    const row = await ctx.db.get(enemyId as Id<"enemies">);
    if (row === null || row.roomId !== roomId) {
      return null;
    }
    return row;
  } catch {
    return null;
  }
}

export async function fetchRoomEnemyByName(
  ctx: MutationCtx,
  roomId: Id<"rooms">,
  name: string,
): Promise<Doc<"enemies"> | null> {
  const rows = await ctx.db
    .query("enemies")
    .withIndex("by_room", (q) => q.eq("roomId", roomId))
    .collect();
  const matches = rows
    .filter((row) => row.name === name)
    .sort((a, b) => b.createdAt - a.createdAt)
    .slice(0, 5);
  const active = matches.find((row) => row.status === "active");
  return active ?? matches[0] ?? null;
}

export async function resolveEnemyRow(
  ctx: MutationCtx,
  args: {
    roomId: Id<"rooms">;
    enemyId: string | null;
    name: string | null;
  },
): Promise<Doc<"enemies"> | null> {
  if (args.enemyId) {
    const row = await getEnemyInRoom(ctx, args.roomId, args.enemyId);
    if (row !== null) {
      return row;
    }
  }
  if (args.name) {
    return await fetchRoomEnemyByName(ctx, args.roomId, args.name);
  }
  return null;
}

export async function createEnemy(
  ctx: MutationCtx,
  args: {
    roomId: Id<"rooms">;
    name: string;
    enemyType: string;
    positionX: number;
    positionY: number;
    hp: number;
    maxHp: number;
  },
) {
  const now = Date.now();
  const enemyId = await ctx.db.insert("enemies", {
    roomId: args.roomId,
    name: args.name,
    enemyType: args.enemyType,
    positionX: args.positionX,
    positionY: args.positionY,
    hp: args.hp,
    maxHp: args.maxHp,
    status: "active",
    metadata: {},
    createdAt: now,
    updatedAt: now,
  });
  return await ctx.db.get(enemyId);
}

export async function moveEnemy(
  ctx: MutationCtx,
  args: { roomId: Id<"rooms">; enemyId: Id<"enemies">; x: number; y: number },
) {
  const row = await getEnemyInRoom(ctx, args.roomId, args.enemyId);
  if (row === null) {
    return;
  }
  await ctx.db.patch(row._id, {
    positionX: args.x,
    positionY: args.y,
    updatedAt: Date.now(),
  });
}

export async function damageEnemy(
  ctx: MutationCtx,
  args: { roomId: Id<"rooms">; enemyId: Id<"enemies">; amount: number },
) {
  const row = await getEnemyInRoom(ctx, args.roomId, args.enemyId);
  if (row === null) {
    return null;
  }
  const maxHp = Math.max(1, asInt(row.maxHp, 20));
  const hp = asInt(row.hp, 0);
  const nextHp = applyEnemyDamage(hp, args.amount, maxHp);
  const status = enemyStatusForHp(nextHp, row.status);
  await ctx.db.patch(row._id, {
    hp: nextHp,
    status,
    updatedAt: Date.now(),
  });
  return {
    id: row._id,
    name: row.name,
    hp,
    next_hp: nextHp,
    status,
  };
}

export async function healEnemy(
  ctx: MutationCtx,
  args: { roomId: Id<"rooms">; enemyId: Id<"enemies">; amount: number },
) {
  const row = await getEnemyInRoom(ctx, args.roomId, args.enemyId);
  if (row === null) {
    return null;
  }
  const maxHp = Math.max(1, asInt(row.maxHp, 20));
  const hp = asInt(row.hp, 0);
  const nextHp = applyEnemyHeal(hp, args.amount, maxHp);
  const status = enemyStatusForHp(nextHp, row.status);
  await ctx.db.patch(row._id, {
    hp: nextHp,
    status,
    updatedAt: Date.now(),
  });
  return {
    id: row._id,
    name: row.name,
    hp,
    next_hp: nextHp,
    status,
  };
}

export async function setEnemyStatus(
  ctx: MutationCtx,
  args: {
    roomId: Id<"rooms">;
    enemyId: Id<"enemies">;
    status: "active" | "defeated" | "escaped";
    hp?: number;
  },
) {
  const row = await getEnemyInRoom(ctx, args.roomId, args.enemyId);
  if (row === null) {
    return;
  }
  await ctx.db.patch(row._id, {
    status: args.status,
    ...(args.hp !== undefined ? { hp: args.hp } : {}),
    updatedAt: Date.now(),
  });
}
