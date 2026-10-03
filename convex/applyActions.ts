import { internalMutation } from "./_generated/server";
import type { MutationCtx } from "./_generated/server";
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { accessLevelForUser } from "./lib/access";
import {
  applyDamage,
  applyHeal,
  asEffects,
  asInt,
  asInventory,
  asPayload,
  COMBAT_MUTATING_TYPES,
  ENEMY_MUTATING_TYPES,
  FINALE_TYPES,
  flattenPositionPayload,
  giveItem,
  hasRequestRoll,
  lastNarrativeMusicMood,
  MUTATING_TYPES,
  nextCombatState,
  normalizeEffect,
  parseDefeatEnemy,
  parseEnemyHp,
  parseFinishGame,
  parseMoveEnemy,
  parseRequestRoll,
  parseSpawnEnemy,
  parseStartCombatRound,
  playerIdFromPayload,
  removeEffect,
  removeItem,
  tickEffects,
  type GmAction,
  type JsonMap,
  upsertEffect,
} from "./lib/stateEffects";
import {
  createEnemy,
  damageEnemy,
  healEnemy,
  moveEnemy,
  resolveEnemyRow,
  setEnemyStatus,
} from "./enemies";
import { fetchCombatSession, upsertCombatSession } from "./combat";
import { createPendingRoll } from "./rolls";

const gmAction = v.object({
  type: v.string(),
  payload: v.optional(v.any()),
});

async function getPlayerInRoom(
  ctx: MutationCtx,
  roomId: Id<"rooms">,
  playerId: string,
): Promise<Doc<"players"> | null> {
  try {
    const row = await ctx.db.get(playerId as Id<"players">);
    if (row === null || row.roomId !== roomId) {
      return null;
    }
    return row;
  } catch {
    return null;
  }
}

async function persistNarrativeMusicMood(
  ctx: MutationCtx,
  roomId: Id<"rooms">,
  actions: GmAction[],
) {
  const mood = lastNarrativeMusicMood(actions);
  if (mood === null) {
    return;
  }
  await ctx.db.patch(roomId, {
    musicMood: mood as "tavern" | "exploration" | "mystery" | "tension",
  });
}

async function applyFinish(
  ctx: MutationCtx,
  roomId: Id<"rooms">,
  action: GmAction,
): Promise<string | null> {
  const ending = parseFinishGame(action.payload);
  const room = await ctx.db.get(roomId);
  if (room === null) {
    return null;
  }
  let accessLevel: "demo" | "full" = "demo";
  if (room.hostUserId) {
    try {
      accessLevel = await accessLevelForUser(ctx, room.hostUserId);
    } catch {
      accessLevel = "demo";
    }
  }
  const demoCut = room.scenarioId === "demo" && accessLevel !== "full";
  const status = demoCut ? "demo_finished" : "finished";
  if (room.status !== "playing" && room.status !== "paused") {
    return null;
  }
  const finishedAt = Date.now();
  await ctx.db.patch(roomId, {
    status,
    finishedAt,
    ending: {
      result: ending.result,
      summary: ending.summary,
      epilogue: ending.epilogue,
    },
  });
  const sessions = await ctx.db
    .query("demoSessions")
    .withIndex("by_room", (q) => q.eq("roomId", roomId))
    .collect();
  for (const session of sessions) {
    if (session.completedAt === undefined) {
      await ctx.db.patch(session._id, { completedAt: finishedAt });
    }
  }
  return `Fin de partie (${ending.result}).`;
}

async function applyCombat(
  ctx: MutationCtx,
  roomId: Id<"rooms">,
  action: GmAction,
): Promise<string | null> {
  if (action.type === "start_combat") {
    const payload = asPayload(action.payload);
    const requested = parseStartCombatRound(payload);
    if (requested === undefined) {
      return null;
    }
    const current = await fetchCombatSession(ctx, roomId);
    const nextState = nextCombatState({
      currentActive: current?.active ?? false,
      currentRound: current ? asInt(current.round, 0) : 0,
      starting: true,
      requestedRound: requested,
    });
    await upsertCombatSession(ctx, {
      roomId,
      active: true,
      round: nextState.round,
    });
    return `Combat : round ${nextState.round}.`;
  }
  if (action.type === "end_combat") {
    const current = await fetchCombatSession(ctx, roomId);
    const nextState = nextCombatState({
      currentActive: current?.active ?? false,
      currentRound: current ? asInt(current.round, 0) : 0,
      starting: false,
      requestedRound: null,
    });
    await upsertCombatSession(ctx, {
      roomId,
      active: false,
      round: nextState.round,
    });
    return "Combat termine.";
  }
  return null;
}

async function applyEnemy(
  ctx: MutationCtx,
  roomId: Id<"rooms">,
  action: GmAction,
): Promise<string | null> {
  const data = flattenPositionPayload(asPayload(action.payload));
  if (action.type === "spawn_enemy") {
    const payload = parseSpawnEnemy(data);
    if (payload === null) {
      return null;
    }
    const row = await createEnemy(ctx, {
      roomId,
      name: payload.name,
      enemyType: payload.enemy_type,
      positionX: payload.x,
      positionY: payload.y,
      hp: payload.hp,
      maxHp: payload.max_hp,
    });
    const enemyId = row?._id ?? "";
    return (
      `${payload.name} apparait (${payload.hp}/${payload.max_hp} PV` +
      `${enemyId ? `, id ${enemyId}` : ""}).`
    );
  }
  if (action.type === "move_enemy") {
    const payload = parseMoveEnemy(data);
    if (payload === null) {
      return null;
    }
    const row = await resolveEnemyRow(ctx, {
      roomId,
      enemyId: payload.enemy_id,
      name: payload.name,
    });
    if (row === null) {
      return null;
    }
    await moveEnemy(ctx, {
      roomId,
      enemyId: row._id,
      x: payload.x,
      y: payload.y,
    });
    return `${row.name || "Ennemi"} se deplace.`;
  }
  if (action.type === "damage_enemy") {
    const payload = parseEnemyHp(data);
    if (payload === null || payload.amount <= 0) {
      return null;
    }
    const row = await resolveEnemyRow(ctx, {
      roomId,
      enemyId: payload.enemy_id,
      name: payload.name,
    });
    if (row === null) {
      return null;
    }
    const result = await damageEnemy(ctx, {
      roomId,
      enemyId: row._id,
      amount: payload.amount,
    });
    if (result === null) {
      return null;
    }
    const suffix = result.status === "defeated" ? " Vaincu." : "";
    return (
      `${result.name} perd ${payload.amount} PV ` +
      `(${result.hp} -> ${result.next_hp}).${suffix}`
    );
  }
  if (action.type === "heal_enemy") {
    const payload = parseEnemyHp(data);
    if (payload === null || payload.amount <= 0) {
      return null;
    }
    const row = await resolveEnemyRow(ctx, {
      roomId,
      enemyId: payload.enemy_id,
      name: payload.name,
    });
    if (row === null) {
      return null;
    }
    const result = await healEnemy(ctx, {
      roomId,
      enemyId: row._id,
      amount: payload.amount,
    });
    if (result === null) {
      return null;
    }
    return (
      `${result.name} recupere ${payload.amount} PV ` +
      `(${result.hp} -> ${result.next_hp}).`
    );
  }
  if (action.type === "defeat_enemy") {
    const payload = parseDefeatEnemy(data);
    if (payload === null) {
      return null;
    }
    const row = await resolveEnemyRow(ctx, {
      roomId,
      enemyId: payload.enemy_id,
      name: payload.name,
    });
    if (row === null) {
      return null;
    }
    await setEnemyStatus(ctx, {
      roomId,
      enemyId: row._id,
      status: "defeated",
      hp: 0,
    });
    return `${row.name || "Ennemi"} est vaincu.`;
  }
  return null;
}

async function applyOne(
  ctx: MutationCtx,
  roomId: Id<"rooms">,
  action: GmAction,
): Promise<string | null> {
  if (action.type === "finish_game") {
    return await applyFinish(ctx, roomId, action);
  }
  if (ENEMY_MUTATING_TYPES.has(action.type)) {
    return await applyEnemy(ctx, roomId, action);
  }
  if (COMBAT_MUTATING_TYPES.has(action.type)) {
    return await applyCombat(ctx, roomId, action);
  }

  const payload = asPayload(action.payload);
  const playerId = playerIdFromPayload(payload);
  if (playerId === null) {
    return null;
  }
  const row = await getPlayerInRoom(ctx, roomId, playerId);
  if (row === null) {
    return null;
  }
  const name = row.figurineName || "Aventurier";
  const hp = asInt(row.hp, 0);
  const inventory = asInventory(row.inventory);
  const effects = asEffects(row.effects);

  if (action.type === "damage_player") {
    const amount = Math.max(0, asInt(payload.amount ?? payload.damage, 0));
    if (amount <= 0) {
      return null;
    }
    const nextHp = applyDamage(hp, amount);
    await ctx.db.patch(row._id, { hp: nextHp });
    return `${name} perd ${amount} PV (${hp} -> ${nextHp}).`;
  }
  if (action.type === "heal_player") {
    const amount = Math.max(0, asInt(payload.amount ?? payload.heal, 0));
    if (amount <= 0) {
      return null;
    }
    const nextHp = applyHeal(hp, amount);
    await ctx.db.patch(row._id, { hp: nextHp });
    return `${name} recupere ${amount} PV (${hp} -> ${nextHp}).`;
  }
  if (action.type === "give_item") {
    let item: JsonMap | null = null;
    if (
      payload.item !== null &&
      typeof payload.item === "object" &&
      !Array.isArray(payload.item)
    ) {
      item = payload.item as JsonMap;
    } else {
      const nameValue = payload.name;
      if (typeof nameValue !== "string" || !nameValue.trim()) {
        return null;
      }
      item = {
        id: payload.id || nameValue,
        name: nameValue,
        description: payload.description || "",
        quantity: payload.quantity || 1,
        type: payload.item_type || payload.type || "unknown",
        bonuses: payload.bonuses,
        heal: payload.heal,
        effect: payload.effect,
      };
    }
    const nextInventory = giveItem(inventory, item);
    await ctx.db.patch(row._id, { inventory: nextInventory });
    return `${name} obtient ${String(item.name ?? "un objet")}.`;
  }
  if (action.type === "remove_item") {
    let itemRef: unknown = payload.item_id ?? payload.name ?? payload.item;
    if (itemRef !== null && typeof itemRef === "object" && !Array.isArray(itemRef)) {
      const mapped = itemRef as JsonMap;
      itemRef = mapped.id ?? mapped.name;
    }
    if (typeof itemRef !== "string" || !itemRef.trim()) {
      return null;
    }
    const quantity = asInt(payload.quantity, 1);
    const nextInventory = removeItem(inventory, itemRef.trim(), quantity);
    await ctx.db.patch(row._id, { inventory: nextInventory });
    return `${name} perd ${itemRef}.`;
  }
  if (action.type === "apply_effect") {
    const incoming = normalizeEffect(payload.effect ?? payload);
    if (incoming === null) {
      return null;
    }
    const nextEffects = upsertEffect(effects, incoming);
    await ctx.db.patch(row._id, { effects: nextEffects });
    return `${name} recoit ${incoming.name}.`;
  }
  if (action.type === "remove_effect") {
    const effectId = payload.effect_id ?? payload.id ?? payload.name;
    if (typeof effectId !== "string" || !effectId.trim()) {
      return null;
    }
    const nextEffects = removeEffect(effects, effectId.trim());
    await ctx.db.patch(row._id, { effects: nextEffects });
    return `${name} perd l effet ${effectId}.`;
  }
  return null;
}

async function persistRequestRolls(
  ctx: MutationCtx,
  roomId: Id<"rooms">,
  actions: GmAction[],
): Promise<string[]> {
  const summaries: string[] = [
    "Jet demande : aucun effet applique avant le resultat.",
  ];
  for (const action of actions) {
    if (action.type !== "request_roll") {
      continue;
    }
    const parsed = parseRequestRoll(asPayload(action.payload));
    if (parsed === null) {
      continue;
    }
    const row = await getPlayerInRoom(ctx, roomId, parsed.player_id);
    if (row === null) {
      continue;
    }
    await createPendingRoll(ctx, {
      roomId,
      playerId: row._id,
      ability: parsed.ability as
        | "strength"
        | "dexterity"
        | "constitution"
        | "intelligence"
        | "wisdom"
        | "charisma",
      dc: parsed.dc,
      reason: parsed.reason,
    });
    const name = row.figurineName || "Aventurier";
    summaries.push(
      `Jet de ${parsed.ability} demande a ${name} (DD ${parsed.dc}).`,
    );
  }
  return summaries;
}

async function tickRoomEffects(
  ctx: MutationCtx,
  roomId: Id<"rooms">,
): Promise<string[]> {
  const summaries: string[] = [];
  const rows = await ctx.db
    .query("players")
    .withIndex("by_room", (q) => q.eq("roomId", roomId))
    .collect();
  for (const row of rows) {
    const current = asEffects(row.effects);
    const { kept, expired } = tickEffects(current);
    if (expired.length === 0 && JSON.stringify(kept) === JSON.stringify(current)) {
      continue;
    }
    await ctx.db.patch(row._id, { effects: kept });
    const name = row.figurineName || "Aventurier";
    for (const effect of expired) {
      summaries.push(`${name} : ${String(effect.name ?? "effet")} se dissipe.`);
    }
  }
  return summaries;
}

export async function applyGameMasterActionsHandler(
  ctx: MutationCtx,
  args: { roomId: Id<"rooms">; actions: GmAction[] },
) {
  const actions: GmAction[] = args.actions.map((action) => ({
    type: action.type,
    payload: action.payload,
  }));
  await persistNarrativeMusicMood(ctx, args.roomId, actions);
  if (hasRequestRoll(actions)) {
    const summaries = await persistRequestRolls(ctx, args.roomId, actions);
    for (const action of actions) {
      if (COMBAT_MUTATING_TYPES.has(action.type)) {
        const summary = await applyCombat(ctx, args.roomId, action);
        if (summary) {
          summaries.push(summary);
        }
      } else if (FINALE_TYPES.has(action.type)) {
        const summary = await applyFinish(ctx, args.roomId, action);
        if (summary) {
          summaries.push(summary);
        }
      }
    }
    return summaries;
  }

  const summaries: string[] = [];
  for (const action of actions) {
    if (!MUTATING_TYPES.has(action.type)) {
      continue;
    }
    const summary = await applyOne(ctx, args.roomId, action);
    if (summary) {
      summaries.push(summary);
    }
  }
  summaries.push(...(await tickRoomEffects(ctx, args.roomId)));
  return summaries;
}

export const applyGameMasterActions = internalMutation({
  args: {
    roomId: v.id("rooms"),
    actions: v.array(gmAction),
  },
  handler: async (ctx, args) => {
    return await applyGameMasterActionsHandler(ctx, args);
  },
});
