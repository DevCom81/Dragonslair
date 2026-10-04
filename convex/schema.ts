import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";
import {
  accessLevel,
  aiCostSource,
  aiUsageKind,
  abilityKey,
  characterStat,
  enemyStatus,
  entitlementGrantSource,
  entitlementProvider,
  entitlementSourceStatus,
  gameEventType,
  narrativeMusicMood,
  pendingRollStatus,
  roomLocale,
  roomStatus,
} from "./lib/validators";

const characterStats = {
  strength: characterStat,
  dexterity: characterStat,
  constitution: characterStat,
  intelligence: characterStat,
  wisdom: characterStat,
  charisma: characterStat,
};

export default defineSchema({
  users: defineTable({
    workosSubject: v.string(),
    email: v.optional(v.string()),
    legacyUuid: v.optional(v.string()),
    createdAt: v.number(),
  })
    .index("by_workos_subject", ["workosSubject"])
    .index("by_email", ["email"])
    .index("by_legacy_uuid", ["legacyUuid"]),

  profiles: defineTable({
    userId: v.id("users"),
    displayName: v.string(),
    classId: v.optional(v.string()),
    avatarFigurineId: v.optional(v.number()),
    sheetConfirmed: v.boolean(),
    createdAt: v.number(),
    legacyUuid: v.optional(v.string()),
    ...characterStats,
  })
    .index("by_user", ["userId"])
    .index("by_legacy_uuid", ["legacyUuid"]),

  rooms: defineTable({
    name: v.string(),
    scenario: v.optional(v.string()),
    scenarioId: v.optional(v.string()),
    status: roomStatus,
    createdAt: v.number(),
    hostUserId: v.optional(v.id("users")),
    joinCode: v.string(),
    minPlayers: v.number(),
    requiredClassIds: v.array(v.string()),
    scenarioPrompt: v.string(),
    worldState: v.any(),
    locale: roomLocale,
    startedAt: v.optional(v.number()),
    finishedAt: v.optional(v.number()),
    gamePhase: v.optional(v.string()),
    ending: v.any(),
    musicMood: narrativeMusicMood,
    legacyUuid: v.optional(v.string()),
  })
    .index("by_join_code", ["joinCode"])
    .index("by_status", ["status"])
    .index("by_host", ["hostUserId"])
    .index("by_legacy_uuid", ["legacyUuid"]),

  players: defineTable({
    roomId: v.id("rooms"),
    userId: v.id("users"),
    figurineId: v.number(),
    figurineName: v.string(),
    positionX: v.number(),
    positionY: v.number(),
    hp: v.number(),
    inventory: v.array(v.any()),
    joinedAt: v.number(),
    classId: v.optional(v.string()),
    effects: v.array(v.any()),
    legacyUuid: v.optional(v.string()),
    ...characterStats,
  })
    .index("by_room", ["roomId"])
    .index("by_room_and_user", ["roomId", "userId"])
    .index("by_room_and_figurine", ["roomId", "figurineId"])
    .index("by_room_and_class", ["roomId", "classId"])
    .index("by_user", ["userId"])
    .index("by_legacy_uuid", ["legacyUuid"]),

  gameEvents: defineTable({
    roomId: v.id("rooms"),
    playerId: v.optional(v.id("players")),
    type: gameEventType,
    content: v.string(),
    createdAt: v.number(),
    legacyUuid: v.optional(v.string()),
  })
    .index("by_room", ["roomId"])
    .index("by_room_and_created", ["roomId", "createdAt"])
    .index("by_legacy_uuid", ["legacyUuid"]),

  enemies: defineTable({
    roomId: v.id("rooms"),
    name: v.string(),
    enemyType: v.string(),
    positionX: v.number(),
    positionY: v.number(),
    hp: v.number(),
    maxHp: v.number(),
    status: enemyStatus,
    metadata: v.any(),
    createdAt: v.number(),
    updatedAt: v.number(),
    legacyUuid: v.optional(v.string()),
  })
    .index("by_room", ["roomId"])
    .index("by_room_and_status", ["roomId", "status"])
    .index("by_legacy_uuid", ["legacyUuid"]),

  combatSessions: defineTable({
    roomId: v.id("rooms"),
    active: v.boolean(),
    round: v.number(),
    startedAt: v.optional(v.number()),
    endedAt: v.optional(v.number()),
    updatedAt: v.number(),
    legacyUuid: v.optional(v.string()),
  })
    .index("by_room", ["roomId"])
    .index("by_legacy_uuid", ["legacyUuid"]),

  pendingRolls: defineTable({
    roomId: v.id("rooms"),
    playerId: v.id("players"),
    ability: abilityKey,
    dc: v.number(),
    reason: v.string(),
    status: pendingRollStatus,
    result: v.optional(v.number()),
    modifier: v.optional(v.number()),
    total: v.optional(v.number()),
    success: v.optional(v.boolean()),
    createdAt: v.number(),
    resolvedAt: v.optional(v.number()),
    legacyUuid: v.optional(v.string()),
  })
    .index("by_room", ["roomId"])
    .index("by_room_and_status", ["roomId", "status"])
    .index("by_player", ["playerId"])
    .index("by_player_and_status", ["playerId", "status"])
    .index("by_legacy_uuid", ["legacyUuid"]),

  roomGmState: defineTable({
    roomId: v.id("rooms"),
    gmSecrets: v.any(),
    gmState: v.any(),
    updatedAt: v.number(),
  }).index("by_room", ["roomId"]),

  userEntitlements: defineTable({
    userId: v.id("users"),
    accessLevel: accessLevel,
    source: entitlementGrantSource,
    grantedAt: v.number(),
    expiresAt: v.optional(v.number()),
    metadata: v.any(),
    legacyUuid: v.optional(v.string()),
  })
    .index("by_user", ["userId"])
    .index("by_legacy_uuid", ["legacyUuid"]),

  entitlementSources: defineTable({
    userId: v.id("users"),
    provider: entitlementProvider,
    providerRef: v.string(),
    status: entitlementSourceStatus,
    currentPeriodEnd: v.optional(v.number()),
    metadata: v.any(),
    createdAt: v.number(),
    updatedAt: v.number(),
    legacyUuid: v.optional(v.string()),
  })
    .index("by_user", ["userId"])
    .index("by_user_provider_ref", ["userId", "provider", "providerRef"])
    .index("by_provider_ref", ["provider", "providerRef"])
    .index("by_legacy_uuid", ["legacyUuid"]),

  demoSessions: defineTable({
    userId: v.id("users"),
    roomId: v.optional(v.id("rooms")),
    startedAt: v.optional(v.number()),
    expiresAt: v.optional(v.number()),
    completedAt: v.optional(v.number()),
    pausedAt: v.optional(v.number()),
    createdAt: v.number(),
    legacyUuid: v.optional(v.string()),
  })
    .index("by_user", ["userId"])
    .index("by_room", ["roomId"])
    .index("by_legacy_uuid", ["legacyUuid"]),

  aiUsageEvents: defineTable({
    userId: v.optional(v.id("users")),
    roomId: v.optional(v.id("rooms")),
    model: v.string(),
    kind: aiUsageKind,
    inputTokens: v.optional(v.number()),
    outputTokens: v.optional(v.number()),
    latencyMs: v.optional(v.number()),
    cost: v.optional(v.number()),
    costSource: aiCostSource,
    createdAt: v.number(),
  })
    .index("by_room_and_created", ["roomId", "createdAt"])
    .index("by_user_and_created", ["userId", "createdAt"]),

  // Legacy migration audit data only. Not used by the runtime auth path.
  identityMap: defineTable({
    supabaseUserId: v.string(),
    workosSubject: v.string(),
    convexUserId: v.optional(v.id("users")),
  })
    .index("by_supabase_user", ["supabaseUserId"])
    .index("by_workos_subject", ["workosSubject"]),

});
