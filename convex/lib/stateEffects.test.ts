import { describe, expect, test } from "vitest";
import {
  applyDamage,
  applyEnemyDamage,
  applyEnemyHeal,
  applyHeal,
  canResolvePendingRoll,
  combatContextFromRow,
  consumePotion,
  effectiveModifierFromRow,
  enemyStatusForHp,
  flattenPositionPayload,
  giveItem,
  hasRequestRoll,
  nextCombatState,
  parseFinishGame,
  parseRequestRoll,
  removeItem,
  resolveRollTotal,
  tickEffects,
} from "./stateEffects";

describe("stateEffects python oracle", () => {
  test("damage and heal are clamped", () => {
    expect(applyDamage(10, 4)).toBe(6);
    expect(applyDamage(3, 10)).toBe(0);
    expect(applyHeal(90, 20)).toBe(100);
  });

  test("give item stacks same id", () => {
    let inventory = giveItem([], { id: "torch", name: "Torche", quantity: 1 });
    inventory = giveItem(inventory, { id: "torch", name: "Torche", quantity: 2 });
    expect(inventory).toHaveLength(1);
    expect(inventory[0]?.quantity).toBe(3);
  });

  test("remove item decreases quantity", () => {
    const inventory = [
      { id: "potion", name: "Potion", quantity: 2, type: "consumable" },
    ];
    const nextInventory = removeItem(inventory, "potion", 1);
    expect(nextInventory[0]?.quantity).toBe(1);
    expect(removeItem(nextInventory, "potion", 1)).toEqual([]);
  });

  test("give item keeps bonuses", () => {
    const inventory = giveItem([], {
      id: "sword",
      name: "Epee",
      type: "weapon",
      bonuses: { strength: 2 },
    });
    expect((inventory[0]?.bonuses as { strength: number }).strength).toBe(2);
    expect(inventory[0]?.equipped).toBe(false);
  });

  test("tick effects expires and keeps permanent", () => {
    const { kept, expired } = tickEffects([
      { id: "bless", name: "Bless", remaining: 1 },
      { id: "mark", name: "Marque", remaining: null },
    ]);
    expect(expired).toHaveLength(1);
    expect(expired[0]?.id).toBe("bless");
    expect(kept[0]?.id).toBe("mark");
  });

  test("enemy damage clamps and defeats at zero", () => {
    expect(applyEnemyDamage(12, 4, 12)).toBe(8);
    expect(applyEnemyDamage(3, 10, 12)).toBe(0);
    expect(enemyStatusForHp(0)).toBe("defeated");
    expect(enemyStatusForHp(8)).toBe("active");
  });

  test("enemy heal clamps to max hp and revives", () => {
    expect(applyEnemyHeal(0, 5, 12)).toBe(5);
    expect(applyEnemyHeal(10, 20, 12)).toBe(12);
    expect(enemyStatusForHp(5, "defeated")).toBe("active");
  });

  test("flatten position payload accepts nested position", () => {
    const data = flattenPositionPayload({
      name: "Orc",
      position: { x: 0.2, y: 0.8 },
      type: "orc",
    });
    expect(data.x).toBe(0.2);
    expect(data.y).toBe(0.8);
    expect(data.enemy_type).toBe("orc");
  });

  test("parse request roll accepts target_id and clamps dc", () => {
    const parsed = parseRequestRoll({
      target_id: "player-b",
      ability: "dexterity",
      dc: 14,
      reason: "esquiver le piege",
    });
    expect(parsed).toEqual({
      player_id: "player-b",
      ability: "dexterity",
      dc: 14,
      reason: "esquiver le piege",
    });
    expect(
      parseRequestRoll({ player_id: "p1", stat: "wisdom", difficulty: 2 })?.dc,
    ).toBe(5);
    expect(
      parseRequestRoll({ player_id: "p1", ability: "wisdom", dc: 40 })?.dc,
    ).toBe(25);
    expect(
      parseRequestRoll({ player_id: "p1", ability: "luck", dc: 12 }),
    ).toBeNull();
  });

  test("other player cannot resolve", () => {
    expect(
      canResolvePendingRoll({
        status: "pending",
        rollPlayerId: "p1",
        actorPlayerId: "p1",
      }),
    ).toBe(true);
    expect(
      canResolvePendingRoll({
        status: "pending",
        rollPlayerId: "p1",
        actorPlayerId: "p2",
      }),
    ).toBe(false);
    expect(
      canResolvePendingRoll({
        status: "resolved",
        rollPlayerId: "p1",
        actorPlayerId: "p1",
      }),
    ).toBe(false);
  });

  test("modifier includes equipped bonus and effects", () => {
    expect(
      effectiveModifierFromRow(
        {
          strength: 16,
          inventory: [
            { id: "sword", equipped: true, bonuses: { strength: 2 } },
            { id: "ring", equipped: false, bonuses: { strength: 4 } },
          ],
          effects: [
            { stat: "strength", delta: 2 },
            { ability: "dexterity", delta: 6 },
          ],
        },
        "strength",
      ),
    ).toBe(5);
  });

  test("success when total meets dc and raw is clamped", () => {
    const success = resolveRollTotal({ raw: 12, modifier: 2, dc: 14 });
    expect(success.raw).toBe(12);
    expect(success.total).toBe(14);
    expect(success.success).toBe(true);
    expect(resolveRollTotal({ raw: 11, modifier: 2, dc: 14 }).success).toBe(false);
    expect(resolveRollTotal({ raw: 40, modifier: 0, dc: 10 }).raw).toBe(20);
    expect(resolveRollTotal({ raw: 0, modifier: 0, dc: 10 }).raw).toBe(1);
  });

  test("combat start increment and end keep round", () => {
    expect(
      nextCombatState({
        currentActive: false,
        currentRound: 0,
        starting: true,
        requestedRound: null,
      }),
    ).toEqual({ active: true, round: 1 });
    expect(
      nextCombatState({
        currentActive: true,
        currentRound: 1,
        starting: true,
        requestedRound: null,
      }),
    ).toEqual({ active: true, round: 2 });
    expect(
      nextCombatState({
        currentActive: true,
        currentRound: 2,
        starting: true,
        requestedRound: 4,
      }).round,
    ).toBe(4);
    expect(
      nextCombatState({
        currentActive: true,
        currentRound: 3,
        starting: false,
        requestedRound: null,
      }),
    ).toEqual({ active: false, round: 3 });
    expect(combatContextFromRow(null)).toEqual({ active: false, round: 0 });
    expect(
      hasRequestRoll([
        { type: "start_combat" },
        { type: "request_roll" },
      ]),
    ).toBe(true);
  });

  test("parse finish game defaults and rejects unknown result", () => {
    expect(parseFinishGame({})).toEqual({
      result: "neutral",
      summary: "",
      epilogue: "",
    });
    expect(
      parseFinishGame({
        result: "draw",
        summary: "Le prince est a l abri.",
        epilogue: "La route se tait.",
      }).result,
    ).toBe("neutral");
    expect(parseFinishGame({ result: "VICTORY", summary: "ok" }).result).toBe(
      "victory",
    );
    expect(
      hasRequestRoll([{ type: "finish_game" }, { type: "request_roll" }]),
    ).toBe(true);
  });

  test("consume potion uses stock and default heal", () => {
    const withStock = consumePotion(
      [{ id: "potion", name: "Potion", type: "potion", quantity: 2 }],
      "potion",
    );
    expect(withStock.heal).toBe(20);
    expect(withStock.inventory[0]?.quantity).toBe(1);
    const empty = consumePotion(
      [{ id: "potion", name: "Potion", type: "weapon", quantity: 1 }],
      "potion",
    );
    expect(empty.heal).toBe(0);
    expect(empty.inventory).toHaveLength(1);
  });
});
