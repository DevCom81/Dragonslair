import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import type { MutationCtx } from "./_generated/server";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { ForbiddenError, GameRuleError } from "./lib/errors";

const modules = import.meta.glob("./**/*.ts");

function backend() {
  return convexTest(schema, modules);
}

const alice = {
  subject: "user_01ALICE",
  issuer: "https://api.workos.com/user_management/client_01EXAMPLE",
};
const bob = {
  subject: "user_01BOB",
  issuer: "https://api.workos.com/user_management/client_01EXAMPLE",
};

const fighterSheet = {
  displayName: "Aldric",
  classId: "fighter",
  strength: 16,
  dexterity: 10,
  constitution: 14,
  intelligence: 8,
  wisdom: 12,
  charisma: 10,
};

const wizardSheet = {
  displayName: "Myrddin",
  classId: "wizard",
  strength: 8,
  dexterity: 10,
  constitution: 12,
  intelligence: 16,
  wisdom: 14,
  charisma: 10,
};

async function grantFull(
  t: ReturnType<typeof backend>,
  identity: typeof alice,
) {
  await t.withIdentity(identity).run(async (ctx: MutationCtx) => {
    const users = await ctx.db.query("users").collect();
    const user = users.find((row) => row.workosSubject === identity.subject);
    const entitlements = await ctx.db
      .query("userEntitlements")
      .withIndex("by_user", (q) => q.eq("userId", user!._id))
      .collect();
    await ctx.db.patch(entitlements[0]!._id, {
      accessLevel: "full",
      source: "admin",
    });
  });
}

async function provision(
  t: ReturnType<typeof backend>,
  identity: typeof alice,
  sheet: typeof fighterSheet,
) {
  const authed = t.withIdentity(identity);
  await authed.mutation(api.users.ensureUser, {});
  await grantFull(t, identity);
  await authed.mutation(api.profiles.upsertSheet, sheet);
  return authed;
}

async function playingRoom(t: ReturnType<typeof backend>) {
  const host = await provision(t, alice, fighterSheet);
  const guest = await provision(t, bob, wizardSheet);
  const room = await host.mutation(api.rooms.create, {
    name: "Intents",
    scenarioId: "custom",
    scenarioName: "Intents",
    minPlayers: 1,
    requiredClassIds: [],
    locale: "en",
  });
  const alicePlayer = await host.mutation(api.players.join, {
    roomId: room!._id,
    figurineId: 1,
  });
  const bobPlayer = await guest.mutation(api.players.join, {
    roomId: room!._id,
    figurineId: 2,
  });
  await host.mutation(api.rooms.start, { roomId: room!._id });
  return {
    host,
    guest,
    room: room!,
    alicePlayer: alicePlayer!,
    bobPlayer: bobPlayer!,
  };
}

describe("LOT 13D.0 player intents", () => {
  test("updatePosition moves the authenticated player only and rejects paused rooms", async () => {
    const t = backend();
    const a = await playingRoom(t);
    const moved = await a.host.mutation(api.players.updatePosition, {
      roomId: a.room._id,
      x: 0.2,
      y: 1.4,
    });
    expect(moved?.positionX).toBe(0.2);
    expect(moved?.positionY).toBe(1);
    expect(moved?._id).toEqual(a.alicePlayer._id);

    const players = await a.host.query(api.players.listByRoom, {
      roomId: a.room._id,
    });
    const bob = players.find((row) => row._id === a.bobPlayer._id);
    expect(bob?.positionX).toBe(0.5);
    expect(bob?.positionY).toBe(0.5);

    await a.host.mutation(api.rooms.pause, { roomId: a.room._id });
    await expect(
      a.host.mutation(api.players.updatePosition, {
        roomId: a.room._id,
        x: 0.1,
        y: 0.1,
      }),
    ).rejects.toBeInstanceOf(GameRuleError);

    const outsider = await provision(t, { ...alice, subject: "user_01OUT" }, fighterSheet);
    await a.host.mutation(api.rooms.resume, { roomId: a.room._id });
    await expect(
      outsider.mutation(api.players.updatePosition, {
        roomId: a.room._id,
        x: 0.9,
        y: 0.9,
      }),
    ).rejects.toBeInstanceOf(ForbiddenError);
  });

  test("setItemEquipped and useScroll are own-player atomic and write one system event", async () => {
    const t = backend();
    const a = await playingRoom(t);
    await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: a.room._id,
      actions: [
        {
          type: "give_item",
          payload: {
            player_id: a.alicePlayer._id,
            item: { id: "sword", name: "Epee", type: "weapon" },
          },
        },
        {
          type: "give_item",
          payload: {
            player_id: a.alicePlayer._id,
            item: {
              id: "scroll",
              name: "Parchemin",
              type: "scroll",
              effect: { id: "bless", name: "Bless", kind: "buff", stat: "strength", delta: 1 },
            },
          },
        },
      ],
    });

    await expect(
      a.guest.mutation(api.players.setItemEquipped, {
        roomId: a.room._id,
        itemId: "sword",
        equipped: true,
      }),
    ).resolves.toMatchObject({ _id: a.bobPlayer._id });

    const equipped = await a.host.mutation(api.players.setItemEquipped, {
      roomId: a.room._id,
      itemId: "sword",
      equipped: true,
    });
    const sword = (equipped?.inventory as Array<{ id: string; equipped: boolean }>).find(
      (item) => item.id === "sword",
    );
    expect(sword?.equipped).toBe(true);

    const scrolled = await a.host.mutation(api.players.useScroll, {
      roomId: a.room._id,
      itemId: "scroll",
    });
    expect(scrolled?.inventory).toEqual(
      expect.arrayContaining([expect.objectContaining({ id: "sword" })]),
    );
    expect(scrolled?.effects).toEqual(
      expect.arrayContaining([expect.objectContaining({ id: "bless" })]),
    );

    await expect(
      a.guest.mutation(api.players.useScroll, {
        roomId: a.room._id,
        itemId: "scroll",
      }),
    ).rejects.toBeInstanceOf(GameRuleError);

    const events = await a.host.query(api.gameEvents.listByRoom, {
      roomId: a.room._id,
    });
    const system = events.filter((row) => row.type === "system");
    expect(system.some((row) => row.content.includes("Equip"))).toBe(true);
    expect(system.some((row) => row.content.includes("Bless"))).toBe(true);
  });

  test("submitAction and announceDice write action events for the caller only", async () => {
    const t = backend();
    const a = await playingRoom(t);
    const submitted = await a.host.mutation(api.players.submitAction, {
      roomId: a.room._id,
      content: "ouvre la porte",
    });
    expect(submitted.playerId).toEqual(a.alicePlayer._id);

    await a.host.mutation(api.players.announceDice, {
      roomId: a.room._id,
      sides: 20,
      raw: 17,
    });
    await expect(
      a.host.mutation(api.players.announceDice, {
        roomId: a.room._id,
        sides: 12,
        raw: 4,
      }),
    ).rejects.toBeInstanceOf(GameRuleError);

    const events = await a.host.query(api.gameEvents.listByRoom, {
      roomId: a.room._id,
    });
    expect(events.some((row) => row.type === "action" && row.content.includes("ouvre la porte"))).toBe(
      true,
    );
    expect(events.some((row) => row.type === "action" && row.content.includes("1d20"))).toBe(
      true,
    );
    expect(events.every((row) => row.playerId !== a.bobPlayer._id)).toBe(true);
  });

  test("usePotion remains atomic and does not duplicate events on empty stock", async () => {
    const t = backend();
    const a = await playingRoom(t);
    await t.mutation(internal.applyActions.applyGameMasterActions, {
      roomId: a.room._id,
      actions: [
        {
          type: "damage_player",
          payload: { player_id: a.alicePlayer._id, amount: 40 },
        },
        {
          type: "give_item",
          payload: {
            player_id: a.alicePlayer._id,
            item: { id: "potion", name: "Potion", type: "potion", heal: 20 },
          },
        },
      ],
    });
    await a.host.mutation(api.players.usePotion, {
      roomId: a.room._id,
      itemId: "potion",
    });
    await a.host.mutation(api.players.usePotion, {
      roomId: a.room._id,
      itemId: "potion",
    });
    const players = await a.host.query(api.players.listByRoom, {
      roomId: a.room._id,
    });
    expect(players.find((row) => row._id === a.alicePlayer._id)?.hp).toBe(80);
    const events = await a.host.query(api.gameEvents.listByRoom, {
      roomId: a.room._id,
    });
    expect(
      events.filter((row) => row.content.includes("Potion")),
    ).toHaveLength(1);
  });
});
