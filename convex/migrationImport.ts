import { internalMutation } from "./_generated/server";
import type { MutationCtx } from "./_generated/server";
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { computeGlobalEntitlement, normalizeSourceStatus } from "./lib/entitlements";
import { MigrationCollisionError } from "./lib/errors";
import {
  isRoomStatus,
  narrativeMusicMood,
  roomLocale,
} from "./lib/validators";

type LegacyIndexedTable =
  | "users"
  | "profiles"
  | "rooms"
  | "players"
  | "gameEvents"
  | "enemies"
  | "combatSessions"
  | "pendingRolls"
  | "entitlementSources"
  | "demoSessions";

function oneOrCollision<T>(table: LegacyIndexedTable, rows: T[]): T | null {
  if (rows.length > 1) {
    throw new MigrationCollisionError(`${table} has multiple rows for one legacyUuid`);
  }
  return rows[0] ?? null;
}

async function byLegacy(
  ctx: MutationCtx,
  table: "users",
  legacyUuid: string,
): Promise<Doc<"users"> | null>;
async function byLegacy(
  ctx: MutationCtx,
  table: "profiles",
  legacyUuid: string,
): Promise<Doc<"profiles"> | null>;
async function byLegacy(
  ctx: MutationCtx,
  table: "rooms",
  legacyUuid: string,
): Promise<Doc<"rooms"> | null>;
async function byLegacy(
  ctx: MutationCtx,
  table: "players",
  legacyUuid: string,
): Promise<Doc<"players"> | null>;
async function byLegacy(
  ctx: MutationCtx,
  table: "gameEvents",
  legacyUuid: string,
): Promise<Doc<"gameEvents"> | null>;
async function byLegacy(
  ctx: MutationCtx,
  table: "enemies",
  legacyUuid: string,
): Promise<Doc<"enemies"> | null>;
async function byLegacy(
  ctx: MutationCtx,
  table: "combatSessions",
  legacyUuid: string,
): Promise<Doc<"combatSessions"> | null>;
async function byLegacy(
  ctx: MutationCtx,
  table: "pendingRolls",
  legacyUuid: string,
): Promise<Doc<"pendingRolls"> | null>;
async function byLegacy(
  ctx: MutationCtx,
  table: "entitlementSources",
  legacyUuid: string,
): Promise<Doc<"entitlementSources"> | null>;
async function byLegacy(
  ctx: MutationCtx,
  table: "demoSessions",
  legacyUuid: string,
): Promise<Doc<"demoSessions"> | null>;
async function byLegacy(
  ctx: MutationCtx,
  table: LegacyIndexedTable,
  legacyUuid: string,
): Promise<Doc<LegacyIndexedTable> | null> {
  switch (table) {
    case "users":
      return oneOrCollision(
        table,
        await ctx.db
          .query("users")
          .withIndex("by_legacy_uuid", (q) => q.eq("legacyUuid", legacyUuid))
          .collect(),
      );
    case "profiles":
      return oneOrCollision(
        table,
        await ctx.db
          .query("profiles")
          .withIndex("by_legacy_uuid", (q) => q.eq("legacyUuid", legacyUuid))
          .collect(),
      );
    case "rooms":
      return oneOrCollision(
        table,
        await ctx.db
          .query("rooms")
          .withIndex("by_legacy_uuid", (q) => q.eq("legacyUuid", legacyUuid))
          .collect(),
      );
    case "players":
      return oneOrCollision(
        table,
        await ctx.db
          .query("players")
          .withIndex("by_legacy_uuid", (q) => q.eq("legacyUuid", legacyUuid))
          .collect(),
      );
    case "gameEvents":
      return oneOrCollision(
        table,
        await ctx.db
          .query("gameEvents")
          .withIndex("by_legacy_uuid", (q) => q.eq("legacyUuid", legacyUuid))
          .collect(),
      );
    case "enemies":
      return oneOrCollision(
        table,
        await ctx.db
          .query("enemies")
          .withIndex("by_legacy_uuid", (q) => q.eq("legacyUuid", legacyUuid))
          .collect(),
      );
    case "combatSessions":
      return oneOrCollision(
        table,
        await ctx.db
          .query("combatSessions")
          .withIndex("by_legacy_uuid", (q) => q.eq("legacyUuid", legacyUuid))
          .collect(),
      );
    case "pendingRolls":
      return oneOrCollision(
        table,
        await ctx.db
          .query("pendingRolls")
          .withIndex("by_legacy_uuid", (q) => q.eq("legacyUuid", legacyUuid))
          .collect(),
      );
    case "entitlementSources":
      return oneOrCollision(
        table,
        await ctx.db
          .query("entitlementSources")
          .withIndex("by_legacy_uuid", (q) => q.eq("legacyUuid", legacyUuid))
          .collect(),
      );
    case "demoSessions":
      return oneOrCollision(
        table,
        await ctx.db
          .query("demoSessions")
          .withIndex("by_legacy_uuid", (q) => q.eq("legacyUuid", legacyUuid))
          .collect(),
      );
  }
}

async function requireUserByLegacy(ctx: MutationCtx, legacyUuid: string): Promise<Doc<"users">> {
  const user = await byLegacy(ctx, "users", legacyUuid);
  if (!user) {
    throw new MigrationCollisionError("Mapped user is missing during import");
  }
  return user;
}

async function requireRoomByLegacy(ctx: MutationCtx, legacyUuid: string): Promise<Doc<"rooms">> {
  const room = await byLegacy(ctx, "rooms", legacyUuid);
  if (!room) {
    throw new MigrationCollisionError("Mapped room is missing during import");
  }
  return room;
}

async function requirePlayerByLegacy(
  ctx: MutationCtx,
  legacyUuid: string,
): Promise<Doc<"players">> {
  const player = await byLegacy(ctx, "players", legacyUuid);
  if (!player) {
    throw new MigrationCollisionError("Mapped player is missing during import");
  }
  return player;
}

function assertSame<T>(left: T, right: T, message: string) {
  if (left !== right) {
    throw new MigrationCollisionError(message);
  }
}

export const upsertUser = internalMutation({
  args: {
    legacyUuid: v.string(),
    workosSubject: v.string(),
    email: v.optional(v.string()),
    createdAt: v.number(),
  },
  handler: async (ctx, args) => {
    const bySubject = await ctx.db
      .query("users")
      .withIndex("by_workos_subject", (q) => q.eq("workosSubject", args.workosSubject))
      .collect();
    const existingLegacy = await byLegacy(ctx, "users", args.legacyUuid);
    if (bySubject.length > 1) {
      throw new MigrationCollisionError("Multiple Convex users share a WorkOS subject");
    }
    const existing = bySubject[0] ?? existingLegacy;
    if (bySubject[0] && existingLegacy && bySubject[0]._id !== existingLegacy._id) {
      throw new MigrationCollisionError("WorkOS subject and legacyUuid map to different users");
    }
    if (existing) {
      if (existing.workosSubject !== args.workosSubject) {
        throw new MigrationCollisionError("legacyUuid is bound to a different WorkOS subject");
      }
      if (existing.legacyUuid && existing.legacyUuid !== args.legacyUuid) {
        throw new MigrationCollisionError("WorkOS subject is bound to a different legacyUuid");
      }
      await ctx.db.patch(existing._id, {
        ...(args.email ? { email: args.email } : {}),
        legacyUuid: args.legacyUuid,
      });
      await upsertIdentityMap(ctx, args.legacyUuid, args.workosSubject, existing._id);
      return existing._id;
    }
    const userId = await ctx.db.insert("users", {
      workosSubject: args.workosSubject,
      ...(args.email ? { email: args.email } : {}),
      legacyUuid: args.legacyUuid,
      createdAt: args.createdAt,
    });
    await upsertIdentityMap(ctx, args.legacyUuid, args.workosSubject, userId);
    return userId;
  },
});

async function upsertIdentityMap(
  ctx: MutationCtx,
  supabaseUserId: string,
  workosSubject: string,
  convexUserId: Id<"users">,
) {
  const existing = await ctx.db
    .query("identityMap")
    .withIndex("by_supabase_user", (q) => q.eq("supabaseUserId", supabaseUserId))
    .collect();
  if (existing.length > 1) {
    throw new MigrationCollisionError("identityMap has duplicate supabase users");
  }
  if (existing[0]) {
    if (existing[0].workosSubject !== workosSubject) {
      throw new MigrationCollisionError("identityMap workosSubject collision");
    }
    await ctx.db.patch(existing[0]._id, { convexUserId, workosSubject });
    return;
  }
  await ctx.db.insert("identityMap", {
    supabaseUserId,
    workosSubject,
    convexUserId,
  });
}

export const upsertProfile = internalMutation({
  args: {
    legacyUuid: v.string(),
    userLegacyUuid: v.string(),
    displayName: v.string(),
    classId: v.optional(v.string()),
    avatarFigurineId: v.optional(v.number()),
    sheetConfirmed: v.boolean(),
    createdAt: v.number(),
    strength: v.number(),
    dexterity: v.number(),
    constitution: v.number(),
    intelligence: v.number(),
    wisdom: v.number(),
    charisma: v.number(),
  },
  handler: async (ctx, args) => {
    const user = await requireUserByLegacy(ctx, args.userLegacyUuid);
    const existing = await byLegacy(ctx, "profiles", args.legacyUuid);
    const fields = {
      userId: user._id,
      displayName: args.displayName,
      classId: args.classId,
      avatarFigurineId: args.avatarFigurineId,
      sheetConfirmed: args.sheetConfirmed,
      createdAt: args.createdAt,
      legacyUuid: args.legacyUuid,
      strength: args.strength,
      dexterity: args.dexterity,
      constitution: args.constitution,
      intelligence: args.intelligence,
      wisdom: args.wisdom,
      charisma: args.charisma,
    };
    if (existing) {
      assertSame(existing.userId, user._id, "profile is bound to a different user");
      await ctx.db.patch(existing._id, fields);
      return existing._id;
    }
    return await ctx.db.insert("profiles", fields);
  },
});

export const upsertEntitlementSource = internalMutation({
  args: {
    legacyUuid: v.string(),
    userLegacyUuid: v.string(),
    provider: v.union(v.literal("stripe"), v.literal("google_play"), v.literal("manual")),
    providerRef: v.string(),
    status: v.string(),
    currentPeriodEnd: v.optional(v.number()),
    metadata: v.any(),
    createdAt: v.number(),
    updatedAt: v.number(),
  },
  handler: async (ctx, args) => {
    const user = await requireUserByLegacy(ctx, args.userLegacyUuid);
    const existing = await byLegacy(ctx, "entitlementSources", args.legacyUuid);
    const scoped = await ctx.db
      .query("entitlementSources")
      .withIndex("by_user_provider_ref", (q) =>
        q
          .eq("userId", user._id)
          .eq("provider", args.provider)
          .eq("providerRef", args.providerRef),
      )
      .collect();
    if (scoped.length > 1) {
      throw new MigrationCollisionError("Multiple entitlement sources share user/provider/ref");
    }
    if (existing && scoped[0] && existing._id !== scoped[0]._id) {
      throw new MigrationCollisionError("legacyUuid and user/provider/ref map to different sources");
    }
    const current = existing ?? scoped[0];
    const fields = {
      userId: user._id,
      provider: args.provider,
      providerRef: args.providerRef,
      status: normalizeSourceStatus(args.status),
      currentPeriodEnd: args.currentPeriodEnd,
      metadata: args.metadata,
      createdAt: args.createdAt,
      updatedAt: args.updatedAt,
      legacyUuid: args.legacyUuid,
    };
    if (current) {
      assertSame(current.userId, user._id, "entitlement source is bound to a different user");
      await ctx.db.patch(current._id, fields);
      return current._id;
    }
    return await ctx.db.insert("entitlementSources", fields);
  },
});

export const recomputeUserEntitlement = internalMutation({
  args: { userLegacyUuid: v.string() },
  handler: async (ctx, args) => {
    const user = await requireUserByLegacy(ctx, args.userLegacyUuid);
    const sources = await ctx.db
      .query("entitlementSources")
      .withIndex("by_user", (q) => q.eq("userId", user._id))
      .collect();
    const computed = computeGlobalEntitlement({
      sources: sources.map((row) => ({
        provider: row.provider,
        status: row.status,
        currentPeriodEnd: row.currentPeriodEnd,
      })),
    });
    const existing = await ctx.db
      .query("userEntitlements")
      .withIndex("by_user", (q) => q.eq("userId", user._id))
      .collect();
    const now = Date.now();
    const fields = {
      userId: user._id,
      accessLevel: computed.accessLevel,
      source: computed.source,
      grantedAt: existing[0]?.grantedAt ?? now,
      metadata: computed.metadata,
      expiresAt: computed.expiresAt,
    };
    if (existing[0]) {
      await ctx.db.patch(existing[0]._id, fields);
    } else {
      await ctx.db.insert("userEntitlements", fields);
    }
    return {
      accessLevel: computed.accessLevel,
      source: computed.source,
    };
  },
});

export const upsertRoom = internalMutation({
  args: {
    legacyUuid: v.string(),
    hostLegacyUuid: v.string(),
    name: v.string(),
    scenario: v.optional(v.string()),
    scenarioId: v.optional(v.string()),
    status: v.string(),
    createdAt: v.number(),
    joinCode: v.string(),
    minPlayers: v.number(),
    requiredClassIds: v.array(v.string()),
    scenarioPrompt: v.string(),
    worldState: v.any(),
    locale: v.string(),
    startedAt: v.optional(v.number()),
    finishedAt: v.optional(v.number()),
    gamePhase: v.optional(v.string()),
    ending: v.any(),
    musicMood: v.string(),
  },
  handler: async (ctx, args) => {
    if (!isRoomStatus(args.status)) {
      throw new MigrationCollisionError("Invalid room status");
    }
    const host = await requireUserByLegacy(ctx, args.hostLegacyUuid);
    const existing = await byLegacy(ctx, "rooms", args.legacyUuid);
    const fields = {
      name: args.name,
      scenario: args.scenario,
      scenarioId: args.scenarioId,
      status: args.status as Doc<"rooms">["status"],
      createdAt: args.createdAt,
      hostUserId: host._id,
      joinCode: args.joinCode,
      minPlayers: args.minPlayers,
      requiredClassIds: args.requiredClassIds,
      scenarioPrompt: args.scenarioPrompt,
      worldState: args.worldState,
      locale: args.locale as Doc<"rooms">["locale"],
      startedAt: args.startedAt,
      finishedAt: args.finishedAt,
      gamePhase: args.gamePhase,
      ending: args.ending,
      musicMood: args.musicMood as Doc<"rooms">["musicMood"],
      legacyUuid: args.legacyUuid,
    };
    if (existing) {
      assertSame(existing.hostUserId, host._id, "room is bound to a different host");
      await ctx.db.patch(existing._id, fields);
      return existing._id;
    }
    return await ctx.db.insert("rooms", fields);
  },
});

void roomLocale;
void narrativeMusicMood;

export const upsertPlayer = internalMutation({
  args: {
    legacyUuid: v.string(),
    roomLegacyUuid: v.string(),
    userLegacyUuid: v.string(),
    figurineId: v.number(),
    figurineName: v.string(),
    positionX: v.number(),
    positionY: v.number(),
    hp: v.number(),
    inventory: v.array(v.any()),
    joinedAt: v.number(),
    classId: v.optional(v.string()),
    effects: v.array(v.any()),
    strength: v.number(),
    dexterity: v.number(),
    constitution: v.number(),
    intelligence: v.number(),
    wisdom: v.number(),
    charisma: v.number(),
  },
  handler: async (ctx, args) => {
    const room = await requireRoomByLegacy(ctx, args.roomLegacyUuid);
    const user = await requireUserByLegacy(ctx, args.userLegacyUuid);
    const existing = await byLegacy(ctx, "players", args.legacyUuid);
    const fields = {
      roomId: room._id,
      userId: user._id,
      figurineId: args.figurineId,
      figurineName: args.figurineName,
      positionX: args.positionX,
      positionY: args.positionY,
      hp: args.hp,
      inventory: args.inventory,
      joinedAt: args.joinedAt,
      classId: args.classId,
      effects: args.effects,
      legacyUuid: args.legacyUuid,
      strength: args.strength,
      dexterity: args.dexterity,
      constitution: args.constitution,
      intelligence: args.intelligence,
      wisdom: args.wisdom,
      charisma: args.charisma,
    };
    if (existing) {
      assertSame(existing.roomId, room._id, "player is bound to a different room");
      assertSame(existing.userId, user._id, "player is bound to a different user");
      await ctx.db.patch(existing._id, fields);
      return existing._id;
    }
    return await ctx.db.insert("players", fields);
  },
});

export const upsertGmState = internalMutation({
  args: {
    roomLegacyUuid: v.string(),
    gmSecrets: v.any(),
    gmState: v.any(),
    updatedAt: v.number(),
  },
  handler: async (ctx, args) => {
    const room = await requireRoomByLegacy(ctx, args.roomLegacyUuid);
    const existing = await ctx.db
      .query("roomGmState")
      .withIndex("by_room", (q) => q.eq("roomId", room._id))
      .collect();
    if (existing.length > 1) {
      throw new MigrationCollisionError("room has multiple GM state rows");
    }
    const fields = {
      roomId: room._id,
      gmSecrets: args.gmSecrets,
      gmState: args.gmState,
      updatedAt: args.updatedAt,
    };
    if (existing[0]) {
      await ctx.db.patch(existing[0]._id, fields);
      return existing[0]._id;
    }
    return await ctx.db.insert("roomGmState", fields);
  },
});

export const upsertEventBatch = internalMutation({
  args: {
    events: v.array(
      v.object({
        legacyUuid: v.string(),
        roomLegacyUuid: v.string(),
        playerLegacyUuid: v.optional(v.string()),
        type: v.union(v.literal("action"), v.literal("narration"), v.literal("system")),
        content: v.string(),
        createdAt: v.number(),
      }),
    ),
  },
  handler: async (ctx, args) => {
    let written = 0;
    for (const event of args.events) {
      const room = await requireRoomByLegacy(ctx, event.roomLegacyUuid);
      const player = event.playerLegacyUuid
        ? await requirePlayerByLegacy(ctx, event.playerLegacyUuid)
        : null;
      const existing = await byLegacy(ctx, "gameEvents", event.legacyUuid);
      const fields = {
        roomId: room._id,
        playerId: player?._id,
        type: event.type,
        content: event.content,
        createdAt: event.createdAt,
        legacyUuid: event.legacyUuid,
      };
      if (existing) {
        assertSame(existing.roomId, room._id, "event is bound to a different room");
        await ctx.db.patch(existing._id, fields);
      } else {
        await ctx.db.insert("gameEvents", fields);
      }
      written += 1;
    }
    return written;
  },
});

export const upsertEnemy = internalMutation({
  args: {
    legacyUuid: v.string(),
    roomLegacyUuid: v.string(),
    name: v.string(),
    enemyType: v.string(),
    positionX: v.number(),
    positionY: v.number(),
    hp: v.number(),
    maxHp: v.number(),
    status: v.union(v.literal("active"), v.literal("defeated"), v.literal("escaped")),
    metadata: v.any(),
  },
  handler: async (ctx, args) => {
    const room = await requireRoomByLegacy(ctx, args.roomLegacyUuid);
    const existing = await byLegacy(ctx, "enemies", args.legacyUuid);
    const now = Date.now();
    const fields = {
      roomId: room._id,
      name: args.name,
      enemyType: args.enemyType,
      positionX: args.positionX,
      positionY: args.positionY,
      hp: args.hp,
      maxHp: args.maxHp,
      status: args.status,
      metadata: args.metadata,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      legacyUuid: args.legacyUuid,
    };
    if (existing) {
      assertSame(existing.roomId, room._id, "enemy is bound to a different room");
      await ctx.db.patch(existing._id, fields);
      return existing._id;
    }
    return await ctx.db.insert("enemies", fields);
  },
});

export const upsertCombat = internalMutation({
  args: {
    legacyUuid: v.string(),
    roomLegacyUuid: v.string(),
    active: v.boolean(),
    round: v.number(),
    startedAt: v.optional(v.number()),
    endedAt: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const room = await requireRoomByLegacy(ctx, args.roomLegacyUuid);
    const existing = await byLegacy(ctx, "combatSessions", args.legacyUuid);
    const fields = {
      roomId: room._id,
      active: args.active,
      round: args.round,
      startedAt: args.startedAt,
      endedAt: args.endedAt,
      updatedAt: Date.now(),
      legacyUuid: args.legacyUuid,
    };
    if (existing) {
      assertSame(existing.roomId, room._id, "combat is bound to a different room");
      await ctx.db.patch(existing._id, fields);
      return existing._id;
    }
    return await ctx.db.insert("combatSessions", fields);
  },
});

export const upsertRoll = internalMutation({
  args: {
    legacyUuid: v.string(),
    roomLegacyUuid: v.string(),
    playerLegacyUuid: v.string(),
    ability: v.string(),
    dc: v.number(),
    reason: v.string(),
    status: v.union(v.literal("pending"), v.literal("resolved"), v.literal("cancelled")),
    result: v.optional(v.number()),
    modifier: v.optional(v.number()),
    total: v.optional(v.number()),
    success: v.optional(v.boolean()),
    createdAt: v.number(),
    resolvedAt: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const room = await requireRoomByLegacy(ctx, args.roomLegacyUuid);
    const player = await requirePlayerByLegacy(ctx, args.playerLegacyUuid);
    const existing = await byLegacy(ctx, "pendingRolls", args.legacyUuid);
    const fields = {
      roomId: room._id,
      playerId: player._id,
      ability: args.ability as Doc<"pendingRolls">["ability"],
      dc: args.dc,
      reason: args.reason,
      status: args.status,
      result: args.result,
      modifier: args.modifier,
      total: args.total,
      success: args.success,
      createdAt: args.createdAt,
      resolvedAt: args.resolvedAt,
      legacyUuid: args.legacyUuid,
    };
    if (existing) {
      assertSame(existing.roomId, room._id, "roll is bound to a different room");
      assertSame(existing.playerId, player._id, "roll is bound to a different player");
      await ctx.db.patch(existing._id, fields);
      return existing._id;
    }
    return await ctx.db.insert("pendingRolls", fields);
  },
});

export const upsertDemo = internalMutation({
  args: {
    legacyUuid: v.string(),
    userLegacyUuid: v.string(),
    roomLegacyUuid: v.optional(v.string()),
    startedAt: v.optional(v.number()),
    expiresAt: v.optional(v.number()),
    completedAt: v.optional(v.number()),
    pausedAt: v.optional(v.number()),
    createdAt: v.number(),
  },
  handler: async (ctx, args) => {
    const user = await requireUserByLegacy(ctx, args.userLegacyUuid);
    const room = args.roomLegacyUuid
      ? await requireRoomByLegacy(ctx, args.roomLegacyUuid)
      : null;
    const existing = await byLegacy(ctx, "demoSessions", args.legacyUuid);
    const fields = {
      userId: user._id,
      roomId: room?._id,
      startedAt: args.startedAt,
      expiresAt: args.expiresAt,
      completedAt: args.completedAt,
      pausedAt: args.pausedAt,
      createdAt: args.createdAt,
      legacyUuid: args.legacyUuid,
    };
    if (existing) {
      assertSame(existing.userId, user._id, "demo session is bound to a different user");
      await ctx.db.patch(existing._id, fields);
      return existing._id;
    }
    return await ctx.db.insert("demoSessions", fields);
  },
});
