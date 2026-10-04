import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import type { MutationCtx } from "./_generated/server";
import { api } from "./_generated/api";
import schema from "./schema";
import { ForbiddenError } from "./lib/errors";
import { GameRuleError } from "./lib/errors";

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

async function grantFull(t: ReturnType<typeof backend>, identity: typeof alice) {
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
  full: boolean,
) {
  const authed = t.withIdentity(identity);
  await authed.mutation(api.users.ensureUser, {});
  if (full) {
    await grantFull(t, identity);
  }
  await authed.mutation(api.profiles.upsertSheet, sheet);
  return authed;
}

describe("rooms.create", () => {
  test("demo user can create a demo room as host without a client userId", async () => {
    const t = backend();
    const authed = await provision(t, alice, fighterSheet, false);
    const room = await authed.mutation(api.rooms.create, {
      name: "Demo",
      scenarioId: "demo",
      scenarioName: "Demo",
      minPlayers: 1,
      requiredClassIds: [],
      locale: "fr",
    });
    expect(room?.status).toBe("waiting");
    expect(room?.hostUserId).toBeDefined();
    expect(room?.joinCode).toHaveLength(6);
    const me = await authed.query(api.users.me, {});
    expect(room?.hostUserId).toEqual(me?._id);

    await authed.run(async (ctx: MutationCtx) => {
      const sessions = await ctx.db.query("demoSessions").collect();
      expect(sessions).toHaveLength(1);
      expect(sessions[0]?.userId).toEqual(me?._id);
      expect(sessions[0]?.startedAt).toBeUndefined();
      expect(sessions[0]?.expiresAt).toBeUndefined();
      expect(sessions[0]?.pausedAt).toBeUndefined();
      expect(sessions[0]?.completedAt).toBeUndefined();
    });
  });

  test("demo user cannot create a non-demo room", async () => {
    const t = backend();
    const authed = await provision(t, alice, fighterSheet, false);
    await expect(
      authed.mutation(api.rooms.create, {
        name: "Donjon",
        scenarioId: "dungeon",
        scenarioName: "Donjon",
        minPlayers: 3,
        requiredClassIds: ["cleric"],
      }),
    ).rejects.toBeInstanceOf(GameRuleError);
  });
});

describe("players.join", () => {
  test("join waiting room, reject non-waiting, duplicates, figurine, class, and bad code", async () => {
    const t = backend();
    const host = await provision(t, alice, fighterSheet, true);
    const otherFighter = await provision(t, bob, {
      ...fighterSheet,
      displayName: "Borin",
    }, true);
    const wizard = {
      subject: "user_01WIZ",
      issuer: alice.issuer,
    };
    const guest = await provision(t, wizard, wizardSheet, true);
    const room = await host.mutation(api.rooms.create, {
      name: "Tavern",
      scenarioId: "custom",
      scenarioName: "Aventure",
      minPlayers: 1,
      requiredClassIds: [],
    });

    const first = await host.mutation(api.players.join, {
      roomId: room!._id,
      figurineId: 1,
    });
    const again = await host.mutation(api.players.join, {
      roomId: room!._id,
      figurineId: 2,
    });
    expect(again?._id).toEqual(first?._id);

    await expect(
      otherFighter.mutation(api.players.join, {
        roomId: room!._id,
        figurineId: 1,
      }),
    ).rejects.toBeInstanceOf(GameRuleError);

    await expect(
      otherFighter.mutation(api.players.join, {
        roomId: room!._id,
        figurineId: 2,
      }),
    ).rejects.toBeInstanceOf(GameRuleError);

    const guestPlayer = await guest.mutation(api.players.joinByCode, {
      joinCode: room!.joinCode,
      figurineId: 3,
    });
    expect(guestPlayer?.classId).toBe("wizard");

    await expect(
      guest.mutation(api.players.joinByCode, {
        joinCode: "NOPE!!",
        figurineId: 4,
      }),
    ).rejects.toBeInstanceOf(GameRuleError);

    await host.mutation(api.rooms.start, { roomId: room!._id });
    const carol = {
      subject: "user_01CAROL",
      issuer: alice.issuer,
    };
    const late = await provision(
      t,
      carol,
      { ...wizardSheet, displayName: "Carol", classId: "cleric" },
      true,
    );
    await expect(
      late.mutation(api.players.join, {
        roomId: room!._id,
        figurineId: 5,
      }),
    ).rejects.toBeInstanceOf(GameRuleError);
  });
});

describe("rooms start/pause/resume", () => {
  test("host can start/pause/resume; non-host cannot; start checks min players", async () => {
    const t = backend();
    const host = await provision(t, alice, fighterSheet, true);
    const guest = await provision(t, bob, wizardSheet, true);
    const room = await host.mutation(api.rooms.create, {
      name: "Siege",
      scenarioId: "siege",
      scenarioName: "Siege",
      minPlayers: 2,
      requiredClassIds: ["fighter", "wizard"],
    });

    await expect(
      host.mutation(api.rooms.start, { roomId: room!._id }),
    ).rejects.toBeInstanceOf(GameRuleError);

    await host.mutation(api.players.join, {
      roomId: room!._id,
      figurineId: 1,
    });
    await expect(
      host.mutation(api.rooms.start, { roomId: room!._id }),
    ).rejects.toBeInstanceOf(GameRuleError);

    await guest.mutation(api.players.join, {
      roomId: room!._id,
      figurineId: 2,
    });

    await expect(
      guest.mutation(api.rooms.start, { roomId: room!._id }),
    ).rejects.toBeInstanceOf(ForbiddenError);

    const started = await host.mutation(api.rooms.start, { roomId: room!._id });
    expect(started?.status).toBe("playing");
    expect(started?.gamePhase).toBe("exploration");

    await expect(
      guest.mutation(api.rooms.pause, { roomId: room!._id }),
    ).rejects.toBeInstanceOf(ForbiddenError);

    const paused = await host.mutation(api.rooms.pause, { roomId: room!._id });
    expect(paused?.status).toBe("paused");
    await host.run(async (ctx: MutationCtx) => {
      const events = await ctx.db
        .query("gameEvents")
        .withIndex("by_room", (q) => q.eq("roomId", room!._id))
        .collect();
      expect(events).toHaveLength(1);
      expect(events[0]?.type).toBe("system");
    });

    await expect(
      guest.mutation(api.rooms.resume, { roomId: room!._id }),
    ).rejects.toBeInstanceOf(ForbiddenError);

    const resumed = await host.mutation(api.rooms.resume, { roomId: room!._id });
    expect(resumed?.status).toBe("playing");
    await host.run(async (ctx: MutationCtx) => {
      const events = await ctx.db
        .query("gameEvents")
        .withIndex("by_room", (q) => q.eq("roomId", room!._id))
        .collect();
      expect(events).toHaveLength(1);
    });
  });
});

describe("rooms.finish", () => {
  test("host can finish playing or paused; non-host cannot; waiting rejected; closed is idempotent", async () => {
    const t = backend();
    const host = await provision(t, alice, fighterSheet, true);
    const guest = await provision(t, bob, wizardSheet, true);
    const room = await host.mutation(api.rooms.create, {
      name: "Finale",
      scenarioId: "custom",
      scenarioName: "Finale",
      minPlayers: 1,
      requiredClassIds: [],
      locale: "fr",
    });
    await host.mutation(api.players.join, {
      roomId: room!._id,
      figurineId: 1,
    });

    await expect(
      host.mutation(api.rooms.finish, { roomId: room!._id, result: "victory" }),
    ).rejects.toBeInstanceOf(GameRuleError);

    await host.mutation(api.rooms.start, { roomId: room!._id });
    await expect(
      guest.mutation(api.rooms.finish, { roomId: room!._id, result: "defeat" }),
    ).rejects.toBeInstanceOf(ForbiddenError);

    const finished = await host.mutation(api.rooms.finish, {
      roomId: room!._id,
      result: "victory",
    });
    expect(finished?.status).toBe("finished");
    expect((finished?.ending as { result: string }).result).toBe("victory");
    await host.run(async (ctx: MutationCtx) => {
      const events = await ctx.db
        .query("gameEvents")
        .withIndex("by_room", (q) => q.eq("roomId", room!._id))
        .collect();
      expect(events).toHaveLength(1);
      expect(events[0]?.type).toBe("system");
      expect(events[0]?.content).toContain("victory");
    });

    const again = await host.mutation(api.rooms.finish, {
      roomId: room!._id,
      result: "defeat",
    });
    expect(again?.status).toBe("finished");
    expect((again?.ending as { result: string }).result).toBe("victory");
    await host.run(async (ctx: MutationCtx) => {
      const events = await ctx.db
        .query("gameEvents")
        .withIndex("by_room", (q) => q.eq("roomId", room!._id))
        .collect();
      expect(events).toHaveLength(1);
    });
  });

  test("demo host finish marks demo_finished and completes the demo session", async () => {
    const t = backend();
    const host = await provision(t, alice, fighterSheet, false);
    const room = await host.mutation(api.rooms.create, {
      name: "Demo",
      scenarioId: "demo",
      scenarioName: "Demo",
      minPlayers: 1,
      requiredClassIds: [],
    });
    await host.mutation(api.players.join, {
      roomId: room!._id,
      figurineId: 1,
    });
    await host.mutation(api.rooms.start, { roomId: room!._id });
    const finished = await host.mutation(api.rooms.finish, {
      roomId: room!._id,
    });
    expect(finished?.status).toBe("demo_finished");
    expect((finished?.ending as { result: string }).result).toBe("neutral");
    await host.run(async (ctx: MutationCtx) => {
      const sessions = await ctx.db.query("demoSessions").collect();
      expect(sessions[0]?.completedAt).toBeDefined();
    });
  });
});
