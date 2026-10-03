import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import type { MutationCtx } from "./_generated/server";
import { api } from "./_generated/api";
import schema from "./schema";
import { InvalidProfileError } from "./profiles";
import { UserNotFoundError } from "./lib/auth";

const modules = import.meta.glob("./**/*.ts");

function backend() {
  return convexTest(schema, modules);
}

const identity = {
  subject: "user_01ALICE",
  issuer: "https://api.workos.com/user_management/client_01EXAMPLE",
};

describe("profiles", () => {
  test("upserts and reads the authenticated user's profile without a client userId", async () => {
    const t = backend();
    const authed = t.withIdentity(identity);
    await authed.mutation(api.users.ensureUser, {});
    expect(await authed.query(api.profiles.getMine, {})).toBeNull();

    const created = await authed.mutation(api.profiles.upsertDisplayName, {
      displayName: "  Aldric  ",
    });
    expect(created?.displayName).toBe("Aldric");
    expect(created?.sheetConfirmed).toBe(false);
    expect(created?.strength).toBe(10);

    const mined = await authed.query(api.profiles.getMine, {});
    expect(mined?._id).toEqual(created?._id);

    const updated = await authed.mutation(api.profiles.upsertDisplayName, {
      displayName: "Aldric le Sage",
    });
    expect(updated?._id).toEqual(created?._id);
    expect(updated?.displayName).toBe("Aldric le Sage");

    const sheet = await authed.mutation(api.profiles.upsertSheet, {
      displayName: "Aldric le Sage",
      classId: "fighter",
      strength: 16,
      dexterity: 10,
      constitution: 14,
      intelligence: 8,
      wisdom: 12,
      charisma: 10,
    });
    expect(sheet?._id).toEqual(created?._id);
    expect(sheet?.classId).toBe("fighter");
    expect(sheet?.sheetConfirmed).toBe(true);
    expect(sheet?.strength).toBe(16);

    const withAvatar = await authed.mutation(api.profiles.upsertAvatar, {
      figurineId: 3,
    });
    expect(withAvatar?._id).toEqual(created?._id);
    expect(withAvatar?.avatarFigurineId).toBe(3);

    await authed.run(async (ctx: MutationCtx) => {
      expect(await ctx.db.query("profiles").collect()).toHaveLength(1);
    });
  });

  test("rejects profile writes before ensureUser", async () => {
    const t = backend();
    await expect(
      t.withIdentity(identity).mutation(api.profiles.upsertDisplayName, {
        displayName: "Aldric",
      }),
    ).rejects.toBeInstanceOf(UserNotFoundError);
  });

  test("rejects invalid display name, class, stats, and avatar", async () => {
    const t = backend();
    const authed = t.withIdentity(identity);
    await authed.mutation(api.users.ensureUser, {});

    await expect(
      authed.mutation(api.profiles.upsertDisplayName, { displayName: "A" }),
    ).rejects.toBeInstanceOf(InvalidProfileError);

    await expect(
      authed.mutation(api.profiles.upsertSheet, {
        displayName: "Aldric",
        classId: "jedi",
        strength: 16,
        dexterity: 10,
        constitution: 14,
        intelligence: 8,
        wisdom: 12,
        charisma: 10,
      }),
    ).rejects.toBeInstanceOf(InvalidProfileError);

    await expect(
      authed.mutation(api.profiles.upsertSheet, {
        displayName: "Aldric",
        classId: "fighter",
        strength: 7,
        dexterity: 10,
        constitution: 14,
        intelligence: 8,
        wisdom: 12,
        charisma: 10,
      }),
    ).rejects.toBeInstanceOf(InvalidProfileError);

    await authed.mutation(api.profiles.upsertDisplayName, {
      displayName: "Aldric",
    });
    await expect(
      authed.mutation(api.profiles.upsertAvatar, { figurineId: 40 }),
    ).rejects.toBeInstanceOf(InvalidProfileError);
  });
});
