import {
  action,
  internalMutation,
  internalQuery,
} from "./_generated/server";
import type { ActionCtx, QueryCtx } from "./_generated/server";
import { v } from "convex/values";
import { api, internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { accessLevelForUser } from "./lib/access";
import { requireHost, requirePlayer, requireUser } from "./lib/auth";
import {
  cannedDemoEnding,
  ensureFinishAction,
  evaluateDemoPlay,
  nextDemoClock,
} from "./lib/demoClock";
import {
  DEMO_EXPIRED,
  ForbiddenError,
  GameMasterBackendError,
  GameRuleError,
  NOT_ENTITLED,
  RateLimitedError,
  RoomFinishedError,
} from "./lib/errors";
import { combatContextFromRow, type GmAction } from "./lib/stateEffects";
import {
  applyMemoryToGmState,
  nextMemory,
  parseMemory,
  RECENT_EVENT_LIMIT,
  recentEventsFromRows,
  shouldSummarize,
  summaryWindow,
} from "./lib/campaignMemory";
import { normalizeLocale } from "./lib/gmLocale";
import type { UsageStats } from "./lib/aiUsage";
import {
  DEFAULT_PER_HOUR,
  DEFAULT_PER_MINUTE,
  envLimit,
  rateLimitExceeded,
} from "./lib/rateLimit";
import {
  completeOpenRouterJson,
  InvalidOpenRouterJsonError,
} from "./lib/openRouter";
import {
  generatedPublicDict,
  parseGameMasterResponse,
  parseGeneratedScenario,
  publicWorldState,
  type GmResponse,
} from "./lib/gmValidate";
import {
  buildScenarioSystemPrompt,
  buildScenarioUserPrompt,
  buildSystemPrompt,
  buildUserPrompt,
} from "./prompts";
import { applyGameMasterActionsHandler } from "./applyActions";
import { NARRATIVE_MUSIC_MOODS } from "./lib/validators";

function worldRecord(value: unknown): Record<string, unknown> {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function normalizeMusicMood(value: unknown): string {
  const raw = String(value ?? "")
    .trim()
    .toLowerCase();
  if ((NARRATIVE_MUSIC_MOODS as readonly string[]).includes(raw)) {
    return raw;
  }
  return "exploration";
}

function assertRoomPlayable(status: string) {
  if (status === "demo_finished") {
    throw new RoomFinishedError(DEMO_EXPIRED);
  }
  if (status === "finished") {
    throw new RoomFinishedError("This game is finished.");
  }
}

async function assertDemoAccess(
  ctx: QueryCtx,
  args: {
    userId: Id<"users">;
    roomStatus: string;
    scenarioId?: string;
    hostUserId?: Id<"users">;
  },
) {
  assertRoomPlayable(args.roomStatus);
  const access = await accessLevelForUser(ctx, args.userId);
  if (access === "full") {
    return;
  }
  if (args.scenarioId !== "demo" || args.hostUserId !== args.userId) {
    throw new ForbiddenError(NOT_ENTITLED);
  }
}

export const assertRateLimit = internalQuery({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const perMinute = envLimit("RATE_LIMIT_PER_MINUTE", DEFAULT_PER_MINUTE);
    const perHour = envLimit("RATE_LIMIT_PER_HOUR", DEFAULT_PER_HOUR);
    if (perMinute <= 0 && perHour <= 0) {
      return;
    }
    const now = Date.now();
    const since = now - 3_600_000;
    const rows = await ctx.db
      .query("aiUsageEvents")
      .withIndex("by_user_and_created", (q) =>
        q.eq("userId", args.userId).gte("createdAt", since),
      )
      .collect();
    if (
      rateLimitExceeded({
        hits: rows.map((row) => row.createdAt),
        now,
        perMinute,
        perHour,
      })
    ) {
      throw new RateLimitedError();
    }
  },
});

export const recordUsage = internalMutation({
  args: {
    userId: v.optional(v.id("users")),
    roomId: v.optional(v.id("rooms")),
    kind: v.union(v.literal("game_master"), v.literal("scenario")),
    model: v.string(),
    inputTokens: v.optional(v.number()),
    outputTokens: v.optional(v.number()),
    latencyMs: v.optional(v.number()),
    cost: v.optional(v.number()),
    costSource: v.union(
      v.literal("none"),
      v.literal("openrouter"),
      v.literal("estimate"),
    ),
  },
  handler: async (ctx, args) => {
    await ctx.db.insert("aiUsageEvents", {
      userId: args.userId,
      roomId: args.roomId,
      model: args.model,
      kind: args.kind,
      inputTokens: args.inputTokens,
      outputTokens: args.outputTokens,
      latencyMs: args.latencyMs,
      cost: args.cost,
      costSource: args.costSource,
      createdAt: Date.now(),
    });
  },
});

async function tryRecordUsage(
  ctx: ActionCtx,
  args: {
    userId: Id<"users">;
    roomId: Id<"rooms">;
    kind: "game_master" | "scenario";
    stats: UsageStats;
  },
) {
  try {
    await ctx.runMutation(internal.gameMaster.recordUsage, {
      userId: args.userId,
      roomId: args.roomId,
      kind: args.kind,
      model: args.stats.model,
      inputTokens: args.stats.input_tokens ?? undefined,
      outputTokens: args.stats.output_tokens ?? undefined,
      latencyMs: args.stats.latency_ms,
      cost: args.stats.cost ?? undefined,
      costSource: args.stats.cost_source,
    });
  } catch {
    // Python: persist failure is logged and ignored.
  }
}

export const loadTurnContext = internalQuery({
  args: {
    roomId: v.id("rooms"),
    action: v.string(),
    includeRollResult: v.optional(v.any()),
  },
  handler: async (ctx, args) => {
    const { user, room, player } = await requirePlayer(ctx, args.roomId);
    await assertDemoAccess(ctx, {
      userId: user._id,
      roomStatus: room.status,
      scenarioId: room.scenarioId,
      hostUserId: room.hostUserId,
    });
    const action = args.action.trim();
    if (action.length < 1 || action.length > 1200) {
      throw new GameRuleError("Invalid action.");
    }
    const players = await ctx.db
      .query("players")
      .withIndex("by_room", (q) => q.eq("roomId", args.roomId))
      .collect();
    const enemies = await ctx.db
      .query("enemies")
      .withIndex("by_room", (q) => q.eq("roomId", args.roomId))
      .collect();
    const combatRows = await ctx.db
      .query("combatSessions")
      .withIndex("by_room", (q) => q.eq("roomId", args.roomId))
      .collect();
    const combatRow = combatRows[0] ?? null;
    const gmRows = await ctx.db
      .query("roomGmState")
      .withIndex("by_room", (q) => q.eq("roomId", args.roomId))
      .collect();
    const gmRow = gmRows[0];
    const gmSecrets = Array.isArray(gmRow?.gmSecrets)
      ? gmRow.gmSecrets
          .map((item) => String(item).trim().slice(0, 240))
          .filter(Boolean)
          .slice(0, 12)
      : [];
    const memory = parseMemory(gmRow?.gmState);
    const eventRows = await ctx.db
      .query("gameEvents")
      .withIndex("by_room_and_created", (q) => q.eq("roomId", args.roomId))
      .collect();
    const chronological = [...eventRows].sort((a, b) => a.createdAt - b.createdAt);
    const recent = recentEventsFromRows(
      chronological.map((row) => ({ type: row.type, content: row.content })),
    );
    return {
      userId: user._id,
      roomId: room._id,
      playerId: player._id,
      playerName: player.figurineName || "Aventurier",
      action,
      locale: normalizeLocale(room.locale),
      musicMood: normalizeMusicMood(room.musicMood),
      worldState: worldRecord(room.worldState),
      campaignSummary: memory.campaign_summary,
      gmSecrets,
      combat: combatContextFromRow(
        combatRow
          ? { active: combatRow.active, round: combatRow.round }
          : null,
      ),
      players: players
        .sort((a, b) => a.joinedAt - b.joinedAt)
        .map((row) => ({
          id: row._id,
          name: row.figurineName,
          hp: row.hp,
          figurine_id: row.figurineId,
          position: { x: row.positionX, y: row.positionY },
          inventory: row.inventory,
          strength: row.strength,
          dexterity: row.dexterity,
          constitution: row.constitution,
          intelligence: row.intelligence,
          wisdom: row.wisdom,
          charisma: row.charisma,
          effects: row.effects,
        })),
      enemies: enemies
        .sort((a, b) => a.createdAt - b.createdAt)
        .map((row) => ({
          id: row._id,
          name: row.name,
          enemy_type: row.enemyType,
          hp: row.hp,
          max_hp: row.maxHp,
          status: row.status,
          position: { x: row.positionX, y: row.positionY },
        })),
      recentEvents: recent,
      rollResult: args.includeRollResult ?? null,
    };
  },
});

export const syncDemoPlay = internalMutation({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, args) => {
    const { user, room } = await requirePlayer(ctx, args.roomId);
    const access = await accessLevelForUser(ctx, user._id);
    const sessions = await ctx.db
      .query("demoSessions")
      .withIndex("by_user", (q) => q.eq("userId", user._id))
      .collect();
    const session = [...sessions].sort((a, b) => a.createdAt - b.createdAt)[0];
    const now = Date.now();
    const status = evaluateDemoPlay({
      accessLevel: access,
      roomStatus: room.status,
      roomScenarioId: room.scenarioId,
      roomHostId: room.hostUserId,
      userId: user._id,
      startedAt: session?.startedAt,
      expiresAt: session?.expiresAt,
      completedAt: session?.completedAt,
      pausedAt: session?.pausedAt,
      now,
    });
    if (status !== "ok") {
      return { status, demoEndRequired: status === "expired" };
    }
    if (access === "full") {
      return { status: "ok" as const, demoEndRequired: false };
    }
    const clock = nextDemoClock({
      now,
      startedAt: session?.startedAt,
      expiresAt: session?.expiresAt,
      completedAt: session?.completedAt,
      pausedAt: session?.pausedAt,
    });
    if (clock.status === "ok" && session?.startedAt === undefined) {
      if (room.status === "paused") {
        return { status: "ok" as const, demoEndRequired: false };
      }
      if (session !== undefined) {
        const fresh = await ctx.db.get(session._id);
        if (fresh !== null && fresh.startedAt === undefined) {
          await ctx.db.patch(session._id, {
            startedAt: clock.startedAt,
            expiresAt: clock.expiresAt,
            roomId: fresh.roomId ?? args.roomId,
          });
        }
      } else {
        const again = await ctx.db
          .query("demoSessions")
          .withIndex("by_user", (q) => q.eq("userId", user._id))
          .collect();
        if (again.length === 0) {
          await ctx.db.insert("demoSessions", {
            userId: user._id,
            roomId: args.roomId,
            startedAt: clock.startedAt,
            expiresAt: clock.expiresAt,
            createdAt: now,
          });
        }
      }
    }
    return { status: "ok" as const, demoEndRequired: false };
  },
});

export const persistGmResponse = internalMutation({
  args: {
    roomId: v.id("rooms"),
    narration: v.string(),
    actions: v.array(
      v.object({
        type: v.string(),
        payload: v.optional(v.any()),
      }),
    ),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    await ctx.db.insert("gameEvents", {
      roomId: args.roomId,
      type: "narration",
      content: args.narration,
      createdAt: now,
    });
    const gmActions: GmAction[] = args.actions.map((action) => ({
      type: action.type,
      payload: action.payload,
    }));
    const effectSummaries = await applyGameMasterActionsHandler(ctx, {
      roomId: args.roomId,
      actions: gmActions,
    });
    if (effectSummaries.length > 0) {
      await ctx.db.insert("gameEvents", {
        roomId: args.roomId,
        type: "system",
        content: effectSummaries.join(" ; "),
        createdAt: Date.now(),
      });
    } else if (gmActions.length > 0) {
      const summaries = gmActions.map((action) => {
        const payloadEmpty =
          action.payload === undefined ||
          (typeof action.payload === "object" &&
            action.payload !== null &&
            !Array.isArray(action.payload) &&
            Object.keys(action.payload as object).length === 0);
        return payloadEmpty
          ? action.type
          : `${action.type}: ${JSON.stringify(action.payload)}`;
      });
      await ctx.db.insert("gameEvents", {
        roomId: args.roomId,
        type: "system",
        content: "Actions MJ: " + summaries.join("; "),
        createdAt: Date.now(),
      });
    }
    try {
      const events = await ctx.db
        .query("gameEvents")
        .withIndex("by_room_and_created", (q) => q.eq("roomId", args.roomId))
        .collect();
      const eventCount = events.length;
      const gmRows = await ctx.db
        .query("roomGmState")
        .withIndex("by_room", (q) => q.eq("roomId", args.roomId))
        .collect();
      const gmRow = gmRows[0];
      const memory = parseMemory(gmRow?.gmState);
      if (
        !shouldSummarize({
          eventCount,
          summarizedEventCount: memory.summarized_event_count,
        })
      ) {
        return;
      }
      const window = summaryWindow({
        eventCount,
        summarizedEventCount: memory.summarized_event_count,
      });
      const chronological = [...events].sort((a, b) => a.createdAt - b.createdAt);
      const folded = chronological
        .slice(window.start, window.start + window.limit)
        .map((row) => ({ type: row.type, content: row.content }));
      const updated = nextMemory({
        previous: memory,
        foldedEvents: folded,
        eventCount,
      });
      const gmState = applyMemoryToGmState(gmRow?.gmState, updated);
      if (gmRow) {
        await ctx.db.patch(gmRow._id, {
          gmState,
          updatedAt: Date.now(),
        });
      } else {
        await ctx.db.insert("roomGmState", {
          roomId: args.roomId,
          gmSecrets: [],
          gmState,
          updatedAt: Date.now(),
        });
      }
    } catch {
      // Python: campaign summary refresh failure is logged and ignored.
    }
  },
});

export const persistGeneratedScenario = internalMutation({
  args: {
    roomId: v.id("rooms"),
    worldState: v.any(),
    scenarioTitle: v.string(),
    scenarioPrompt: v.string(),
    gmSecrets: v.array(v.string()),
    openingNarration: v.string(),
  },
  handler: async (ctx, args) => {
    const { room } = await requireHost(ctx, args.roomId);
    if (room.scenarioId !== "custom") {
      throw new GameRuleError(
        "Scenario generation is only allowed for custom rooms.",
      );
    }
    await ctx.db.patch(room._id, {
      worldState: args.worldState,
      scenario: args.scenarioTitle,
      scenarioPrompt: args.scenarioPrompt,
    });
    const existing = await ctx.db
      .query("roomGmState")
      .withIndex("by_room", (q) => q.eq("roomId", args.roomId))
      .collect();
    if (existing[0]) {
      await ctx.db.patch(existing[0]._id, {
        gmSecrets: args.gmSecrets,
        updatedAt: Date.now(),
      });
    } else {
      await ctx.db.insert("roomGmState", {
        roomId: args.roomId,
        gmSecrets: args.gmSecrets,
        gmState: {},
        updatedAt: Date.now(),
      });
    }
    if (args.openingNarration) {
      await ctx.db.insert("gameEvents", {
        roomId: args.roomId,
        type: "narration",
        content: args.openingNarration,
        createdAt: Date.now(),
      });
    }
  },
});

async function requestGmDecoded(
  ctx: ActionCtx,
  args: {
    userId: Id<"users">;
    roomId: Id<"rooms">;
    locale: string;
    promptRequest: Parameters<typeof buildUserPrompt>[0];
  },
): Promise<Record<string, unknown>> {
  try {
    const result = await completeOpenRouterJson({
      messages: [
        { role: "system", content: buildSystemPrompt(args.locale) },
        { role: "user", content: buildUserPrompt(args.promptRequest) },
      ],
      temperature: 0.7,
      maxTokens: 900,
      title: "DragonsLair Game Master",
    });
    await tryRecordUsage(ctx, {
      userId: args.userId,
      roomId: args.roomId,
      kind: "game_master",
      stats: result.stats,
    });
    return result.decoded;
  } catch (error) {
    if (error instanceof InvalidOpenRouterJsonError) {
      await tryRecordUsage(ctx, {
        userId: args.userId,
        roomId: args.roomId,
        kind: "game_master",
        stats: error.stats,
      });
    }
    throw error;
  }
}

async function runGmTurn(
  ctx: ActionCtx,
  args: {
    userId: Id<"users">;
    roomId: Id<"rooms">;
    action: string;
    includeRollResult?: unknown;
  },
): Promise<GmResponse> {
  const loaded = await ctx.runQuery(internal.gameMaster.loadTurnContext, {
    roomId: args.roomId,
    action: args.action,
    includeRollResult: args.includeRollResult,
  });
  const gate = await ctx.runMutation(internal.gameMaster.syncDemoPlay, {
    roomId: args.roomId,
  });
  if (gate.status === "closed") {
    throw new RoomFinishedError(DEMO_EXPIRED);
  }
  if (gate.status === "forbidden") {
    throw new ForbiddenError(NOT_ENTITLED);
  }
  const demoEndRequired = gate.demoEndRequired === true;
  const promptRequest = {
    locale: loaded.locale,
    world_state: loaded.worldState,
    campaign_summary: loaded.campaignSummary,
    players: loaded.players,
    enemies: loaded.enemies,
    combat: loaded.combat,
    music_mood: loaded.musicMood,
    recent_events: loaded.recentEvents,
    player_id: loaded.playerId,
    player_name: loaded.playerName,
    action: loaded.action,
    demo_end_required: demoEndRequired,
    roll_result:
      loaded.rollResult === null
        ? null
        : (loaded.rollResult as Record<string, unknown>),
    gm_secrets: loaded.gmSecrets,
  };
  let response: GmResponse;
  if (demoEndRequired) {
    try {
      const decoded = ensureFinishAction(
        await requestGmDecoded(ctx, {
          userId: args.userId,
          roomId: args.roomId,
          locale: loaded.locale,
          promptRequest,
        }),
        loaded.locale,
      );
      response = parseGameMasterResponse(decoded);
    } catch (error) {
      if (
        error instanceof RateLimitedError ||
        error instanceof RoomFinishedError ||
        error instanceof ForbiddenError
      ) {
        throw error;
      }
      if (!(error instanceof GameMasterBackendError)) {
        throw error;
      }
      response = parseGameMasterResponse(cannedDemoEnding(loaded.locale));
    }
  } else {
    const decoded = await requestGmDecoded(ctx, {
      userId: args.userId,
      roomId: args.roomId,
      locale: loaded.locale,
      promptRequest,
    });
    response = parseGameMasterResponse(decoded);
  }
  await ctx.runMutation(internal.gameMaster.persistGmResponse, {
    roomId: args.roomId,
    narration: response.narration,
    actions: response.actions,
  });
  return response;
}

export const respond = action({
  args: {
    roomId: v.id("rooms"),
    action: v.string(),
  },
  handler: async (ctx, args): Promise<GmResponse> => {
    const userId = await ctx.runQuery(internal.gameMaster.currentUserId, {});
    await ctx.runQuery(internal.gameMaster.assertRateLimit, { userId });
    return await runGmTurn(ctx, {
      userId,
      roomId: args.roomId,
      action: args.action,
    });
  },
});

export const resolveRoll = action({
  args: {
    pendingRollId: v.id("pendingRolls"),
    raw: v.number(),
  },
  handler: async (ctx, args): Promise<GmResponse> => {
    const userId = await ctx.runQuery(internal.gameMaster.currentUserId, {});
    await ctx.runQuery(internal.gameMaster.assertRateLimit, { userId });
    const resolved = await ctx.runMutation(api.rolls.resolve, {
      pendingRollId: args.pendingRollId,
      raw: args.raw,
    });
    return await runGmTurn(ctx, {
      userId,
      roomId: resolved.roomId,
      action: resolved.content,
      includeRollResult: {
        pending_roll_id: resolved.pendingRollId,
        player_id: resolved.playerId,
        ability: resolved.ability,
        dc: resolved.dc,
        raw: resolved.raw,
        modifier: resolved.modifier,
        total: resolved.total,
        success: resolved.success,
        reason: resolved.reason,
      },
    });
  },
});

export const generate = action({
  args: {
    roomId: v.id("rooms"),
    prompt: v.string(),
    title: v.optional(v.string()),
    tone: v.optional(v.string()),
    difficulty: v.optional(v.string()),
    duration: v.optional(v.string()),
    orientations: v.optional(v.array(v.string())),
    improvise: v.optional(v.boolean()),
    permadeath: v.optional(v.boolean()),
    pvp: v.optional(v.boolean()),
    betrayals: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    const prepared = await ctx.runQuery(internal.gameMaster.prepareGenerate, {
      roomId: args.roomId,
    });
    const prompt = args.prompt.trim();
    if (prompt.length < 20 || prompt.length > 2000) {
      throw new GameRuleError("Invalid scenario prompt.");
    }
    await ctx.runQuery(internal.gameMaster.assertRateLimit, {
      userId: prepared.userId,
    });
    const locale = prepared.locale;
    let decoded: Record<string, unknown>;
    try {
      const result = await completeOpenRouterJson({
        messages: [
          { role: "system", content: buildScenarioSystemPrompt(locale) },
          {
            role: "user",
            content: buildScenarioUserPrompt({
              prompt,
              title: args.title ?? "",
              tone: args.tone ?? "",
              difficulty: args.difficulty ?? "standard",
              duration: args.duration ?? "medium",
              orientations: args.orientations ?? [],
              improvise: args.improvise ?? true,
              permadeath: args.permadeath ?? false,
              pvp: args.pvp ?? false,
              betrayals: args.betrayals ?? false,
            }),
          },
        ],
        temperature: 0.8,
        maxTokens: 1200,
        title: "DragonsLair Scenario",
      });
      await tryRecordUsage(ctx, {
        userId: prepared.userId,
        roomId: args.roomId,
        kind: "scenario",
        stats: result.stats,
      });
      decoded = result.decoded;
    } catch (error) {
      if (error instanceof InvalidOpenRouterJsonError) {
        await tryRecordUsage(ctx, {
          userId: prepared.userId,
          roomId: args.roomId,
          kind: "scenario",
          stats: error.stats,
        });
      }
      throw error;
    }
    const generated = parseGeneratedScenario(decoded);
    const worldState = publicWorldState(generatedPublicDict(generated));
    const secrets = generated.gm_secrets;
    const title = generated.title.trim() || (args.title ?? "").trim() || "Aventure";
    const opening = generated.opening_narration.trim();
    await ctx.runMutation(internal.gameMaster.persistGeneratedScenario, {
      roomId: args.roomId,
      worldState,
      scenarioTitle: title,
      scenarioPrompt: prompt,
      gmSecrets: secrets,
      openingNarration: opening,
    });
    return { world_state: worldState, opening_narration: opening };
  },
});

export const currentUserId = internalQuery({
  args: {},
  handler: async (ctx) => {
    const { user } = await requireUser(ctx);
    return user._id;
  },
});

export const prepareGenerate = internalQuery({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, args) => {
    const { user, room } = await requireHost(ctx, args.roomId);
    const access = await accessLevelForUser(ctx, user._id);
    if (access !== "full") {
      throw new ForbiddenError(NOT_ENTITLED);
    }
    if (room.scenarioId !== "custom") {
      throw new GameRuleError(
        "Scenario generation is only allowed for custom rooms.",
      );
    }
    return { userId: user._id, locale: normalizeLocale(room.locale) };
  },
});
