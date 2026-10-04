import {
  classifyAuthUsers,
  entitlementCacheIsFull,
  isPaidPurchaseSource,
  playObfuscatedAccountId,
  sourceGrantsFull,
} from "./classify";
import { assertNoForbiddenPayload } from "./sanitize";
import type {
  DatasetCounts,
  DryRunReport,
  Finding,
  MigrationBundle,
  RoomRow,
  UserCategory,
} from "./types";

const LIVE_STATUSES = new Set(["waiting", "playing", "paused"]);
const STRICT_LIVE = new Set(["playing", "paused"]);

function emptyCounts(): Record<UserCategory, number> {
  return {
    migratable_email: 0,
    ignored_anonymous: 0,
    pending_identity_link: 0,
    ambiguous_identity: 0,
    orphan: 0,
  };
}

function emptyDatasetCounts(): DatasetCounts {
  return {
    auth_users: 0,
    profiles: 0,
    entitlement_sources: 0,
    user_entitlements: 0,
    rooms: 0,
    players: 0,
    room_gm_state: 0,
    game_events: 0,
    enemies: 0,
    combat_sessions: 0,
    pending_rolls: 0,
    demo_sessions: 0,
    ai_usage_events: 0,
  };
}

function subtractCounts(source: DatasetCounts, migratable: DatasetCounts): DatasetCounts {
  return {
    auth_users: source.auth_users - migratable.auth_users,
    profiles: source.profiles - migratable.profiles,
    entitlement_sources: source.entitlement_sources - migratable.entitlement_sources,
    user_entitlements: source.user_entitlements - migratable.user_entitlements,
    rooms: source.rooms - migratable.rooms,
    players: source.players - migratable.players,
    room_gm_state: source.room_gm_state - migratable.room_gm_state,
    game_events: source.game_events - migratable.game_events,
    enemies: source.enemies - migratable.enemies,
    combat_sessions: source.combat_sessions - migratable.combat_sessions,
    pending_rolls: source.pending_rolls - migratable.pending_rolls,
    demo_sessions: source.demo_sessions - migratable.demo_sessions,
    ai_usage_events: source.ai_usage_events - migratable.ai_usage_events,
  };
}

function hostCategory(
  room: RoomRow,
  classified: Record<string, UserCategory>,
): UserCategory | null {
  const hostId = String(room.host_id ?? "").trim();
  if (!hostId) {
    return null;
  }
  return classified[hostId] ?? null;
}

function isIgnoredAnonymousHost(
  room: RoomRow,
  classified: Record<string, UserCategory>,
): boolean {
  return hostCategory(room, classified) === "ignored_anonymous";
}

function isCustomScenario(room: RoomRow): boolean {
  return String(room.scenario_id ?? "").trim() === "custom";
}

function isDemoScenario(room: RoomRow): boolean {
  return String(room.scenario_id ?? "").trim() === "demo";
}

export function runDryRun(bundle: MigrationBundle): DryRunReport {
  const findings: Finding[] = [];
  const leaks = assertNoForbiddenPayload(bundle);
  for (const path of leaks) {
    findings.push({
      severity: "CRITICAL",
      code: "SECRET_LEAK",
      message: `Forbidden field present in export at ${path}`,
    });
  }

  const authIds = new Set(bundle.auth_users.map((row) => row.id));
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
  const integrityRoomIds = new Set(
    bundle.rooms
      .filter((room) => !isIgnoredAnonymousHost(room, classified))
      .map((room) => room.id),
  );
  const migratableRoomIds = new Set(
    bundle.rooms
      .filter((room) => hostCategory(room, classified) === "migratable_email")
      .map((room) => room.id),
  );
  const integrityPlayerIds = new Set(
    bundle.players
      .filter((player) => integrityRoomIds.has(player.room_id))
      .map((player) => player.id),
  );

  const referencedUsers = new Set<string>();
  const addRef = (id: string | null | undefined) => {
    const value = String(id ?? "").trim();
    if (value) {
      referencedUsers.add(value);
    }
  };
  for (const row of bundle.profiles) {
    if (migratableUsers.has(row.id) || classified[row.id] === "ambiguous_identity") {
      addRef(row.id);
    }
  }
  for (const row of bundle.entitlement_sources) {
    addRef(row.user_id);
  }
  for (const row of bundle.user_entitlements) {
    if (migratableUsers.has(row.user_id) || classified[row.user_id] === "ambiguous_identity") {
      addRef(row.user_id);
    }
  }
  for (const row of bundle.rooms) {
    if (!isIgnoredAnonymousHost(row, classified)) {
      addRef(row.host_id);
    }
  }
  for (const row of bundle.players) {
    if (integrityRoomIds.has(row.room_id) && migratableUsers.has(row.user_id)) {
      addRef(row.user_id);
    }
  }
  for (const row of bundle.demo_sessions) {
    if (migratableUsers.has(row.user_id)) {
      addRef(row.user_id);
    }
  }
  for (const row of bundle.ai_usage_events) {
    if (row.user_id && migratableUsers.has(row.user_id)) {
      addRef(row.user_id);
    }
  }

  const orphans: string[] = [];
  for (const id of referencedUsers) {
    if (!authIds.has(id)) {
      orphans.push(id);
      classified[id] = "orphan";
      findings.push({
        severity: "CRITICAL",
        code: "ORPHAN_USER",
        message: "Referenced user is missing from sanitized auth export",
        refs: { user_id: id },
      });
    }
  }

  const category_counts = emptyCounts();
  for (const category of Object.values(classified)) {
    category_counts[category] += 1;
  }

  const pending_identity_link = Object.entries(classified)
    .filter(([, category]) => category === "pending_identity_link")
    .map(([id]) => id)
    .sort();
  const ambiguous_identity = Object.entries(classified)
    .filter(([, category]) => category === "ambiguous_identity")
    .map(([id]) => id)
    .sort();

  for (const id of ambiguous_identity) {
    findings.push({
      severity: "CRITICAL",
      code: "DUPLICATE_EMAIL",
      message: "Email identity is ambiguous and will not be auto-merged",
      refs: { user_id: id },
    });
  }

  const profileIds = new Set(bundle.profiles.map((row) => row.id));
  const sourceRoomIds = new Set(bundle.rooms.map((row) => row.id));
  const gmByRoom = new Set(bundle.room_gm_state.map((row) => row.room_id));

  for (const player of bundle.players) {
    if (!sourceRoomIds.has(player.room_id)) {
      findings.push({
        severity: "CRITICAL",
        code: "ORPHAN_FK",
        message: "Player references missing room",
        refs: { player_id: player.id, room_id: player.room_id },
      });
    }
  }
  for (const event of bundle.game_events) {
    if (!sourceRoomIds.has(event.room_id)) {
      findings.push({
        severity: "CRITICAL",
        code: "ORPHAN_FK",
        message: "Event references missing room",
        refs: { event_id: event.id, room_id: event.room_id },
      });
      continue;
    }
    if (!integrityRoomIds.has(event.room_id)) {
      continue;
    }
    if (event.player_id && !integrityPlayerIds.has(event.player_id)) {
      findings.push({
        severity: "CRITICAL",
        code: "ORPHAN_FK",
        message: "Event references missing player",
        refs: { event_id: event.id, player_id: event.player_id },
      });
    }
  }
  for (const enemy of bundle.enemies) {
    if (!sourceRoomIds.has(enemy.room_id)) {
      findings.push({
        severity: "CRITICAL",
        code: "ORPHAN_FK",
        message: "Enemy references missing room",
        refs: { enemy_id: enemy.id, room_id: enemy.room_id },
      });
    }
  }
  for (const combat of bundle.combat_sessions) {
    if (!sourceRoomIds.has(combat.room_id)) {
      findings.push({
        severity: "CRITICAL",
        code: "ORPHAN_FK",
        message: "Combat references missing room",
        refs: { combat_id: combat.id, room_id: combat.room_id },
      });
    }
  }
  for (const roll of bundle.pending_rolls) {
    if (!sourceRoomIds.has(roll.room_id)) {
      findings.push({
        severity: "CRITICAL",
        code: "ORPHAN_FK",
        message: "Pending roll references missing room",
        refs: { roll_id: roll.id, room_id: roll.room_id },
      });
      continue;
    }
    if (!integrityRoomIds.has(roll.room_id)) {
      continue;
    }
    if (!integrityPlayerIds.has(roll.player_id)) {
      findings.push({
        severity: "CRITICAL",
        code: "ORPHAN_FK",
        message: "Pending roll references missing player",
        refs: { roll_id: roll.id, player_id: roll.player_id },
      });
    }
  }
  for (const gm of bundle.room_gm_state) {
    if (!sourceRoomIds.has(gm.room_id)) {
      findings.push({
        severity: "CRITICAL",
        code: "ORPHAN_FK",
        message: "GM state references missing room",
        refs: { room_id: gm.room_id },
      });
    }
  }

  const joinCodes = new Map<string, string[]>();
  const combatsByRoom = new Map<string, string[]>();
  const pendingByPlayer = new Map<string, string[]>();
  const room_status_counts: Record<string, number> = {};
  let archivedRoomCount = 0;

  for (const room of bundle.rooms) {
    const status = String(room.status ?? "").trim();
    room_status_counts[status] = (room_status_counts[status] ?? 0) + 1;
    const archived = isIgnoredAnonymousHost(room, classified);
    if (archived) {
      archivedRoomCount += 1;
    }
    const code = String(room.join_code ?? "").trim();
    if (code && !archived) {
      const list = joinCodes.get(code) ?? [];
      list.push(room.id);
      joinCodes.set(code, list);
    }
    const live = LIVE_STATUSES.has(status);
    const strict = STRICT_LIVE.has(status);
    if (
      !archived &&
      room.host_id &&
      !authIds.has(room.host_id) &&
      !profileIds.has(room.host_id)
    ) {
      findings.push({
        severity: live ? "CRITICAL" : "IMPORTANT",
        code: "MISSING_HOST",
        message: "Room host is not in auth export",
        refs: { room_id: room.id, host_id: room.host_id },
      });
    }
    if (strict && !gmByRoom.has(room.id)) {
      if (archived && isDemoScenario(room)) {
        continue;
      }
      if (!archived || isCustomScenario(room)) {
        findings.push({
          severity: "CRITICAL",
          code: "INCOMPLETE_ROOM_GRAPH",
          message: "Playing/paused room is missing room_gm_state",
          refs: { room_id: room.id },
        });
      }
    } else if (!archived && status === "waiting" && !gmByRoom.has(room.id)) {
      findings.push({
        severity: "INFO",
        code: "WAITING_WITHOUT_GM_STATE",
        message: "Waiting room has no GM state yet",
        refs: { room_id: room.id },
      });
    }
  }
  if (archivedRoomCount > 0) {
    findings.push({
      severity: "INFO",
      code: "ANONYMOUS_DATA_ARCHIVED",
      message:
        "Anonymous test/demo data is archived and will not be imported",
    });
  }
  for (const [code, ids] of joinCodes) {
    if (ids.length > 1) {
      findings.push({
        severity: "CRITICAL",
        code: "JOIN_CODE_COLLISION",
        message: `join_code ${code} is used by multiple rooms`,
        refs: { join_code: code },
      });
    }
  }

  for (const combat of bundle.combat_sessions) {
    if (!integrityRoomIds.has(combat.room_id)) {
      continue;
    }
    const list = combatsByRoom.get(combat.room_id) ?? [];
    list.push(combat.id);
    combatsByRoom.set(combat.room_id, list);
  }
  for (const [roomId, ids] of combatsByRoom) {
    if (ids.length > 1) {
      findings.push({
        severity: "CRITICAL",
        code: "MULTIPLE_COMBATS",
        message: "Room has more than one combat session",
        refs: { room_id: roomId },
      });
    }
  }

  for (const roll of bundle.pending_rolls) {
    if (!integrityRoomIds.has(roll.room_id)) {
      continue;
    }
    if (String(roll.status ?? "").trim() !== "pending") {
      continue;
    }
    const list = pendingByPlayer.get(roll.player_id) ?? [];
    list.push(roll.id);
    pendingByPlayer.set(roll.player_id, list);
  }
  for (const [playerId, ids] of pendingByPlayer) {
    if (ids.length > 1) {
      findings.push({
        severity: "CRITICAL",
        code: "MULTIPLE_OPEN_ROLLS",
        message: "Player has more than one open pending roll",
        refs: { player_id: playerId },
      });
    }
  }

  const playRefs = new Map<string, string[]>();
  const stripeCs = new Map<string, string[]>();
  const stripeLegacyUsers = new Set<string>();

  for (const source of bundle.entitlement_sources) {
    const provider = String(source.provider ?? "").trim();
    const ref = String(source.provider_ref ?? "").trim() || "legacy";
    if (!source.user_id) {
      findings.push({
        severity: "CRITICAL",
        code: "PURCHASE_WITHOUT_USER",
        message: "Entitlement source has no user_id",
        refs: { source_id: source.id },
      });
      continue;
    }
    if (classified[source.user_id] === "ignored_anonymous" && isPaidPurchaseSource(source)) {
      findings.push({
        severity: "CRITICAL",
        code: "ANONYMOUS_PAID_SOURCE",
        message: "Paid entitlement source is attached to an anonymous user",
        refs: { source_id: source.id, user_id: source.user_id },
      });
    }
    if (provider === "google_play") {
      const list = playRefs.get(ref) ?? [];
      list.push(source.user_id);
      playRefs.set(ref, list);
      const meta =
        source.metadata && typeof source.metadata === "object"
          ? source.metadata
          : {};
      const actual = String(meta.play_account_id ?? "").trim();
      const expected = playObfuscatedAccountId(source.user_id);
      if (actual && expected && actual !== expected) {
        findings.push({
          severity: "CRITICAL",
          code: "PLAY_ACCOUNT_MISMATCH",
          message: "play_account_id does not match legacy user hash",
          refs: { source_id: source.id, user_id: source.user_id },
        });
      }
    }
    if (provider === "stripe") {
      if (ref === "legacy") {
        stripeLegacyUsers.add(source.user_id);
      } else if (ref.startsWith("cs_")) {
        const list = stripeCs.get(ref) ?? [];
        list.push(source.user_id);
        stripeCs.set(ref, list);
      }
    }
  }

  for (const [ref, users] of playRefs) {
    const unique = [...new Set(users)];
    if (unique.length > 1) {
      findings.push({
        severity: "CRITICAL",
        code: "PLAY_REF_SHARED",
        message: "Google Play providerRef is attached to multiple users",
        refs: { provider_ref: ref },
      });
    }
  }
  for (const [ref, users] of stripeCs) {
    const unique = [...new Set(users)];
    if (unique.length > 1) {
      findings.push({
        severity: "CRITICAL",
        code: "STRIPE_CS_SHARED",
        message: "Stripe checkout session is attached to multiple users",
        refs: { provider_ref: ref },
      });
    }
  }
  if (stripeLegacyUsers.size > 1) {
    findings.push({
      severity: "INFO",
      code: "STRIPE_LEGACY_NON_GLOBAL_REF",
      message:
        "Stripe providerRef=legacy is shared across users; kept as per-user local ref",
    });
  }

  const unresolved_entitlements: string[] = [];
  const fullByUser = new Map<string, boolean>();
  for (const source of bundle.entitlement_sources) {
    if (!sourceGrantsFull(source)) {
      continue;
    }
    fullByUser.set(source.user_id, true);
  }
  for (const row of bundle.user_entitlements) {
    if (!entitlementCacheIsFull(row)) {
      continue;
    }
    if (classified[row.user_id] === "ignored_anonymous") {
      continue;
    }
    if (!fullByUser.get(row.user_id)) {
      unresolved_entitlements.push(row.user_id);
      findings.push({
        severity: "IMPORTANT",
        code: "UNRESOLVED_ENTITLEMENT",
        message: "user_entitlements is full without an active granting source",
        refs: { user_id: row.user_id },
      });
    }
  }

  for (const demo of bundle.demo_sessions) {
    if (!demo.user_id) {
      findings.push({
        severity: "IMPORTANT",
        code: "DEMO_INCOMPLETE",
        message: "Demo session is missing user_id",
        refs: { demo_id: demo.id },
      });
    }
  }

  const source_counts: DatasetCounts = {
    auth_users: bundle.auth_users.length,
    profiles: bundle.profiles.length,
    entitlement_sources: bundle.entitlement_sources.length,
    user_entitlements: bundle.user_entitlements.length,
    rooms: bundle.rooms.length,
    players: bundle.players.length,
    room_gm_state: bundle.room_gm_state.length,
    game_events: bundle.game_events.length,
    enemies: bundle.enemies.length,
    combat_sessions: bundle.combat_sessions.length,
    pending_rolls: bundle.pending_rolls.length,
    demo_sessions: bundle.demo_sessions.length,
    ai_usage_events: bundle.ai_usage_events.length,
  };
  const migratable_counts: DatasetCounts = {
    ...emptyDatasetCounts(),
    auth_users: bundle.auth_users.filter((row) => migratableUsers.has(row.id)).length,
    profiles: bundle.profiles.filter((row) => migratableUsers.has(row.id)).length,
    entitlement_sources: bundle.entitlement_sources.filter((row) =>
      migratableUsers.has(row.user_id),
    ).length,
    user_entitlements: bundle.user_entitlements.filter((row) =>
      migratableUsers.has(row.user_id),
    ).length,
    rooms: bundle.rooms.filter((row) => migratableRoomIds.has(row.id)).length,
    players: bundle.players.filter((row) => migratableRoomIds.has(row.room_id)).length,
    room_gm_state: bundle.room_gm_state.filter((row) =>
      migratableRoomIds.has(row.room_id),
    ).length,
    game_events: bundle.game_events.filter((row) =>
      migratableRoomIds.has(row.room_id),
    ).length,
    enemies: bundle.enemies.filter((row) => migratableRoomIds.has(row.room_id)).length,
    combat_sessions: bundle.combat_sessions.filter((row) =>
      migratableRoomIds.has(row.room_id),
    ).length,
    pending_rolls: bundle.pending_rolls.filter((row) =>
      migratableRoomIds.has(row.room_id),
    ).length,
    demo_sessions: bundle.demo_sessions.filter((row) =>
      migratableUsers.has(row.user_id),
    ).length,
    ai_usage_events: bundle.ai_usage_events.filter(
      (row) =>
        (row.user_id && migratableUsers.has(row.user_id)) ||
        (row.room_id && migratableRoomIds.has(row.room_id)),
    ).length,
  };
  const archived_counts = subtractCounts(source_counts, migratable_counts);

  const blocked = findings.some((item) => item.severity === "CRITICAL");
  return {
    verdict: blocked ? "DRY_RUN_BLOCKED" : "DRY_RUN_PASS",
    table_counts: source_counts,
    source_counts,
    migratable_counts,
    archived_counts,
    category_counts,
    classified_users: classified,
    pending_identity_link,
    ambiguous_identity,
    orphans: orphans.sort(),
    unresolved_entitlements: [...new Set(unresolved_entitlements)].sort(),
    findings,
    room_status_counts,
  };
}
