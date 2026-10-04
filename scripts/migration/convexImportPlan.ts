import { computeGlobalEntitlement } from "../../convex/lib/entitlements";
import {
  ABILITY_KEYS,
  ENEMY_STATUSES,
  GAME_EVENT_TYPES,
  NARRATIVE_MUSIC_MOODS,
  PENDING_ROLL_STATUSES,
  ROOM_LOCALES,
  ROOM_STATUSES,
} from "../../convex/lib/validators";
import { classifyAuthUsers, normalizeEmail } from "./classify";
import type {
  EntitlementSourceRow,
  Finding,
  MigrationBundle,
  RoomRow,
  WorkosMapping,
} from "./types";

export const EVENT_BATCH_SIZE = 50;
export const CONVEX_IMPORT_PLAN_VERSION = "lot12-b4";

export type ConvexImportVerdict = "CONVEX_IMPORT_READY" | "CONVEX_IMPORT_BLOCKED";

export type PlannedUser = {
  legacyUuid: string;
  workosSubject: string;
  email: string | null;
  createdAt: number;
};

export type PlannedProfile = {
  legacyUuid: string;
  userLegacyUuid: string;
  displayName: string;
  classId?: string;
  avatarFigurineId?: number;
  sheetConfirmed: boolean;
  createdAt: number;
  strength: number;
  dexterity: number;
  constitution: number;
  intelligence: number;
  wisdom: number;
  charisma: number;
};

export type PlannedSource = {
  legacyUuid: string;
  userLegacyUuid: string;
  provider: "stripe" | "google_play" | "manual";
  providerRef: string;
  status: string;
  currentPeriodEnd?: number;
  metadata: Record<string, unknown>;
  createdAt: number;
  updatedAt: number;
};

export type PlannedRoom = {
  legacyUuid: string;
  hostLegacyUuid: string;
  name: string;
  scenario?: string;
  scenarioId?: string;
  status: string;
  createdAt: number;
  joinCode: string;
  minPlayers: number;
  requiredClassIds: string[];
  scenarioPrompt: string;
  worldState: unknown;
  locale: string;
  startedAt?: number;
  finishedAt?: number;
  gamePhase?: string;
  ending: unknown;
  musicMood: string;
};

export type PlannedPlayer = {
  legacyUuid: string;
  roomLegacyUuid: string;
  userLegacyUuid: string;
  figurineId: number;
  figurineName: string;
  positionX: number;
  positionY: number;
  hp: number;
  inventory: unknown[];
  joinedAt: number;
  classId?: string;
  effects: unknown[];
  strength: number;
  dexterity: number;
  constitution: number;
  intelligence: number;
  wisdom: number;
  charisma: number;
};

export type PlannedEvent = {
  legacyUuid: string;
  roomLegacyUuid: string;
  playerLegacyUuid?: string;
  type: string;
  content: string;
  createdAt: number;
};

export type PlannedEnemy = {
  legacyUuid: string;
  roomLegacyUuid: string;
  name: string;
  enemyType: string;
  positionX: number;
  positionY: number;
  hp: number;
  maxHp: number;
  status: string;
  metadata: unknown;
};

export type PlannedCombat = {
  legacyUuid: string;
  roomLegacyUuid: string;
  active: boolean;
  round: number;
  startedAt?: number;
  endedAt?: number;
};

export type PlannedRoll = {
  legacyUuid: string;
  roomLegacyUuid: string;
  playerLegacyUuid: string;
  ability: string;
  dc: number;
  reason: string;
  status: string;
  result?: number;
  modifier?: number;
  total?: number;
  success?: boolean;
  createdAt: number;
  resolvedAt?: number;
};

export type PlannedGmState = {
  roomLegacyUuid: string;
  gmSecrets: unknown;
  gmState: unknown;
  updatedAt: number;
};

export type PlannedDemo = {
  legacyUuid: string;
  userLegacyUuid: string;
  roomLegacyUuid?: string;
  startedAt?: number;
  expiresAt?: number;
  completedAt?: number;
  pausedAt?: number;
  createdAt: number;
};

export type EntitlementExpectation = {
  userLegacyUuid: string;
  historicalAccessLevel: string | null;
  computedAccessLevel: "demo" | "full";
  computedSource: string;
};

export type ConvexImportPlan = {
  version: string;
  verdict: ConvexImportVerdict;
  findings: Finding[];
  counts: {
    users: number;
    profiles: number;
    entitlement_sources: number;
    rooms: number;
    players: number;
    room_gm_state: number;
    game_events: number;
    event_batches: number;
    enemies: number;
    combat_sessions: number;
    pending_rolls: number;
    demo_sessions: number;
    ai_usage_events: number;
    archived_rooms: number;
  };
  users: PlannedUser[];
  profiles: PlannedProfile[];
  entitlementSources: PlannedSource[];
  entitlementExpectations: EntitlementExpectation[];
  rooms: PlannedRoom[];
  players: PlannedPlayer[];
  roomGmState: PlannedGmState[];
  eventBatches: PlannedEvent[][];
  enemies: PlannedEnemy[];
  combatSessions: PlannedCombat[];
  pendingRolls: PlannedRoll[];
  demoSessions: PlannedDemo[];
};

function parseTime(value?: string | null): number | undefined {
  if (!value) {
    return undefined;
  }
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? undefined : parsed;
}

function requiredTime(value?: string | null, fallback = 0): number {
  return parseTime(value) ?? fallback;
}

function stat(value: number | undefined, fallback = 10): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function isCustomScenario(room: RoomRow): boolean {
  return String(room.scenario_id ?? "").trim() === "custom";
}

function strictLive(status: string): boolean {
  return status === "playing" || status === "paused";
}

function providerOf(
  source: EntitlementSourceRow,
): "stripe" | "google_play" | "manual" | null {
  const provider = String(source.provider ?? "")
    .trim()
    .toLowerCase();
  if (provider === "stripe" || provider === "google_play" || provider === "manual") {
    return provider;
  }
  return null;
}

export function buildConvexImportPlan(
  bundle: MigrationBundle,
  mapping: WorkosMapping,
): ConvexImportPlan {
  const findings: Finding[] = [];
  const classified = classifyAuthUsers({
    authUsers: bundle.auth_users,
    sources: bundle.entitlement_sources,
    entitlements: bundle.user_entitlements,
    rooms: bundle.rooms,
    players: bundle.players,
    demos: bundle.demo_sessions,
  });
  const migratableUsers = new Set(
    Object.entries(classified)
      .filter(([, category]) => category === "migratable_email")
      .map(([id]) => id),
  );
  const migratableRoomIds = new Set(
    bundle.rooms
      .filter((room) => classified[String(room.host_id ?? "")] === "migratable_email")
      .map((room) => room.id),
  );
  const archivedRoomCount = bundle.rooms.length - migratableRoomIds.size;

  if (mapping.verdict !== "WORKOS_MAP_PASS") {
    findings.push({
      severity: "CRITICAL",
      code: "WORKOS_MAP_NOT_PASS",
      message: "WorkOS mapping verdict is not PASS",
    });
  }

  const mappingByLegacy = new Map(
    mapping.entries.map((entry) => [entry.legacy_user_id, entry]),
  );
  const users: PlannedUser[] = [];
  for (const user of bundle.auth_users) {
    if (!migratableUsers.has(user.id)) {
      continue;
    }
    const mapped = mappingByLegacy.get(user.id);
    if (!mapped || mapped.status !== "EXISTING_WORKOS_USER" || !mapped.workos_user_id) {
      findings.push({
        severity: "CRITICAL",
        code: "WORKOS_MAPPING_MISSING",
        message: "Migratable user is missing a unique WorkOS mapping",
        refs: { legacy_user_id: user.id },
      });
      continue;
    }
    const email = normalizeEmail(user.email);
    if (email && mapped.email && email !== mapped.email) {
      findings.push({
        severity: "CRITICAL",
        code: "WORKOS_EMAIL_MISMATCH",
        message: "WorkOS mapping email does not match migratable user",
        refs: { legacy_user_id: user.id },
      });
      continue;
    }
    users.push({
      legacyUuid: user.id,
      workosSubject: mapped.workos_user_id,
      email,
      createdAt: requiredTime(user.created_at),
    });
  }

  const workosSubjects = new Map<string, string>();
  for (const user of users) {
    const previous = workosSubjects.get(user.workosSubject);
    if (previous && previous !== user.legacyUuid) {
      findings.push({
        severity: "CRITICAL",
        code: "WORKOS_USER_SHARED",
        message: "WorkOS user id is attached to multiple legacy users",
        refs: { legacy_user_id: user.legacyUuid },
      });
    }
    workosSubjects.set(user.workosSubject, user.legacyUuid);
  }

  const profiles: PlannedProfile[] = [];
  for (const row of bundle.profiles) {
    if (!migratableUsers.has(row.id)) {
      continue;
    }
    profiles.push({
      legacyUuid: row.id,
      userLegacyUuid: row.id,
      displayName: String(row.display_name ?? "").trim(),
      classId: row.class_id ?? undefined,
      avatarFigurineId: row.avatar_figurine_id ?? undefined,
      sheetConfirmed: row.sheet_confirmed === true,
      createdAt: requiredTime(row.created_at),
      strength: stat(row.strength),
      dexterity: stat(row.dexterity),
      constitution: stat(row.constitution),
      intelligence: stat(row.intelligence),
      wisdom: stat(row.wisdom),
      charisma: stat(row.charisma),
    });
  }

  const entitlementSources: PlannedSource[] = [];
  const sourcesByUser = new Map<string, PlannedSource[]>();
  for (const row of bundle.entitlement_sources) {
    if (!migratableUsers.has(row.user_id)) {
      continue;
    }
    const provider = providerOf(row);
    if (!provider) {
      findings.push({
        severity: "CRITICAL",
        code: "UNKNOWN_ENTITLEMENT_PROVIDER",
        message: "Entitlement source provider is not importable",
        refs: { source_id: row.id },
      });
      continue;
    }
    const planned: PlannedSource = {
      legacyUuid: row.id,
      userLegacyUuid: row.user_id,
      provider,
      providerRef: String(row.provider_ref ?? "").trim() || "legacy",
      status: String(row.status ?? "").trim() || "pending",
      currentPeriodEnd: parseTime(row.current_period_end),
      metadata:
        row.metadata && typeof row.metadata === "object" && !Array.isArray(row.metadata)
          ? row.metadata
          : {},
      createdAt: requiredTime(row.created_at),
      updatedAt: requiredTime(row.updated_at, requiredTime(row.created_at)),
    };
    entitlementSources.push(planned);
    const list = sourcesByUser.get(row.user_id) ?? [];
    list.push(planned);
    sourcesByUser.set(row.user_id, list);
  }

  const entitlementExpectations: EntitlementExpectation[] = [];
  const historicalByUser = new Map(
    bundle.user_entitlements
      .filter((row) => migratableUsers.has(row.user_id))
      .map((row) => [row.user_id, row]),
  );
  for (const user of users) {
    const computed = computeGlobalEntitlement({
      sources: (sourcesByUser.get(user.legacyUuid) ?? []).map((row) => ({
        provider: row.provider,
        status: row.status,
        currentPeriodEnd: row.currentPeriodEnd,
      })),
    });
    const historical = historicalByUser.get(user.legacyUuid);
    const historicalAccessLevel = historical
      ? String(historical.access_level ?? "")
          .trim()
          .toLowerCase()
      : null;
    if (historicalAccessLevel && historicalAccessLevel !== computed.accessLevel) {
      findings.push({
        severity: "CRITICAL",
        code: "ENTITLEMENT_RECOMPUTE_MISMATCH",
        message: "Recomputed entitlement diverges from historical cache",
        refs: { legacy_user_id: user.legacyUuid },
      });
    }
    entitlementExpectations.push({
      userLegacyUuid: user.legacyUuid,
      historicalAccessLevel,
      computedAccessLevel: computed.accessLevel,
      computedSource: computed.source,
    });
  }

  const gmByRoom = new Set(bundle.room_gm_state.map((row) => row.room_id));
  const rooms: PlannedRoom[] = [];
  const joinCodes = new Map<string, string[]>();
  for (const room of bundle.rooms) {
    if (!migratableRoomIds.has(room.id)) {
      continue;
    }
    const status = String(room.status ?? "").trim();
    const hostLegacyUuid = String(room.host_id ?? "").trim();
    if (!(ROOM_STATUSES as readonly string[]).includes(status)) {
      findings.push({
        severity: "CRITICAL",
        code: "INVALID_ROOM_STATUS",
        message: "Room status is not a Convex room status",
        refs: { room_id: room.id },
      });
      continue;
    }
    const locale = String(room.locale ?? "en").trim() || "en";
    const musicMood = String(room.music_mood ?? "exploration").trim() || "exploration";
    if (!(ROOM_LOCALES as readonly string[]).includes(locale)) {
      findings.push({
        severity: "CRITICAL",
        code: "INVALID_ROOM_LOCALE",
        message: "Room locale is not importable",
        refs: { room_id: room.id },
      });
      continue;
    }
    if (!(NARRATIVE_MUSIC_MOODS as readonly string[]).includes(musicMood)) {
      findings.push({
        severity: "CRITICAL",
        code: "INVALID_ROOM_MUSIC_MOOD",
        message: "Room music mood is not importable",
        refs: { room_id: room.id },
      });
      continue;
    }
    if (!migratableUsers.has(hostLegacyUuid)) {
      findings.push({
        severity: "CRITICAL",
        code: "MIGRATABLE_ROOM_HOST",
        message: "Migratable room host is not a mapped user",
        refs: { room_id: room.id },
      });
      continue;
    }
    if (strictLive(status) && isCustomScenario(room) && !gmByRoom.has(room.id)) {
      findings.push({
        severity: "CRITICAL",
        code: "INCOMPLETE_ROOM_GRAPH",
        message: "Playing/paused custom room is missing room_gm_state",
        refs: { room_id: room.id },
      });
      continue;
    }
    const joinCode = String(room.join_code ?? "").trim();
    if (!joinCode) {
      findings.push({
        severity: "CRITICAL",
        code: "MISSING_JOIN_CODE",
        message: "Migratable room is missing join_code",
        refs: { room_id: room.id },
      });
      continue;
    }
    const list = joinCodes.get(joinCode) ?? [];
    list.push(room.id);
    joinCodes.set(joinCode, list);
    rooms.push({
      legacyUuid: room.id,
      hostLegacyUuid,
      name: String(room.name ?? "").trim(),
      scenario: room.scenario ?? undefined,
      scenarioId: room.scenario_id ?? undefined,
      status,
      createdAt: requiredTime(room.created_at),
      joinCode,
      minPlayers: room.min_players ?? 1,
      requiredClassIds: room.required_class_ids ?? [],
      scenarioPrompt: room.scenario_prompt ?? "",
      worldState: room.world_state ?? {},
      locale,
      startedAt: parseTime(room.started_at),
      finishedAt: parseTime(room.finished_at),
      gamePhase: room.game_phase ?? undefined,
      ending: room.ending ?? {},
      musicMood,
    });
  }
  for (const [code, ids] of joinCodes) {
    if (ids.length > 1) {
      findings.push({
        severity: "CRITICAL",
        code: "JOIN_CODE_COLLISION",
        message: "join_code is used by multiple migratable rooms",
        refs: { join_code: code },
      });
    }
  }

  const importedRoomIds = new Set(rooms.map((row) => row.legacyUuid));
  const players: PlannedPlayer[] = [];
  for (const row of bundle.players) {
    if (!importedRoomIds.has(row.room_id)) {
      continue;
    }
    if (!migratableUsers.has(row.user_id)) {
      continue;
    }
    players.push({
      legacyUuid: row.id,
      roomLegacyUuid: row.room_id,
      userLegacyUuid: row.user_id,
      figurineId: row.figurine_id,
      figurineName: row.figurine_name,
      positionX: row.position_x ?? 0.5,
      positionY: row.position_y ?? 0.5,
      hp: row.hp ?? 100,
      inventory: Array.isArray(row.inventory) ? row.inventory : [],
      joinedAt: requiredTime(row.joined_at),
      classId: row.class_id ?? undefined,
      effects: Array.isArray(row.effects) ? row.effects : [],
      strength: stat(row.strength),
      dexterity: stat(row.dexterity),
      constitution: stat(row.constitution),
      intelligence: stat(row.intelligence),
      wisdom: stat(row.wisdom),
      charisma: stat(row.charisma),
    });
  }
  const importedPlayerIds = new Set(players.map((row) => row.legacyUuid));

  const roomGmState: PlannedGmState[] = [];
  for (const row of bundle.room_gm_state) {
    if (!importedRoomIds.has(row.room_id)) {
      continue;
    }
    roomGmState.push({
      roomLegacyUuid: row.room_id,
      gmSecrets: row.gm_secrets ?? [],
      gmState: row.gm_state ?? {},
      updatedAt: requiredTime(row.updated_at),
    });
  }

  const events: PlannedEvent[] = [];
  for (const row of bundle.game_events) {
    if (!importedRoomIds.has(row.room_id)) {
      continue;
    }
    const type = String(row.type ?? "").trim();
    if (!(GAME_EVENT_TYPES as readonly string[]).includes(type)) {
      findings.push({
        severity: "CRITICAL",
        code: "INVALID_GAME_EVENT_TYPE",
        message: "Game event type is not importable",
        refs: { event_id: row.id },
      });
      continue;
    }
    events.push({
      legacyUuid: row.id,
      roomLegacyUuid: row.room_id,
      playerLegacyUuid:
        row.player_id && importedPlayerIds.has(row.player_id) ? row.player_id : undefined,
      type,
      content: row.content,
      createdAt: requiredTime(row.created_at),
    });
  }
  const eventBatches: PlannedEvent[][] = [];
  for (let index = 0; index < events.length; index += EVENT_BATCH_SIZE) {
    eventBatches.push(events.slice(index, index + EVENT_BATCH_SIZE));
  }

  const enemies: PlannedEnemy[] = [];
  for (const row of bundle.enemies) {
    if (!importedRoomIds.has(row.room_id)) {
      continue;
    }
    const status = String(row.status ?? "active").trim() || "active";
    if (!(ENEMY_STATUSES as readonly string[]).includes(status)) {
      findings.push({
        severity: "CRITICAL",
        code: "INVALID_ENEMY_STATUS",
        message: "Enemy status is not importable",
        refs: { enemy_id: row.id },
      });
      continue;
    }
    enemies.push({
      legacyUuid: row.id,
      roomLegacyUuid: row.room_id,
      name: row.name,
      enemyType: row.enemy_type,
      positionX: row.position_x ?? 0.5,
      positionY: row.position_y ?? 0.5,
      hp: row.hp ?? 0,
      maxHp: row.max_hp ?? row.hp ?? 0,
      status,
      metadata: row.metadata ?? {},
    });
  }

  const combatSessions: PlannedCombat[] = [];
  for (const row of bundle.combat_sessions) {
    if (!importedRoomIds.has(row.room_id)) {
      continue;
    }
    combatSessions.push({
      legacyUuid: row.id,
      roomLegacyUuid: row.room_id,
      active: row.active === true,
      round: row.round ?? 1,
      startedAt: parseTime(row.started_at),
      endedAt: parseTime(row.ended_at),
    });
  }

  const pendingRolls: PlannedRoll[] = [];
  for (const row of bundle.pending_rolls) {
    if (!importedRoomIds.has(row.room_id) || !importedPlayerIds.has(row.player_id)) {
      continue;
    }
    const ability = String(row.ability ?? "").trim();
    const status = String(row.status ?? "").trim();
    if (!(ABILITY_KEYS as readonly string[]).includes(ability)) {
      findings.push({
        severity: "CRITICAL",
        code: "INVALID_ROLL_ABILITY",
        message: "Pending roll ability is not importable",
        refs: { roll_id: row.id },
      });
      continue;
    }
    if (!(PENDING_ROLL_STATUSES as readonly string[]).includes(status)) {
      findings.push({
        severity: "CRITICAL",
        code: "INVALID_ROLL_STATUS",
        message: "Pending roll status is not importable",
        refs: { roll_id: row.id },
      });
      continue;
    }
    pendingRolls.push({
      legacyUuid: row.id,
      roomLegacyUuid: row.room_id,
      playerLegacyUuid: row.player_id,
      ability,
      dc: row.dc,
      reason: row.reason ?? "",
      status,
      result: row.result ?? undefined,
      modifier: row.modifier ?? undefined,
      total: row.total ?? undefined,
      success: row.success ?? undefined,
      createdAt: requiredTime(row.created_at),
      resolvedAt: parseTime(row.resolved_at),
    });
  }

  const demoSessions: PlannedDemo[] = [];
  for (const row of bundle.demo_sessions) {
    if (!migratableUsers.has(row.user_id)) {
      continue;
    }
    if (row.room_id && !importedRoomIds.has(row.room_id)) {
      continue;
    }
    demoSessions.push({
      legacyUuid: row.id,
      userLegacyUuid: row.user_id,
      roomLegacyUuid: row.room_id ?? undefined,
      startedAt: parseTime(row.started_at),
      expiresAt: parseTime(row.expires_at),
      completedAt: parseTime(row.completed_at),
      pausedAt: parseTime(row.paused_at),
      createdAt: requiredTime(row.created_at, requiredTime(row.started_at)),
    });
  }

  const blocked = findings.some((item) => item.severity === "CRITICAL");
  return {
    version: CONVEX_IMPORT_PLAN_VERSION,
    verdict: blocked ? "CONVEX_IMPORT_BLOCKED" : "CONVEX_IMPORT_READY",
    findings,
    counts: {
      users: users.length,
      profiles: profiles.length,
      entitlement_sources: entitlementSources.length,
      rooms: rooms.length,
      players: players.length,
      room_gm_state: roomGmState.length,
      game_events: events.length,
      event_batches: eventBatches.length,
      enemies: enemies.length,
      combat_sessions: combatSessions.length,
      pending_rolls: pendingRolls.length,
      demo_sessions: demoSessions.length,
      ai_usage_events: 0,
      archived_rooms: archivedRoomCount,
    },
    users,
    profiles,
    entitlementSources,
    entitlementExpectations,
    rooms,
    players,
    roomGmState,
    eventBatches,
    enemies,
    combatSessions,
    pendingRolls,
    demoSessions,
  };
}

export function formatConvexImportPlan(plan: ConvexImportPlan): string {
  const lines = [
    `Convex import plan: ${plan.verdict}`,
    `users: ${plan.counts.users}`,
    `profiles: ${plan.counts.profiles}`,
    `entitlement_sources: ${plan.counts.entitlement_sources}`,
    `rooms: ${plan.counts.rooms}`,
    `players: ${plan.counts.players}`,
    `room_gm_state: ${plan.counts.room_gm_state}`,
    `game_events: ${plan.counts.game_events}`,
    `event_batches: ${plan.counts.event_batches} (size ${EVENT_BATCH_SIZE})`,
    `enemies: ${plan.counts.enemies}`,
    `combat_sessions: ${plan.counts.combat_sessions}`,
    `pending_rolls: ${plan.counts.pending_rolls}`,
    `demo_sessions: ${plan.counts.demo_sessions}`,
    `ai_usage_events: ${plan.counts.ai_usage_events} (archive only, not imported)`,
    `archived_rooms_excluded: ${plan.counts.archived_rooms}`,
  ];
  if (plan.findings.length > 0) {
    lines.push("findings:");
    for (const finding of plan.findings) {
      lines.push(`  [${finding.severity}] ${finding.code}: ${finding.message}`);
    }
  }
  return `${lines.join("\n")}\n`;
}
