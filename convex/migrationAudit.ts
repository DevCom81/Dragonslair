import { internalQuery } from "./_generated/server";

function idOf(value: { _id: string } | string): string {
  return typeof value === "string" ? value : String(value._id);
}

export const snapshot = internalQuery({
  args: {},
  handler: async (ctx) => {
    const [
      users,
      profiles,
      sources,
      entitlements,
      rooms,
      players,
      events,
      enemies,
      combat,
      rolls,
      gmRows,
      demos,
      aiUsage,
    ] = await Promise.all([
      ctx.db.query("users").collect(),
      ctx.db.query("profiles").collect(),
      ctx.db.query("entitlementSources").collect(),
      ctx.db.query("userEntitlements").collect(),
      ctx.db.query("rooms").collect(),
      ctx.db.query("players").collect(),
      ctx.db.query("gameEvents").collect(),
      ctx.db.query("enemies").collect(),
      ctx.db.query("combatSessions").collect(),
      ctx.db.query("pendingRolls").collect(),
      ctx.db.query("roomGmState").collect(),
      ctx.db.query("demoSessions").collect(),
      ctx.db.query("aiUsageEvents").collect(),
    ]);
    return {
      users: users.map((row) => ({
        convexId: idOf(row),
        workosSubject: row.workosSubject,
        legacyUuid: row.legacyUuid,
      })),
      profiles: profiles.map((row) => ({
        convexId: idOf(row),
        userId: String(row.userId),
        legacyUuid: row.legacyUuid,
        classId: row.classId,
        sheetConfirmed: row.sheetConfirmed,
      })),
      sources: sources.map((row) => ({
        convexId: idOf(row),
        userId: String(row.userId),
        provider: row.provider,
        providerRef: row.providerRef,
        status: row.status,
        legacyUuid: row.legacyUuid,
      })),
      entitlements: entitlements.map((row) => ({
        userId: String(row.userId),
        accessLevel: row.accessLevel,
        source: row.source,
      })),
      rooms: rooms.map((row) => ({
        convexId: idOf(row),
        hostUserId: row.hostUserId ? String(row.hostUserId) : undefined,
        legacyUuid: row.legacyUuid,
        status: row.status,
        scenarioId: row.scenarioId,
      })),
      players: players.map((row) => ({
        convexId: idOf(row),
        roomId: String(row.roomId),
        userId: String(row.userId),
        legacyUuid: row.legacyUuid,
      })),
      events: events.map((row) => ({
        convexId: idOf(row),
        roomId: String(row.roomId),
        playerId: row.playerId ? String(row.playerId) : undefined,
        legacyUuid: row.legacyUuid,
      })),
      enemies: enemies.map((row) => ({
        convexId: idOf(row),
        roomId: String(row.roomId),
        legacyUuid: row.legacyUuid,
      })),
      combat: combat.map((row) => ({
        convexId: idOf(row),
        roomId: String(row.roomId),
        legacyUuid: row.legacyUuid,
      })),
      rolls: rolls.map((row) => ({
        convexId: idOf(row),
        roomId: String(row.roomId),
        playerId: String(row.playerId),
        legacyUuid: row.legacyUuid,
      })),
      gmRooms: gmRows.map((row) => String(row.roomId)),
      demos: demos.map((row) => ({
        convexId: idOf(row),
        userId: String(row.userId),
        roomId: row.roomId ? String(row.roomId) : undefined,
        legacyUuid: row.legacyUuid,
      })),
      aiUsageCount: aiUsage.length,
    };
  },
});

function prefixId(value: string | undefined): string | null {
  if (!value) {
    return null;
  }
  return value.length <= 8 ? value : value.slice(0, 8);
}

export const characterizeAiUsage = internalQuery({
  args: {},
  handler: async (ctx) => {
    const rows = await ctx.db.query("aiUsageEvents").collect();
    const users = await ctx.db.query("users").collect();
    const rooms = await ctx.db.query("rooms").collect();
    const usersById = new Map(users.map((row) => [String(row._id), row]));
    const roomsById = new Map(rooms.map((row) => [String(row._id), row]));
    return {
      schemaHasLegacyUuid: false,
      count: rows.length,
      events: rows.map((row) => {
        const user = row.userId ? usersById.get(String(row.userId)) : undefined;
        const room = row.roomId ? roomsById.get(String(row.roomId)) : undefined;
        return {
          idPrefix: prefixId(String(row._id)),
          creationTime: row._creationTime,
          createdAt: row.createdAt,
          userIdPrefix: prefixId(row.userId ? String(row.userId) : undefined),
          roomIdPrefix: prefixId(row.roomId ? String(row.roomId) : undefined),
          userIsMigrated: Boolean(user?.legacyUuid),
          roomIsMigrated: Boolean(room?.legacyUuid),
          model: row.model,
          kind: row.kind,
          costSource: row.costSource,
          migrationMarker: null,
        };
      }),
    };
  },
});
