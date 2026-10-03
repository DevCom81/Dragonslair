import { mutation, query } from "./_generated/server";
import type { MutationCtx } from "./_generated/server";
import { v } from "convex/values";
import { accessLevelForUser } from "./lib/access";
import {
  findPlayerInRoom,
  requirePlayer,
  requireReadablePlayers,
  requireRoom,
  requireUser,
} from "./lib/auth";
import { GameRuleError, NotFoundError } from "./lib/errors";
import { isFigurineId } from "./lib/validators";
import { applyHeal, asInventory, consumePotion } from "./lib/stateEffects";
import type { Doc, Id } from "./_generated/dataModel";

async function profileForUser(ctx: MutationCtx, userId: Id<"users">) {
  const rows = await ctx.db
    .query("profiles")
    .withIndex("by_user", (q) => q.eq("userId", userId))
    .collect();
  if (rows.length === 0) {
    return null;
  }
  return rows.reduce((oldest, row) =>
    row._creationTime < oldest._creationTime ? row : oldest,
  );
}

async function insertPlayer(
  ctx: MutationCtx,
  args: {
    room: Doc<"rooms">;
    user: Doc<"users">;
    profile: Doc<"profiles">;
    figurineId: number;
  },
) {
  const classId = args.profile.classId;
  if (classId === undefined || !args.profile.sheetConfirmed) {
    throw new GameRuleError("Complete sheet first");
  }
  if (!isFigurineId(args.figurineId)) {
    throw new GameRuleError("Figurine invalide.");
  }
  const access = await accessLevelForUser(ctx, args.user._id);
  if (access !== "full") {
    if (
      args.room.scenarioId !== "demo" ||
      args.room.hostUserId !== args.user._id
    ) {
      throw new GameRuleError("La demo est solo uniquement.");
    }
  }
  if (args.room.status !== "waiting") {
    throw new GameRuleError(
      "Impossible de rejoindre une partie deja lancee.",
    );
  }

  const sameUser = await findPlayerInRoom(ctx, args.room._id, args.user._id);
  if (sameUser !== null) {
    return sameUser;
  }

  const sameFigurine = await ctx.db
    .query("players")
    .withIndex("by_room_and_figurine", (q) =>
      q.eq("roomId", args.room._id).eq("figurineId", args.figurineId),
    )
    .collect();
  if (sameFigurine.length > 0) {
    throw new GameRuleError("Cette figurine est deja prise.");
  }

  const sameClass = await ctx.db
    .query("players")
    .withIndex("by_room_and_class", (q) =>
      q.eq("roomId", args.room._id).eq("classId", classId),
    )
    .collect();
  if (sameClass.length > 0) {
    throw new GameRuleError("Cette classe est deja prise.");
  }

  const now = Date.now();
  const playerId = await ctx.db.insert("players", {
    roomId: args.room._id,
    userId: args.user._id,
    figurineId: args.figurineId,
    figurineName: args.profile.displayName,
    positionX: 0.5,
    positionY: 0.5,
    hp: 100,
    inventory: [],
    joinedAt: now,
    classId,
    effects: [],
    strength: args.profile.strength,
    dexterity: args.profile.dexterity,
    constitution: args.profile.constitution,
    intelligence: args.profile.intelligence,
    wisdom: args.profile.wisdom,
    charisma: args.profile.charisma,
  });

  const afterUser = await findPlayerInRoom(ctx, args.room._id, args.user._id);
  if (afterUser !== null && afterUser._id !== playerId) {
    await ctx.db.delete(playerId);
    return afterUser;
  }
  const afterFigurine = await ctx.db
    .query("players")
    .withIndex("by_room_and_figurine", (q) =>
      q.eq("roomId", args.room._id).eq("figurineId", args.figurineId),
    )
    .collect();
  if (afterFigurine.length > 1) {
    await ctx.db.delete(playerId);
    throw new GameRuleError("Cette figurine est deja prise.");
  }
  const afterClass = await ctx.db
    .query("players")
    .withIndex("by_room_and_class", (q) =>
      q.eq("roomId", args.room._id).eq("classId", classId),
    )
    .collect();
  if (afterClass.length > 1) {
    await ctx.db.delete(playerId);
    throw new GameRuleError("Cette classe est deja prise.");
  }

  return await ctx.db.get(playerId);
}

async function joinAuthenticated(
  ctx: MutationCtx,
  room: Doc<"rooms">,
  figurineId: number,
) {
  const { user } = await requireUser(ctx);
  const profile = await profileForUser(ctx, user._id);
  if (profile === null) {
    throw new GameRuleError("Complete sheet first");
  }
  return await insertPlayer(ctx, {
    room,
    user,
    profile,
    figurineId,
  });
}

export const join = mutation({
  args: {
    roomId: v.id("rooms"),
    figurineId: v.number(),
  },
  handler: async (ctx, args) => {
    const room = await requireRoom(ctx, args.roomId);
    return await joinAuthenticated(ctx, room, args.figurineId);
  },
});

export const joinByCode = mutation({
  args: {
    joinCode: v.string(),
    figurineId: v.number(),
  },
  handler: async (ctx, args) => {
    await requireUser(ctx);
    const joinCode = args.joinCode.trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
    if (joinCode.length !== 6) {
      throw new GameRuleError("Code de partie invalide.");
    }
    const matches = await ctx.db
      .query("rooms")
      .withIndex("by_join_code", (q) => q.eq("joinCode", joinCode))
      .collect();
    const room = matches[0];
    if (room === undefined) {
      throw new NotFoundError("Room not found");
    }
    return await joinAuthenticated(ctx, room, args.figurineId);
  },
});

export const listByRoom = query({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, args) => {
    await requireReadablePlayers(ctx, args.roomId);
    const players = await ctx.db
      .query("players")
      .withIndex("by_room", (q) => q.eq("roomId", args.roomId))
      .collect();
    return players.sort((a, b) => a.joinedAt - b.joinedAt);
  },
});

export const usePotion = mutation({
  args: {
    roomId: v.id("rooms"),
    itemId: v.string(),
  },
  handler: async (ctx, args) => {
    const { player } = await requirePlayer(ctx, args.roomId);
    const inventory = asInventory(player.inventory);
    const result = consumePotion(inventory, args.itemId);
    if (result.heal <= 0) {
      return player;
    }
    const nextHp = applyHeal(player.hp, result.heal);
    await ctx.db.patch(player._id, {
      hp: nextHp,
      inventory: result.inventory,
    });
    const used = inventory.find((item) => String(item.id ?? "") === args.itemId);
    const itemName = String(used?.name ?? "Potion");
    await ctx.db.insert("gameEvents", {
      roomId: args.roomId,
      type: "system",
      content:
        `${player.figurineName} : ${itemName} (+${result.heal} PV, ${player.hp} -> ${nextHp})`,
      createdAt: Date.now(),
    });
    return await ctx.db.get(player._id);
  },
});


