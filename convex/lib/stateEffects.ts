export const HP_MIN = 0;
export const HP_MAX = 100;
export const ENEMY_HP_MAX = 500;
export const PLAY_STAT_MIN = 1;
export const PLAY_STAT_MAX = 30;
export const DC_MIN = 5;
export const DC_MAX = 25;
export const COMBAT_ROUND_MAX = 999;
export const DEFAULT_POTION_HEAL = 20;
export const POTION_ITEM_TYPES = new Set(["potion", "consumable"]);

export const VALID_ABILITIES = new Set([
  "strength",
  "dexterity",
  "constitution",
  "intelligence",
  "wisdom",
  "charisma",
]);

export const VALID_EFFECT_KINDS = new Set(["buff", "debuff", "wound", "spell"]);

export const MUTATING_TYPES = new Set([
  "damage_player",
  "heal_player",
  "give_item",
  "remove_item",
  "apply_effect",
  "remove_effect",
  "spawn_enemy",
  "move_enemy",
  "damage_enemy",
  "heal_enemy",
  "defeat_enemy",
  "start_combat",
  "end_combat",
  "finish_game",
]);

export const ENEMY_MUTATING_TYPES = new Set([
  "spawn_enemy",
  "move_enemy",
  "damage_enemy",
  "heal_enemy",
  "defeat_enemy",
]);

export const FINALE_TYPES = new Set(["finish_game"]);

export const COMBAT_MUTATING_TYPES = new Set(["start_combat", "end_combat"]);

export const VALID_GAME_RESULTS = new Set(["victory", "defeat", "neutral"]);

export const NARRATIVE_MUSIC_MOODS = new Set([
  "tavern",
  "exploration",
  "mystery",
  "tension",
]);

export type JsonMap = Record<string, unknown>;

export type GmAction = {
  type: string;
  payload?: unknown;
};

export function clampHp(value: number): number {
  return Math.max(HP_MIN, Math.min(HP_MAX, value));
}

export function asInt(value: unknown, defaultValue = 0): number {
  if (typeof value === "boolean") {
    return defaultValue;
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string") {
    const trimmed = value.trim();
    const digits = trimmed.startsWith("-") ? trimmed.slice(1) : trimmed;
    if (digits.length > 0 && /^\d+$/.test(digits)) {
      return Number.parseInt(trimmed, 10);
    }
  }
  return defaultValue;
}

export function playerIdFromPayload(payload: JsonMap): string | null {
  for (const key of ["player_id", "target_id", "target"]) {
    const value = payload[key];
    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }
  }
  return null;
}

export function applyDamage(hp: number, amount: number): number {
  return clampHp(hp - Math.max(0, amount));
}

export function applyHeal(hp: number, amount: number): number {
  return clampHp(hp + Math.max(0, amount));
}

function cloneList<T>(value: T[]): T[] {
  return structuredClone(value);
}

function itemExtras(item: JsonMap): JsonMap {
  const extras: JsonMap = {};
  const bonuses = item.bonuses;
  if (bonuses !== null && typeof bonuses === "object" && !Array.isArray(bonuses)) {
    const cleaned: Record<string, number> = {};
    for (const [key, value] of Object.entries(bonuses as JsonMap)) {
      if (!VALID_ABILITIES.has(key)) {
        continue;
      }
      const amount = asInt(value, 0);
      if (amount === 0) {
        continue;
      }
      cleaned[key] = Math.max(-6, Math.min(6, amount));
    }
    if (Object.keys(cleaned).length > 0) {
      extras.bonuses = cleaned;
    }
  }
  const heal = asInt(item.heal, 0);
  if (heal > 0) {
    extras.heal = Math.max(1, Math.min(50, heal));
  }
  const effect = normalizeEffect(item.effect);
  if (effect !== null) {
    extras.effect = effect;
  }
  return extras;
}

export function giveItem(inventory: JsonMap[], item: JsonMap): JsonMap[] {
  const nextInventory = cloneList(inventory);
  const itemId = String(item.id ?? item.name ?? "item");
  const name = String(item.name ?? "Objet");
  const quantity = Math.max(1, asInt(item.quantity, 1));
  const extras = itemExtras(item);
  for (const existing of nextInventory) {
    const existingId = String(existing.id ?? existing.name ?? "");
    if (existingId === itemId || existing.name === name) {
      existing.quantity = asInt(existing.quantity, 1) + quantity;
      return nextInventory;
    }
  }
  nextInventory.push({
    id: itemId,
    name,
    description: String(item.description ?? ""),
    quantity,
    type: String(item.type ?? "unknown"),
    equipped: false,
    ...extras,
  });
  return nextInventory;
}

export function removeItem(
  inventory: JsonMap[],
  itemRef: string,
  quantity = 1,
): JsonMap[] {
  const nextInventory: JsonMap[] = [];
  let remaining = Math.max(1, quantity);
  for (const existing of cloneList(inventory)) {
    const existingId = String(existing.id ?? "");
    const existingName = String(existing.name ?? "");
    if (remaining > 0 && (itemRef === existingId || itemRef === existingName)) {
      const currentQty = asInt(existing.quantity, 1);
      if (currentQty > remaining) {
        existing.quantity = currentQty - remaining;
        remaining = 0;
        nextInventory.push(existing);
      } else {
        remaining -= currentQty;
      }
      continue;
    }
    nextInventory.push(existing);
  }
  return nextInventory;
}

export function normalizeEffect(raw: unknown): JsonMap | null {
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) {
    return null;
  }
  const data = raw as JsonMap;
  const effectId = String(data.id ?? data.name ?? "").trim();
  const name = String(data.name ?? effectId ?? "Effet").trim();
  if (!effectId) {
    return null;
  }
  let kind = String(data.kind ?? data.type ?? "spell").trim();
  if (!VALID_EFFECT_KINDS.has(kind)) {
    kind = "spell";
  }
  const statRaw = data.stat ?? data.ability;
  const stat = typeof statRaw === "string" && VALID_ABILITIES.has(statRaw) ? statRaw : null;
  const remainingRaw = data.remaining ?? data.duration;
  let remaining: number | null = null;
  if (remainingRaw !== undefined && remainingRaw !== null) {
    remaining = Math.max(1, Math.min(20, asInt(remainingRaw, 1)));
  }
  return {
    id: effectId,
    name,
    kind,
    stat,
    delta: Math.max(-6, Math.min(6, asInt(data.delta ?? data.bonus, 0))),
    remaining,
    source: String(data.source ?? "gm"),
  };
}

export function upsertEffect(effects: JsonMap[], incoming: JsonMap): JsonMap[] {
  const nextEffects = cloneList(effects);
  for (let index = 0; index < nextEffects.length; index += 1) {
    if (String(nextEffects[index]?.id ?? "") === incoming.id) {
      nextEffects[index] = incoming;
      return nextEffects;
    }
  }
  nextEffects.push(incoming);
  return nextEffects;
}

export function removeEffect(effects: JsonMap[], effectId: string): JsonMap[] {
  return cloneList(effects).filter(
    (existing) => String(existing.id ?? "") !== effectId,
  );
}

export function tickEffects(effects: JsonMap[]): {
  kept: JsonMap[];
  expired: JsonMap[];
} {
  const kept: JsonMap[] = [];
  const expired: JsonMap[] = [];
  for (const existing of cloneList(effects)) {
    const remaining = existing.remaining;
    if (remaining === null || remaining === undefined) {
      kept.push(existing);
      continue;
    }
    const nextRemaining = asInt(remaining, 0) - 1;
    if (nextRemaining <= 0) {
      expired.push(existing);
      continue;
    }
    existing.remaining = nextRemaining;
    kept.push(existing);
  }
  return { kept, expired };
}

export function hasRequestRoll(actions: GmAction[]): boolean {
  return actions.some((action) => action.type === "request_roll");
}

export function clampDc(value: number): number {
  return Math.max(DC_MIN, Math.min(DC_MAX, value));
}

export function parseRequestRoll(payload: JsonMap): {
  player_id: string;
  ability: string;
  dc: number;
  reason: string;
} | null {
  const playerId = playerIdFromPayload(payload);
  const ability = payload.ability ?? payload.stat;
  if (
    playerId === null ||
    typeof ability !== "string" ||
    !VALID_ABILITIES.has(ability)
  ) {
    return null;
  }
  if (!("dc" in payload) && !("difficulty" in payload)) {
    return null;
  }
  const dc = asInt(payload.dc ?? payload.difficulty, 0);
  if (dc <= 0) {
    return null;
  }
  const reason = payload.reason;
  const reasonText = typeof reason === "string" ? reason.trim().slice(0, 240) : "";
  return {
    player_id: playerId,
    ability,
    dc: clampDc(dc),
    reason: reasonText,
  };
}

export function effectiveScoreFromRow(row: JsonMap, key: string): number {
  if (!VALID_ABILITIES.has(key)) {
    return 10;
  }
  let score = asInt(row[key], 10);
  const inventory = row.inventory;
  if (Array.isArray(inventory)) {
    for (const item of inventory) {
      if (item === null || typeof item !== "object" || Array.isArray(item)) {
        continue;
      }
      const mapped = item as JsonMap;
      if (!mapped.equipped) {
        continue;
      }
      const bonuses = mapped.bonuses;
      if (bonuses !== null && typeof bonuses === "object" && !Array.isArray(bonuses)) {
        score += asInt((bonuses as JsonMap)[key], 0);
      }
    }
  }
  const effects = row.effects;
  if (Array.isArray(effects)) {
    for (const effect of effects) {
      if (effect === null || typeof effect !== "object" || Array.isArray(effect)) {
        continue;
      }
      const mapped = effect as JsonMap;
      if (mapped.stat === key || mapped.ability === key) {
        score += asInt(mapped.delta, 0);
      }
    }
  }
  return Math.max(PLAY_STAT_MIN, Math.min(PLAY_STAT_MAX, score));
}

export function effectiveModifierFromRow(row: JsonMap, key: string): number {
  return Math.floor((effectiveScoreFromRow(row, key) - 10) / 2);
}

export function resolveRollTotal(args: {
  raw: number;
  modifier: number;
  dc: number;
}): { raw: number; modifier: number; total: number; success: boolean } {
  const clampedRaw = Math.max(1, Math.min(20, args.raw));
  const total = clampedRaw + args.modifier;
  return {
    raw: clampedRaw,
    modifier: args.modifier,
    total,
    success: total >= args.dc,
  };
}

export function nextCombatState(args: {
  currentActive: boolean;
  currentRound: number;
  starting: boolean;
  requestedRound: number | null;
}): { active: boolean; round: number } {
  if (!args.starting) {
    return {
      active: false,
      round: Math.max(0, Math.min(COMBAT_ROUND_MAX, args.currentRound)),
    };
  }
  if (args.requestedRound !== null) {
    return {
      active: true,
      round: Math.max(1, Math.min(COMBAT_ROUND_MAX, args.requestedRound)),
    };
  }
  if (args.currentActive) {
    return {
      active: true,
      round: Math.max(1, Math.min(COMBAT_ROUND_MAX, args.currentRound + 1)),
    };
  }
  return { active: true, round: 1 };
}

export function combatContextFromRow(
  row: JsonMap | null,
): { active: boolean; round: number } {
  if (row === null) {
    return { active: false, round: 0 };
  }
  return {
    active: Boolean(row.active),
    round: Math.max(0, Math.min(COMBAT_ROUND_MAX, asInt(row.round, 0))),
  };
}

export function canResolvePendingRoll(args: {
  status: string;
  rollPlayerId: string;
  actorPlayerId: string;
}): boolean {
  return args.status === "pending" && args.rollPlayerId === args.actorPlayerId;
}

export function clampEnemyHp(value: number, maxHp: number): number {
  const ceiling = Math.max(1, Math.min(ENEMY_HP_MAX, maxHp));
  return Math.max(HP_MIN, Math.min(ceiling, value));
}

export function enemyStatusForHp(
  hp: number,
  currentStatus = "active",
): "active" | "defeated" | "escaped" {
  if (hp <= 0) {
    return "defeated";
  }
  if (currentStatus === "escaped") {
    return "escaped";
  }
  return "active";
}

export function applyEnemyDamage(hp: number, amount: number, maxHp: number): number {
  return clampEnemyHp(hp - Math.max(0, amount), maxHp);
}

export function applyEnemyHeal(hp: number, amount: number, maxHp: number): number {
  return clampEnemyHp(hp + Math.max(0, amount), maxHp);
}

export function flattenPositionPayload(payload: JsonMap): JsonMap {
  const data: JsonMap = { ...payload };
  const position = data.position;
  if (position !== null && typeof position === "object" && !Array.isArray(position)) {
    const pos = position as JsonMap;
    if (data.x === undefined && pos.x !== undefined && pos.x !== null) {
      data.x = pos.x;
    }
    if (data.y === undefined && pos.y !== undefined && pos.y !== null) {
      data.y = pos.y;
    }
  }
  if (!data.enemy_type) {
    const typeValue = data.type;
    if (typeof typeValue === "string" && typeValue.trim()) {
      data.enemy_type = typeValue.trim();
    }
  }
  const amount = data.amount ?? data.damage ?? data.heal;
  if (amount !== undefined) {
    data.amount = amount;
  }
  const enemyId = data.enemy_id ?? data.id ?? data.target_id;
  if (typeof enemyId === "string" && enemyId.trim()) {
    data.enemy_id = enemyId.trim();
  }
  const name = data.name ?? data.enemy_name;
  if (typeof name === "string" && name.trim()) {
    data.name = name.trim();
  }
  return data;
}

export function parseFinishGame(payload: unknown): {
  result: string;
  summary: string;
  epilogue: string;
} {
  const data =
    payload !== null && typeof payload === "object" && !Array.isArray(payload)
      ? (payload as JsonMap)
      : {};
  let result = String(data.result ?? "neutral").trim().toLowerCase();
  if (!VALID_GAME_RESULTS.has(result)) {
    result = "neutral";
  }
  return {
    result,
    summary: String(data.summary ?? "").trim().slice(0, 2000),
    epilogue: String(data.epilogue ?? "").trim().slice(0, 4000),
  };
}

export function lastNarrativeMusicMood(actions: GmAction[]): string | null {
  let last: string | null = null;
  for (const action of actions) {
    if (action.type !== "set_music_mood") {
      continue;
    }
    if (
      action.payload === null ||
      typeof action.payload !== "object" ||
      Array.isArray(action.payload)
    ) {
      continue;
    }
    const mood = String((action.payload as JsonMap).mood ?? "")
      .trim()
      .toLowerCase();
    if (NARRATIVE_MUSIC_MOODS.has(mood)) {
      last = mood;
    }
  }
  return last;
}

export function isPotionItem(item: JsonMap): boolean {
  const type = String(item.type ?? "");
  return POTION_ITEM_TYPES.has(type) || asInt(item.heal, 0) > 0;
}

export function consumePotion(
  inventory: JsonMap[],
  itemId: string,
): { inventory: JsonMap[]; heal: number } {
  const next: JsonMap[] = [];
  let heal = 0;
  for (const item of cloneList(inventory)) {
    if (String(item.id ?? "") !== itemId || !isPotionItem(item) || heal > 0) {
      next.push(item);
      continue;
    }
    heal = item.heal === undefined || item.heal === null
      ? DEFAULT_POTION_HEAL
      : asInt(item.heal, DEFAULT_POTION_HEAL);
    if (asInt(item.quantity, 1) > 1) {
      item.quantity = asInt(item.quantity, 1) - 1;
      next.push(item);
    }
  }
  return { inventory: next, heal };
}

export function asPayload(value: unknown): JsonMap {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as JsonMap;
  }
  return {};
}

export function asInventory(value: unknown): JsonMap[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter(
    (item): item is JsonMap =>
      item !== null && typeof item === "object" && !Array.isArray(item),
  );
}

export function asEffects(value: unknown): JsonMap[] {
  return asInventory(value);
}

function inClosedRange(value: number, min: number, max: number): boolean {
  return Number.isFinite(value) && value >= min && value <= max;
}

export function parseSpawnEnemy(data: JsonMap): {
  name: string;
  enemy_type: string;
  x: number;
  y: number;
  hp: number;
  max_hp: number;
} | null {
  if (typeof data.name !== "string") {
    return null;
  }
  const name = data.name.trim();
  if (name.length < 1 || name.length > 80) {
    return null;
  }
  const enemyTypeRaw =
    typeof data.enemy_type === "string" && data.enemy_type.trim()
      ? data.enemy_type.trim()
      : "enemy";
  if (enemyTypeRaw.length < 1 || enemyTypeRaw.length > 40) {
    return null;
  }
  const x = data.x === undefined ? 0.5 : Number(data.x);
  const y = data.y === undefined ? 0.5 : Number(data.y);
  if (!inClosedRange(x, 0, 1) || !inClosedRange(y, 0, 1)) {
    return null;
  }
  const hp = data.hp === undefined ? 20 : asInt(data.hp, 0);
  if (hp < 1 || hp > 500) {
    return null;
  }
  let maxHp = data.max_hp === undefined || data.max_hp === null ? hp : asInt(data.max_hp, 0);
  if (data.max_hp !== undefined && data.max_hp !== null && (maxHp < 1 || maxHp > 500)) {
    return null;
  }
  if (maxHp < hp) {
    maxHp = hp;
  }
  return {
    name,
    enemy_type: enemyTypeRaw,
    x,
    y,
    hp,
    max_hp: maxHp,
  };
}

export function parseMoveEnemy(data: JsonMap): {
  enemy_id: string | null;
  name: string | null;
  x: number;
  y: number;
} | null {
  const x = Number(data.x);
  const y = Number(data.y);
  if (!inClosedRange(x, 0, 1) || !inClosedRange(y, 0, 1)) {
    return null;
  }
  let enemyId: string | null = null;
  if (typeof data.enemy_id === "string" && data.enemy_id.trim()) {
    enemyId = data.enemy_id.trim();
  }
  let name: string | null = null;
  if (typeof data.name === "string" && data.name.trim()) {
    const trimmed = data.name.trim();
    if (trimmed.length > 80) {
      return null;
    }
    name = trimmed;
  }
  return { enemy_id: enemyId, name, x, y };
}

export function parseEnemyHp(data: JsonMap): {
  enemy_id: string | null;
  name: string | null;
  amount: number;
} | null {
  const amount = asInt(data.amount, Number.NaN);
  if (!Number.isFinite(amount) || amount < 0 || amount > 500) {
    return null;
  }
  let enemyId: string | null = null;
  if (typeof data.enemy_id === "string" && data.enemy_id.trim()) {
    enemyId = data.enemy_id.trim();
  }
  let name: string | null = null;
  if (typeof data.name === "string" && data.name.trim()) {
    const trimmed = data.name.trim();
    if (trimmed.length > 80) {
      return null;
    }
    name = trimmed;
  }
  return { enemy_id: enemyId, name, amount };
}

export function parseDefeatEnemy(data: JsonMap): {
  enemy_id: string | null;
  name: string | null;
} | null {
  let enemyId: string | null = null;
  if (typeof data.enemy_id === "string" && data.enemy_id.trim()) {
    enemyId = data.enemy_id.trim();
  }
  let name: string | null = null;
  if (typeof data.name === "string" && data.name.trim()) {
    const trimmed = data.name.trim();
    if (trimmed.length > 80) {
      return null;
    }
    name = trimmed;
  }
  return { enemy_id: enemyId, name };
}

export function parseStartCombatRound(payload: JsonMap): number | null | undefined {
  if (payload.round === undefined || payload.round === null) {
    return null;
  }
  const round = asInt(payload.round, 0);
  if (round < 1 || round > 999) {
    return undefined;
  }
  return round;
}
