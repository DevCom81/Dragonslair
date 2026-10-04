export const EXPORT_VERSION = "lot12-b1";

export const AUTH_EXPORT_ALLOWLIST = [
  "id",
  "email",
  "is_anonymous",
  "created_at",
  "email_confirmed_at",
  "deleted_at",
] as const;

export type AuthExportAllowField = (typeof AUTH_EXPORT_ALLOWLIST)[number];

export type SanitizedAuthUser = {
  id: string;
  email: string | null;
  is_anonymous: boolean;
  created_at: string | null;
  email_confirmed_at: string | null;
  deleted_at: string | null;
};

export type ProfileRow = {
  id: string;
  display_name: string;
  created_at?: string | null;
  class_id?: string | null;
  avatar_figurine_id?: number | null;
  sheet_confirmed?: boolean;
  strength?: number;
  dexterity?: number;
  constitution?: number;
  intelligence?: number;
  wisdom?: number;
  charisma?: number;
};

export type EntitlementSourceRow = {
  id: string;
  user_id: string;
  provider: string;
  provider_ref: string;
  status: string;
  current_period_end?: string | null;
  metadata?: Record<string, unknown> | null;
  created_at?: string | null;
  updated_at?: string | null;
};

export type UserEntitlementRow = {
  user_id: string;
  access_level: string;
  source: string;
  granted_at?: string | null;
  expires_at?: string | null;
  metadata?: Record<string, unknown> | null;
};

export type RoomRow = {
  id: string;
  name: string;
  status: string;
  host_id?: string | null;
  join_code?: string | null;
  scenario_id?: string | null;
  scenario?: string | null;
  min_players?: number;
  required_class_ids?: string[];
  scenario_prompt?: string;
  world_state?: unknown;
  locale?: string;
  started_at?: string | null;
  finished_at?: string | null;
  game_phase?: string | null;
  ending?: unknown;
  music_mood?: string;
  created_at?: string | null;
};

export type PlayerRow = {
  id: string;
  room_id: string;
  user_id: string;
  figurine_id: number;
  figurine_name: string;
  position_x?: number;
  position_y?: number;
  hp?: number;
  inventory?: unknown;
  joined_at?: string | null;
  class_id?: string | null;
  effects?: unknown;
  strength?: number;
  dexterity?: number;
  constitution?: number;
  intelligence?: number;
  wisdom?: number;
  charisma?: number;
};

export type GameEventRow = {
  id: string;
  room_id: string;
  player_id?: string | null;
  type: string;
  content: string;
  created_at?: string | null;
};

export type EnemyRow = {
  id: string;
  room_id: string;
  name: string;
  enemy_type: string;
  position_x?: number;
  position_y?: number;
  hp?: number;
  max_hp?: number;
  status?: string;
  metadata?: unknown;
};

export type CombatSessionRow = {
  id: string;
  room_id: string;
  active?: boolean;
  round?: number;
  started_at?: string | null;
  ended_at?: string | null;
  updated_at?: string | null;
};

export type PendingRollRow = {
  id: string;
  room_id: string;
  player_id: string;
  ability: string;
  dc: number;
  reason?: string;
  status: string;
  result?: number | null;
  modifier?: number | null;
  total?: number | null;
  success?: boolean | null;
  created_at?: string | null;
  resolved_at?: string | null;
};

export type RoomGmStateRow = {
  room_id: string;
  gm_secrets?: unknown;
  gm_state?: unknown;
  updated_at?: string | null;
};

export type DemoSessionRow = {
  id: string;
  user_id: string;
  room_id?: string | null;
  started_at?: string | null;
  expires_at?: string | null;
  completed_at?: string | null;
  paused_at?: string | null;
  created_at?: string | null;
};

export type AiUsageEventRow = {
  id: string;
  user_id?: string | null;
  room_id?: string | null;
  model?: string;
  kind?: string;
  created_at?: string | null;
};

export type Manifest = {
  version: string;
  exported_at: string;
  table_counts: Record<string, number>;
};

export type MigrationBundle = {
  manifest: Manifest;
  auth_users: SanitizedAuthUser[];
  profiles: ProfileRow[];
  entitlement_sources: EntitlementSourceRow[];
  user_entitlements: UserEntitlementRow[];
  rooms: RoomRow[];
  players: PlayerRow[];
  room_gm_state: RoomGmStateRow[];
  game_events: GameEventRow[];
  enemies: EnemyRow[];
  combat_sessions: CombatSessionRow[];
  pending_rolls: PendingRollRow[];
  demo_sessions: DemoSessionRow[];
  ai_usage_events: AiUsageEventRow[];
};

export type UserCategory =
  | "migratable_email"
  | "ignored_anonymous"
  | "pending_identity_link"
  | "ambiguous_identity"
  | "orphan";

export type FindingSeverity = "CRITICAL" | "IMPORTANT" | "INFO";

export type Finding = {
  severity: FindingSeverity;
  code: string;
  message: string;
  refs?: Record<string, string>;
};

export type DryRunVerdict = "DRY_RUN_PASS" | "DRY_RUN_BLOCKED";

export type DatasetCounts = {
  auth_users: number;
  profiles: number;
  entitlement_sources: number;
  user_entitlements: number;
  rooms: number;
  players: number;
  room_gm_state: number;
  game_events: number;
  enemies: number;
  combat_sessions: number;
  pending_rolls: number;
  demo_sessions: number;
  ai_usage_events: number;
};

export type DryRunReport = {
  verdict: DryRunVerdict;
  table_counts: DatasetCounts;
  source_counts: DatasetCounts;
  migratable_counts: DatasetCounts;
  archived_counts: DatasetCounts;
  category_counts: Record<UserCategory, number>;
  classified_users: Record<string, UserCategory>;
  pending_identity_link: string[];
  ambiguous_identity: string[];
  orphans: string[];
  unresolved_entitlements: string[];
  findings: Finding[];
  room_status_counts: Record<string, number>;
};

export const WORKOS_MAP_VERSION = "lot12-b3";

export type WorkosMapStatus =
  | "EXISTING_WORKOS_USER"
  | "NOT_FOUND"
  | "AMBIGUOUS_WORKOS_USER";

export type WorkosMapVerdict = "WORKOS_MAP_PASS" | "WORKOS_MAP_BLOCKED";

export type WorkosMapEntry = {
  legacy_user_id: string;
  email: string;
  status: WorkosMapStatus;
  workos_user_id: string | null;
};

export type WorkosMapping = {
  version: string;
  generated_at: string;
  verdict: WorkosMapVerdict;
  entries: WorkosMapEntry[];
  findings: Finding[];
};
