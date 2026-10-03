import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import type { MutationCtx } from "./_generated/server";
import { api } from "./_generated/api";
import schema from "./schema";
import { ForbiddenError } from "./lib/errors";

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
const carol = {
  subject: "user_01CAROL",
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

const clericSheet = {
  displayName: "Clara",
  classId: "cleric",
  strength: 10,
  dexterity: 8,
  constitution: 14,
  intelligence: 10,
  wisdom: 16,
  charisma: 12,
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

describe("reactive reads", () => {
  test("members can read their room; strangers cannot read private room data", async () => {
    const t = backend();
    const host = await provision(t, alice, fighterSheet);
    const guest = await provision(t, bob, wizardSheet);
    const stranger = await provision(t, carol, clericSheet);

    const roomA = await host.mutation(api.rooms.create, {
      name: "A",
      scenarioId: "custom",
      scenarioName: "A",
      minPlayers: 1,
      requiredClassIds: [],
      locale: "en",
    });
    const roomB = await guest.mutation(api.rooms.create, {
      name: "B",
      scenarioId: "custom",
      scenarioName: "B",
      minPlayers: 1,
      requiredClassIds: [],
      locale: "fr",
    });

    await host.mutation(api.players.join, {
      roomId: roomA!._id,
      figurineId: 1,
    });
    await guest.mutation(api.players.join, {
      roomId: roomB!._id,
      figurineId: 2,
    });

    const readableWaiting = await stranger.query(api.rooms.get, {
      roomId: roomA!._id,
    });
    expect(readableWaiting?._id).toEqual(roomA?._id);

    await host.mutation(api.rooms.start, { roomId: roomA!._id });
    await host.mutation(api.rooms.pause, { roomId: roomA!._id });
    await guest.mutation(api.rooms.start, { roomId: roomB!._id });

    await host.run(async (ctx: MutationCtx) => {
      await ctx.db.insert("gameEvents", {
        roomId: roomA!._id,
        type: "narration",
        content: "first",
        createdAt: 10,
      });
      await ctx.db.insert("gameEvents", {
        roomId: roomA!._id,
        type: "narration",
        content: "second",
        createdAt: 20,
      });
      await ctx.db.insert("gameEvents", {
        roomId: roomB!._id,
        type: "narration",
        content: "leak",
        createdAt: 15,
      });
    });

    const mine = await host.query(api.rooms.get, { roomId: roomA!._id });
    expect(mine?._id).toEqual(roomA?._id);

    await expect(
      stranger.query(api.rooms.get, { roomId: roomA!._id }),
    ).rejects.toBeInstanceOf(ForbiddenError);

    const playersA = await host.query(api.players.listByRoom, {
      roomId: roomA!._id,
    });
    expect(playersA.map((player) => player.roomId)).toEqual([roomA!._id]);

    await expect(
      stranger.query(api.players.listByRoom, { roomId: roomA!._id }),
    ).rejects.toBeInstanceOf(ForbiddenError);

    const eventsA = await host.query(api.gameEvents.listByRoom, {
      roomId: roomA!._id,
    });
    expect(eventsA.every((event) => event.roomId === roomA!._id)).toBe(true);
    expect(eventsA.some((event) => event.content === "leak")).toBe(false);
    const narrations = eventsA.filter((event) => event.type === "narration");
    expect(narrations.map((event) => event.content)).toEqual([
      "first",
      "second",
    ]);

    await expect(
      stranger.query(api.gameEvents.listByRoom, { roomId: roomA!._id }),
    ).rejects.toBeInstanceOf(ForbiddenError);

    await expect(
      host.query(api.gameEvents.listByRoom, { roomId: roomB!._id }),
    ).rejects.toBeInstanceOf(ForbiddenError);
    await expect(
      host.query(api.players.listByRoom, { roomId: roomB!._id }),
    ).rejects.toBeInstanceOf(ForbiddenError);
    await expect(
      host.query(api.enemies.listByRoom, { roomId: roomB!._id }),
    ).rejects.toBeInstanceOf(ForbiddenError);
  });

  test("listMineContinuable returns only the user's playing/paused rooms", async () => {
    const t = backend();
    const host = await provision(t, alice, fighterSheet);
    const guest = await provision(t, bob, wizardSheet);

    const waiting = await host.mutation(api.rooms.create, {
      name: "Waiting",
      scenarioId: "custom",
      scenarioName: "Waiting",
      minPlayers: 1,
      requiredClassIds: [],
    });
    const continuable = await host.mutation(api.rooms.create, {
      name: "Live",
      scenarioId: "custom",
      scenarioName: "Live",
      minPlayers: 1,
      requiredClassIds: [],
    });
    const other = await guest.mutation(api.rooms.create, {
      name: "Other",
      scenarioId: "custom",
      scenarioName: "Other",
      minPlayers: 1,
      requiredClassIds: [],
    });

    await host.mutation(api.players.join, {
      roomId: continuable!._id,
      figurineId: 1,
    });
    await guest.mutation(api.players.join, {
      roomId: other!._id,
      figurineId: 2,
    });
    await host.mutation(api.rooms.start, { roomId: continuable!._id });
    await host.mutation(api.rooms.pause, { roomId: continuable!._id });
    await guest.mutation(api.rooms.start, { roomId: other!._id });

    const mine = await host.query(api.rooms.listMineContinuable, {});
    expect(mine.map((room) => room._id)).toEqual([continuable!._id]);
    expect(mine.some((room) => room._id === waiting?._id)).toBe(false);
    expect(mine.some((room) => room._id === other?._id)).toBe(false);

    const guestMine = await guest.query(api.rooms.listMineContinuable, {});
    expect(guestMine.map((room) => room._id)).toEqual([other!._id]);
  });
});
