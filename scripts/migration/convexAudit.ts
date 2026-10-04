import { classifyAuthUsers } from "./classify";
import type { ConvexImportPlan } from "./convexImportPlan";
import type { Finding, MigrationBundle } from "./types";

export type B5Verdict = "B5_PASS" | "B5_BLOCKED";

export type MigrationAuditSnapshot = {
  users: Array<{ convexId: string; workosSubject: string; legacyUuid?: string }>;
  profiles: Array<{
    convexId: string;
    userId: string;
    legacyUuid?: string;
    classId?: string;
    sheetConfirmed: boolean;
  }>;
  sources: Array<{
    convexId: string;
    userId: string;
    provider: string;
    providerRef: string;
    status: string;
    legacyUuid?: string;
  }>;
  entitlements: Array<{ userId: string; accessLevel: string; source: string }>;
  rooms: Array<{
    convexId: string;
    hostUserId?: string;
    legacyUuid?: string;
    status: string;
    scenarioId?: string;
  }>;
  players: Array<{
    convexId: string;
    roomId: string;
    userId: string;
    legacyUuid?: string;
  }>;
  events: Array<{
    convexId: string;
    roomId: string;
    playerId?: string;
    legacyUuid?: string;
  }>;
  enemies: Array<{ convexId: string; roomId: string; legacyUuid?: string }>;
  combat: Array<{ convexId: string; roomId: string; legacyUuid?: string }>;
  rolls: Array<{
    convexId: string;
    roomId: string;
    playerId: string;
    legacyUuid?: string;
  }>;
  gmRooms: string[];
  demos: Array<{
    convexId: string;
    userId: string;
    roomId?: string;
    legacyUuid?: string;
  }>;
  aiUsageCount: number;
};

export type B5Report = {
  verdict: B5Verdict;
  counts: Record<string, { expected: number; actual: number }>;
  identity: { expected: number; matched: number };
  relations: { orphans: number; wrong_parent: number };
  archives: {
    anonymous_users_imported: number;
    anonymous_rooms_imported: number;
    ai_usage_imported: number;
    ai_usage_native: number;
  };
  entitlements: { expected: number; matched: number };
  findings: Finding[];
};

function prefix(legacy: string): string {
  return legacy.length <= 8 ? legacy : legacy.slice(0, 8);
}

function add(
  findings: Finding[],
  code: string,
  message: string,
  refs?: Record<string, string>,
) {
  findings.push({ severity: "CRITICAL", code, message, refs });
}

function indexByLegacy<T extends { legacyUuid?: string }>(rows: T[]): Map<string, T[]> {
  const map = new Map<string, T[]>();
  for (const row of rows) {
    if (!row.legacyUuid) {
      continue;
    }
    const list = map.get(row.legacyUuid) ?? [];
    list.push(row);
    map.set(row.legacyUuid, list);
  }
  return map;
}

function duplicates<T>(values: T[]): T[] {
  const seen = new Set<T>();
  const dup = new Set<T>();
  for (const value of values) {
    if (seen.has(value)) {
      dup.add(value);
    }
    seen.add(value);
  }
  return [...dup];
}

export function archivedLegacyIds(bundle: MigrationBundle): {
  users: Set<string>;
  rooms: Set<string>;
  players: Set<string>;
} {
  const classified = classifyAuthUsers({
    authUsers: bundle.auth_users,
    sources: bundle.entitlement_sources,
    entitlements: bundle.user_entitlements,
    rooms: bundle.rooms,
    players: bundle.players,
    demos: bundle.demo_sessions,
  });
  const users = new Set(
    Object.entries(classified)
      .filter(([, category]) => category === "ignored_anonymous")
      .map(([id]) => id),
  );
  const rooms = new Set(
    bundle.rooms.filter((room) => users.has(String(room.host_id ?? ""))).map((room) => room.id),
  );
  const players = new Set(
    bundle.players.filter((row) => rooms.has(row.room_id) || users.has(row.user_id)).map((row) => row.id),
  );
  return { users, rooms, players };
}

export function compareMigrationAudit(
  plan: ConvexImportPlan,
  archived: { users: Set<string>; rooms: Set<string>; players: Set<string> },
  snapshot: MigrationAuditSnapshot,
): B5Report {
  const findings: Finding[] = [];
  const userByLegacy = indexByLegacy(snapshot.users);
  const userBySubject = new Map<string, typeof snapshot.users>();
  for (const user of snapshot.users) {
    const list = userBySubject.get(user.workosSubject) ?? [];
    list.push(user);
    userBySubject.set(user.workosSubject, list);
  }
  const profileByLegacy = indexByLegacy(snapshot.profiles);
  const sourceByLegacy = indexByLegacy(snapshot.sources);
  const roomByLegacy = indexByLegacy(snapshot.rooms);
  const playerByLegacy = indexByLegacy(snapshot.players);
  const eventByLegacy = indexByLegacy(snapshot.events);
  const enemyByLegacy = indexByLegacy(snapshot.enemies);
  const combatByLegacy = indexByLegacy(snapshot.combat);
  const rollByLegacy = indexByLegacy(snapshot.rolls);
  const demoByLegacy = indexByLegacy(snapshot.demos);
  const convexIds = new Set([
    ...snapshot.users.map((row) => row.convexId),
    ...snapshot.profiles.map((row) => row.convexId),
    ...snapshot.rooms.map((row) => row.convexId),
    ...snapshot.players.map((row) => row.convexId),
    ...snapshot.events.map((row) => row.convexId),
    ...snapshot.enemies.map((row) => row.convexId),
    ...snapshot.combat.map((row) => row.convexId),
    ...snapshot.rolls.map((row) => row.convexId),
    ...snapshot.demos.map((row) => row.convexId),
  ]);

  let identityMatched = 0;
  for (const user of plan.users) {
    const byLegacy = userByLegacy.get(user.legacyUuid) ?? [];
    const bySubject = userBySubject.get(user.workosSubject) ?? [];
    if (byLegacy.length !== 1) {
      add(findings, "DUPLICATE_LEGACY_UUID", "Migrated user legacyUuid is missing or duplicated", {
        legacy: prefix(user.legacyUuid),
      });
      continue;
    }
    if (bySubject.length !== 1) {
      add(
        findings,
        "DUPLICATE_WORKOS_SUBJECT",
        "WorkOS subject does not resolve to exactly one Convex user",
        { legacy: prefix(user.legacyUuid) },
      );
      continue;
    }
    if (byLegacy[0]!.convexId !== bySubject[0]!.convexId) {
      add(findings, "IDENTITY_SPLIT", "legacyUuid and workosSubject map to different Convex users", {
        legacy: prefix(user.legacyUuid),
      });
      continue;
    }
    if (byLegacy[0]!.workosSubject !== user.workosSubject) {
      add(findings, "WORKOS_MISMATCH", "Convex workosSubject does not match WorkOS mapping", {
        legacy: prefix(user.legacyUuid),
      });
      continue;
    }
    identityMatched += 1;
  }
  for (const subject of duplicates(snapshot.users.map((row) => row.workosSubject))) {
    add(findings, "DUPLICATE_WORKOS_SUBJECT", "Duplicate WorkOS subject in Convex users");
    void subject;
  }
  for (const legacy of duplicates(
    snapshot.users.map((row) => row.legacyUuid).filter((value): value is string => Boolean(value)),
  )) {
    add(findings, "DUPLICATE_LEGACY_UUID", "Duplicate user legacyUuid in Convex", {
      legacy: prefix(legacy),
    });
  }

  const convexUserId = (legacy: string) => userByLegacy.get(legacy)?.[0]?.convexId;
  const convexRoomId = (legacy: string) => roomByLegacy.get(legacy)?.[0]?.convexId;
  const convexPlayerId = (legacy: string) => playerByLegacy.get(legacy)?.[0]?.convexId;

  let orphans = 0;
  let wrongParent = 0;
  const noteOrphan = (kind: string, id: string) => {
    orphans += 1;
    add(findings, "ORPHAN_FK", `${kind} points at a missing Convex document`, {
      convex: prefix(id),
    });
  };
  const noteWrong = (kind: string, legacy: string) => {
    wrongParent += 1;
    add(findings, "WRONG_PARENT", `${kind} is attached to the wrong parent`, {
      legacy: prefix(legacy),
    });
  };

  for (const profile of plan.profiles) {
    const rows = profileByLegacy.get(profile.legacyUuid) ?? [];
    const expectedUser = convexUserId(profile.userLegacyUuid);
    if (rows.length !== 1 || !expectedUser) {
      add(findings, "COUNT_MISMATCH", "Migrated profile is missing or duplicated", {
        legacy: prefix(profile.legacyUuid),
      });
      continue;
    }
    if (!convexIds.has(rows[0]!.userId)) {
      noteOrphan("profile.userId", rows[0]!.userId);
    } else if (rows[0]!.userId !== expectedUser) {
      noteWrong("profile", profile.legacyUuid);
    }
  }

  let entitlementMatched = 0;
  for (const source of plan.entitlementSources) {
    const rows = sourceByLegacy.get(source.legacyUuid) ?? [];
    const expectedUser = convexUserId(source.userLegacyUuid);
    if (rows.length !== 1 || !expectedUser) {
      add(findings, "COUNT_MISMATCH", "Migrated entitlement source is missing or duplicated", {
        legacy: prefix(source.legacyUuid),
      });
      continue;
    }
    if (rows[0]!.userId !== expectedUser) {
      noteWrong("entitlement source", source.legacyUuid);
    }
  }
  const stripeLegacyByUser = new Map<string, number>();
  for (const source of snapshot.sources) {
    if (source.provider === "stripe" && source.providerRef === "legacy") {
      stripeLegacyByUser.set(source.userId, (stripeLegacyByUser.get(source.userId) ?? 0) + 1);
    }
  }
  for (const [userId, count] of stripeLegacyByUser) {
    if (count > 1) {
      add(findings, "DUPLICATE_STRIPE_LEGACY", "Stripe providerRef=legacy is duplicated for one user", {
        convex: prefix(userId),
      });
    }
  }
  for (const expected of plan.entitlementExpectations) {
    const userId = convexUserId(expected.userLegacyUuid);
    if (!userId) {
      continue;
    }
    const actual = snapshot.entitlements.filter((row) => row.userId === userId);
    if (actual.length !== 1 || actual[0]!.accessLevel !== expected.computedAccessLevel) {
      add(findings, "ENTITLEMENT_DIVERGENCE", "Effective entitlement diverges from LOT9/10 recompute", {
        legacy: prefix(expected.userLegacyUuid),
      });
      continue;
    }
    entitlementMatched += 1;
  }
  for (const source of plan.entitlementSources) {
    if (source.provider !== "google_play") {
      continue;
    }
    const user = userByLegacy.get(source.userLegacyUuid)?.[0];
    if (!user?.legacyUuid) {
      add(findings, "MISSING_PLAY_LEGACY_UUID", "Google Play user is missing legacyUuid for dual hash", {
        legacy: prefix(source.userLegacyUuid),
      });
    }
  }

  for (const room of plan.rooms) {
    const rows = roomByLegacy.get(room.legacyUuid) ?? [];
    const expectedHost = convexUserId(room.hostLegacyUuid);
    if (rows.length !== 1 || !expectedHost) {
      add(findings, "COUNT_MISMATCH", "Migrated room is missing or duplicated", {
        legacy: prefix(room.legacyUuid),
      });
      continue;
    }
    const actual = rows[0]!;
    if (actual.convexId === room.legacyUuid) {
      add(findings, "LEGACY_USED_AS_CONVEX_ID", "Room Convex _id equals a legacy UUID", {
        legacy: prefix(room.legacyUuid),
      });
    }
    if (!actual.hostUserId) {
      noteOrphan("room.hostUserId", "missing");
    } else if (!convexIds.has(actual.hostUserId)) {
      noteOrphan("room.hostUserId", actual.hostUserId);
    } else if (actual.hostUserId !== expectedHost) {
      noteWrong("room host", room.legacyUuid);
    }
    const customLive =
      (actual.status === "playing" || actual.status === "paused") && actual.scenarioId === "custom";
    if (customLive && !snapshot.gmRooms.includes(actual.convexId)) {
      add(findings, "INCOMPLETE_ROOM_GRAPH", "Playing/paused custom room is missing gm_state", {
        legacy: prefix(room.legacyUuid),
      });
    }
    if (
      (room.status === "playing" || room.status === "paused") &&
      actual.status !== "playing" &&
      actual.status !== "paused"
    ) {
      add(findings, "CONTINUABLE_MISSING", "Expected continuable room is not playing/paused in Convex", {
        legacy: prefix(room.legacyUuid),
      });
    }
  }
  for (const player of plan.players) {
    const rows = playerByLegacy.get(player.legacyUuid) ?? [];
    const expectedRoom = convexRoomId(player.roomLegacyUuid);
    const expectedUser = convexUserId(player.userLegacyUuid);
    if (rows.length !== 1 || !expectedRoom || !expectedUser) {
      add(findings, "COUNT_MISMATCH", "Migrated player is missing or duplicated", {
        legacy: prefix(player.legacyUuid),
      });
      continue;
    }
    const actual = rows[0]!;
    if (!convexIds.has(actual.roomId) || !convexIds.has(actual.userId)) {
      if (!convexIds.has(actual.roomId)) {
        noteOrphan("player.roomId", actual.roomId);
      }
      if (!convexIds.has(actual.userId)) {
        noteOrphan("player.userId", actual.userId);
      }
    } else if (actual.roomId !== expectedRoom || actual.userId !== expectedUser) {
      noteWrong("player", player.legacyUuid);
    }
  }
  for (const batch of plan.eventBatches) {
    for (const event of batch) {
      const rows = eventByLegacy.get(event.legacyUuid) ?? [];
      const expectedRoom = convexRoomId(event.roomLegacyUuid);
      if (rows.length !== 1 || !expectedRoom) {
        add(findings, "COUNT_MISMATCH", "Migrated event is missing or duplicated", {
          legacy: prefix(event.legacyUuid),
        });
        continue;
      }
      const actual = rows[0]!;
      if (!convexIds.has(actual.roomId)) {
        noteOrphan("event.roomId", actual.roomId);
      } else if (actual.roomId !== expectedRoom) {
        noteWrong("event room", event.legacyUuid);
      }
      if (event.playerLegacyUuid) {
        const expectedPlayer = convexPlayerId(event.playerLegacyUuid);
        if (!actual.playerId) {
          noteWrong("event player", event.legacyUuid);
        } else if (!convexIds.has(actual.playerId)) {
          noteOrphan("event.playerId", actual.playerId);
        } else if (actual.playerId !== expectedPlayer) {
          noteWrong("event player", event.legacyUuid);
        }
      }
    }
  }
  for (const enemy of plan.enemies) {
    const rows = enemyByLegacy.get(enemy.legacyUuid) ?? [];
    const expectedRoom = convexRoomId(enemy.roomLegacyUuid);
    if (rows.length !== 1 || !expectedRoom) {
      add(findings, "COUNT_MISMATCH", "Migrated enemy is missing or duplicated", {
        legacy: prefix(enemy.legacyUuid),
      });
      continue;
    }
    if (!convexIds.has(rows[0]!.roomId)) {
      noteOrphan("enemy.roomId", rows[0]!.roomId);
    } else if (rows[0]!.roomId !== expectedRoom) {
      noteWrong("enemy", enemy.legacyUuid);
    }
  }
  for (const combat of plan.combatSessions) {
    const rows = combatByLegacy.get(combat.legacyUuid) ?? [];
    const expectedRoom = convexRoomId(combat.roomLegacyUuid);
    if (rows.length !== 1 || !expectedRoom) {
      add(findings, "COUNT_MISMATCH", "Migrated combat is missing or duplicated", {
        legacy: prefix(combat.legacyUuid),
      });
      continue;
    }
    if (!convexIds.has(rows[0]!.roomId)) {
      noteOrphan("combat.roomId", rows[0]!.roomId);
    } else if (rows[0]!.roomId !== expectedRoom) {
      noteWrong("combat", combat.legacyUuid);
    }
  }
  for (const roll of plan.pendingRolls) {
    const rows = rollByLegacy.get(roll.legacyUuid) ?? [];
    const expectedRoom = convexRoomId(roll.roomLegacyUuid);
    const expectedPlayer = convexPlayerId(roll.playerLegacyUuid);
    if (rows.length !== 1 || !expectedRoom || !expectedPlayer) {
      add(findings, "COUNT_MISMATCH", "Migrated pending roll is missing or duplicated", {
        legacy: prefix(roll.legacyUuid),
      });
      continue;
    }
    if (!convexIds.has(rows[0]!.roomId) || !convexIds.has(rows[0]!.playerId)) {
      if (!convexIds.has(rows[0]!.roomId)) {
        noteOrphan("roll.roomId", rows[0]!.roomId);
      }
      if (!convexIds.has(rows[0]!.playerId)) {
        noteOrphan("roll.playerId", rows[0]!.playerId);
      }
    } else if (rows[0]!.roomId !== expectedRoom || rows[0]!.playerId !== expectedPlayer) {
      noteWrong("pending roll", roll.legacyUuid);
    }
  }
  for (const gm of plan.roomGmState) {
    const roomId = convexRoomId(gm.roomLegacyUuid);
    if (!roomId || !snapshot.gmRooms.includes(roomId)) {
      add(findings, "COUNT_MISMATCH", "Migrated gm_state is missing", {
        legacy: prefix(gm.roomLegacyUuid),
      });
    }
  }
  for (const demo of plan.demoSessions) {
    const rows = demoByLegacy.get(demo.legacyUuid) ?? [];
    const expectedUser = convexUserId(demo.userLegacyUuid);
    if (rows.length !== 1 || !expectedUser) {
      add(findings, "COUNT_MISMATCH", "Migrated demo session is missing or duplicated", {
        legacy: prefix(demo.legacyUuid),
      });
      continue;
    }
    if (rows[0]!.userId !== expectedUser) {
      noteWrong("demo user", demo.legacyUuid);
    }
    if (demo.roomLegacyUuid) {
      const expectedRoom = convexRoomId(demo.roomLegacyUuid);
      if (!rows[0]!.roomId || rows[0]!.roomId !== expectedRoom) {
        noteWrong("demo room", demo.legacyUuid);
      }
    }
  }

  for (const user of plan.users) {
    const actual = userByLegacy.get(user.legacyUuid)?.[0];
    if (actual && actual.convexId === user.legacyUuid) {
      add(findings, "LEGACY_USED_AS_CONVEX_ID", "User Convex _id equals a legacy UUID", {
        legacy: prefix(user.legacyUuid),
      });
    }
  }

  const anonymousUsersImported = snapshot.users.filter(
    (row) => row.legacyUuid && archived.users.has(row.legacyUuid),
  ).length;
  const anonymousRoomsImported = snapshot.rooms.filter(
    (row) => row.legacyUuid && archived.rooms.has(row.legacyUuid),
  ).length;
  if (anonymousUsersImported > 0) {
    add(findings, "ANONYMOUS_IMPORTED", "Anonymous archived users are present in Convex");
  }
  if (anonymousRoomsImported > 0) {
    add(findings, "ANONYMOUS_IMPORTED", "Anonymous archived rooms are present in Convex");
  }
  if (snapshot.players.some((row) => row.legacyUuid && archived.players.has(row.legacyUuid))) {
    add(findings, "ANONYMOUS_IMPORTED", "Anonymous archived players are present in Convex");
  }

  const counts = {
    users: { expected: plan.counts.users, actual: identityMatched },
    profiles: {
      expected: plan.counts.profiles,
      actual: plan.profiles.filter((row) => (profileByLegacy.get(row.legacyUuid) ?? []).length === 1)
        .length,
    },
    entitlement_sources: {
      expected: plan.counts.entitlement_sources,
      actual: plan.entitlementSources.filter(
        (row) => (sourceByLegacy.get(row.legacyUuid) ?? []).length === 1,
      ).length,
    },
    rooms: {
      expected: plan.counts.rooms,
      actual: plan.rooms.filter((row) => (roomByLegacy.get(row.legacyUuid) ?? []).length === 1)
        .length,
    },
    players: {
      expected: plan.counts.players,
      actual: plan.players.filter((row) => (playerByLegacy.get(row.legacyUuid) ?? []).length === 1)
        .length,
    },
    room_gm_state: {
      expected: plan.counts.room_gm_state,
      actual: plan.roomGmState.filter((row) => {
        const roomId = convexRoomId(row.roomLegacyUuid);
        return Boolean(roomId && snapshot.gmRooms.includes(roomId));
      }).length,
    },
    game_events: {
      expected: plan.counts.game_events,
      actual: plan.eventBatches
        .flat()
        .filter((row) => (eventByLegacy.get(row.legacyUuid) ?? []).length === 1).length,
    },
    enemies: {
      expected: plan.counts.enemies,
      actual: plan.enemies.filter((row) => (enemyByLegacy.get(row.legacyUuid) ?? []).length === 1)
        .length,
    },
    combat_sessions: {
      expected: plan.counts.combat_sessions,
      actual: plan.combatSessions.filter(
        (row) => (combatByLegacy.get(row.legacyUuid) ?? []).length === 1,
      ).length,
    },
    pending_rolls: {
      expected: plan.counts.pending_rolls,
      actual: plan.pendingRolls.filter((row) => (rollByLegacy.get(row.legacyUuid) ?? []).length === 1)
        .length,
    },
    demo_sessions: {
      expected: plan.counts.demo_sessions,
      actual: plan.demoSessions.filter((row) => (demoByLegacy.get(row.legacyUuid) ?? []).length === 1)
        .length,
    },
  };
  for (const [name, pair] of Object.entries(counts)) {
    if (pair.expected !== pair.actual) {
      add(findings, "COUNT_MISMATCH", `${name} count diverges from the migratable dataset`);
    }
  }

  const blocked = findings.some((item) => item.severity === "CRITICAL");
  return {
    verdict: blocked ? "B5_BLOCKED" : "B5_PASS",
    counts,
    identity: { expected: plan.counts.users, matched: identityMatched },
    relations: { orphans, wrong_parent: wrongParent },
    archives: {
      anonymous_users_imported: anonymousUsersImported,
      anonymous_rooms_imported: anonymousRoomsImported,
      ai_usage_imported: 0,
      ai_usage_native: snapshot.aiUsageCount,
    },
    entitlements: {
      expected: plan.entitlementExpectations.length,
      matched: entitlementMatched,
    },
    findings,
  };
}

export function formatB5Report(report: B5Report): string {
  const lines = [
    `LOT12 B5: ${report.verdict}`,
    "",
    "Counts:",
    ...Object.entries(report.counts).map(
      ([name, pair]) => `${name} ${pair.actual}/${pair.expected}`,
    ),
    "",
    "Identity:",
    `${report.identity.matched}/${report.identity.expected}`,
    "",
    "Relations:",
    `orphans: ${report.relations.orphans}`,
    `wrong_parent: ${report.relations.wrong_parent}`,
    "",
    "Archives:",
    `anonymous_users_imported: ${report.archives.anonymous_users_imported}`,
    `anonymous_rooms_imported: ${report.archives.anonymous_rooms_imported}`,
    `ai_usage_imported: ${report.archives.ai_usage_imported}`,
    `ai_usage_native: ${report.archives.ai_usage_native}`,
    "",
    "Entitlements:",
    `${report.entitlements.matched}/${report.entitlements.expected}`,
  ];
  if (report.findings.length > 0) {
    lines.push("", "findings:");
    for (const finding of report.findings) {
      lines.push(`  [${finding.severity}] ${finding.code}: ${finding.message}`);
    }
  }
  return `${lines.join("\n")}\n`;
}
