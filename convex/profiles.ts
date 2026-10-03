import { mutation, query } from "./_generated/server";
import type { MutationCtx } from "./_generated/server";
import type { Doc, Id } from "./_generated/dataModel";
import { v } from "convex/values";
import { requireUser } from "./lib/auth";
import {
  isCharacterClassId,
  isDisplayName,
  isFigurineId,
  isStatInRange,
} from "./lib/validators";

export class InvalidProfileError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "InvalidProfileError";
  }
}

const DEFAULT_STAT = 10;

const characterStatsValidator = {
  strength: v.number(),
  dexterity: v.number(),
  constitution: v.number(),
  intelligence: v.number(),
  wisdom: v.number(),
  charisma: v.number(),
};

async function profilesForUser(ctx: MutationCtx, userId: Id<"users">) {
  return await ctx.db
    .query("profiles")
    .withIndex("by_user", (q) => q.eq("userId", userId))
    .collect();
}

function oldestProfile(rows: Doc<"profiles">[]) {
  return rows.reduce((oldest, row) =>
    row._creationTime < oldest._creationTime ? row : oldest,
  );
}

async function getProfileForUser(ctx: MutationCtx, userId: Id<"users">) {
  const rows = await profilesForUser(ctx, userId);
  if (rows.length === 0) {
    return null;
  }
  return oldestProfile(rows);
}

function requireDisplayName(displayName: string) {
  const trimmed = displayName.trim();
  if (!isDisplayName(trimmed)) {
    throw new InvalidProfileError(
      "Le pseudo doit contenir entre 2 et 32 caracteres.",
    );
  }
  return trimmed;
}

function requireStats(stats: {
  strength: number;
  dexterity: number;
  constitution: number;
  intelligence: number;
  wisdom: number;
  charisma: number;
}) {
  const keys = [
    "strength",
    "dexterity",
    "constitution",
    "intelligence",
    "wisdom",
    "charisma",
  ] as const;
  for (const key of keys) {
    if (!isStatInRange(stats[key])) {
      throw new InvalidProfileError(`${key} must be between 8 and 18`);
    }
  }
  return stats;
}

function requireClassId(classId: string) {
  if (!isCharacterClassId(classId)) {
    throw new InvalidProfileError("Classe invalide.");
  }
  return classId;
}

function requireAvatar(figurineId: number | null) {
  if (figurineId === null) {
    return null;
  }
  if (!isFigurineId(figurineId)) {
    throw new InvalidProfileError("Figurine invalide.");
  }
  return figurineId;
}

export const getMine = query({
  args: {},
  handler: async (ctx) => {
    const { user } = await requireUser(ctx);
    const rows = await ctx.db
      .query("profiles")
      .withIndex("by_user", (q) => q.eq("userId", user._id))
      .collect();
    if (rows.length === 0) {
      return null;
    }
    return oldestProfile(rows);
  },
});

export const upsertDisplayName = mutation({
  args: {
    displayName: v.string(),
  },
  handler: async (ctx, args) => {
    const { user } = await requireUser(ctx);
    const displayName = requireDisplayName(args.displayName);
    const existing = await getProfileForUser(ctx, user._id);
    if (existing !== null) {
      await ctx.db.patch(existing._id, { displayName });
      return await ctx.db.get(existing._id);
    }
    const now = Date.now();
    const profileId = await ctx.db.insert("profiles", {
      userId: user._id,
      displayName,
      sheetConfirmed: false,
      createdAt: now,
      strength: DEFAULT_STAT,
      dexterity: DEFAULT_STAT,
      constitution: DEFAULT_STAT,
      intelligence: DEFAULT_STAT,
      wisdom: DEFAULT_STAT,
      charisma: DEFAULT_STAT,
    });
    return await ctx.db.get(profileId);
  },
});

export const upsertSheet = mutation({
  args: {
    displayName: v.string(),
    classId: v.string(),
    ...characterStatsValidator,
  },
  handler: async (ctx, args) => {
    const { user } = await requireUser(ctx);
    const displayName = requireDisplayName(args.displayName);
    const classId = requireClassId(args.classId);
    const stats = requireStats({
      strength: args.strength,
      dexterity: args.dexterity,
      constitution: args.constitution,
      intelligence: args.intelligence,
      wisdom: args.wisdom,
      charisma: args.charisma,
    });
    const existing = await getProfileForUser(ctx, user._id);
    if (existing !== null) {
      await ctx.db.patch(existing._id, {
        displayName,
        classId,
        sheetConfirmed: true,
        ...stats,
      });
      return await ctx.db.get(existing._id);
    }
    const profileId = await ctx.db.insert("profiles", {
      userId: user._id,
      displayName,
      classId,
      sheetConfirmed: true,
      createdAt: Date.now(),
      ...stats,
    });
    return await ctx.db.get(profileId);
  },
});

export const upsertAvatar = mutation({
  args: {
    figurineId: v.union(v.number(), v.null()),
  },
  handler: async (ctx, args) => {
    const { user } = await requireUser(ctx);
    const avatarFigurineId = requireAvatar(args.figurineId);
    const existing = await getProfileForUser(ctx, user._id);
    if (existing === null) {
      throw new InvalidProfileError("Profile not found");
    }
    const { _id, _creationTime, avatarFigurineId: _previousAvatar, ...rest } =
      existing;
    await ctx.db.replace(_id, {
      ...rest,
      ...(avatarFigurineId === null ? {} : { avatarFigurineId }),
    });
    return await ctx.db.get(existing._id);
  },
});
