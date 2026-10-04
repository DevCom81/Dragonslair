// @vitest-environment node
import { describe, expect, test, vi } from "vitest";
import type { MigrationBundle, SanitizedAuthUser, WorkosMapping } from "./types";
import {
  createMissingWorkosUsers,
  formatWorkosCreateReport,
} from "./workosCreate";
import { createWorkosEmailLookup, createWorkosUser, WORKOS_USERS_URL } from "./workosLookup";
import { WorkosMapError } from "./workosMap";

const A = "11111111-1111-4111-8111-111111111111";
const B = "22222222-2222-4222-8222-222222222222";

function authUser(
  id: string,
  args: Partial<SanitizedAuthUser> = {},
): SanitizedAuthUser {
  return {
    id,
    email: null,
    is_anonymous: true,
    created_at: "2026-01-01T00:00:00.000Z",
    email_confirmed_at: null,
    deleted_at: null,
    ...args,
  };
}

function emptyBundle(users: SanitizedAuthUser[]): MigrationBundle {
  return {
    manifest: { version: "lot12-b1", exported_at: "2026-01-01T00:00:00.000Z", table_counts: {} },
    auth_users: users,
    profiles: [],
    entitlement_sources: [],
    user_entitlements: [],
    rooms: [],
    players: [],
    room_gm_state: [],
    game_events: [],
    enemies: [],
    combat_sessions: [],
    pending_rolls: [],
    demo_sessions: [],
    ai_usage_events: [],
  };
}

function passMapping(
  entries: WorkosMapping["entries"],
): WorkosMapping {
  return {
    version: "lot12-b3",
    generated_at: "2026-01-01T00:00:00.000Z",
    verdict: "WORKOS_MAP_PASS",
    entries,
    findings: [],
  };
}

const alice = authUser(A, {
  email: "alice@example.com",
  is_anonymous: false,
  email_confirmed_at: "2026-01-01T00:00:00.000Z",
});
const bob = authUser(B, { email: "bob@example.com", is_anonymous: false });

function notFoundMapping(): WorkosMapping {
  return passMapping([
    {
      legacy_user_id: A,
      email: "alice@example.com",
      status: "NOT_FOUND",
      workos_user_id: null,
    },
    {
      legacy_user_id: B,
      email: "bob@example.com",
      status: "NOT_FOUND",
      workos_user_id: null,
    },
  ]);
}

describe("LOT 12 B3 WorkOS create", () => {
  test("NOT_FOUND with empty recheck issues one POST create", async () => {
    const lookup = vi.fn(async () => [] as string[]);
    const createUser = vi.fn(async () => ({
      kind: "created" as const,
      id: "user_01ALICE",
      status: 201,
    }));
    const report = await createMissingWorkosUsers({
      bundle: emptyBundle([alice]),
      mapping: passMapping([
        {
          legacy_user_id: A,
          email: "alice@example.com",
          status: "NOT_FOUND",
          workos_user_id: null,
        },
      ]),
      lookup,
      createUser,
    });
    expect(createUser).toHaveBeenCalledTimes(1);
    expect(report.created).toBe(1);
    expect(report.verdict).toBe("WORKOS_CREATE_PASS");
    expect(report.mapping.entries[0]?.status).toBe("EXISTING_WORKOS_USER");
    expect(report.mapping.entries[0]?.workos_user_id).toBe("user_01ALICE");
  });

  test("recheck finds user and skips POST", async () => {
    const lookup = vi.fn(async () => ["user_01ALREADY"]);
    const createUser = vi.fn(async () => ({
      kind: "created" as const,
      id: "user_01NEW",
      status: 201,
    }));
    const report = await createMissingWorkosUsers({
      bundle: emptyBundle([alice]),
      mapping: passMapping([
        {
          legacy_user_id: A,
          email: "alice@example.com",
          status: "NOT_FOUND",
          workos_user_id: null,
        },
      ]),
      lookup,
      createUser,
    });
    expect(createUser).not.toHaveBeenCalled();
    expect(report.already_existed).toBe(1);
    expect(report.created).toBe(0);
    expect(report.mapping.entries[0]?.workos_user_id).toBe("user_01ALREADY");
  });

  test("recheck ambiguity BLOCKED with no POST", async () => {
    const lookup = vi.fn(async () => ["user_01A", "user_01B"]);
    const createUser = vi.fn(async () => ({
      kind: "created" as const,
      id: "user_01NEW",
      status: 201,
    }));
    const report = await createMissingWorkosUsers({
      bundle: emptyBundle([alice, bob]),
      mapping: notFoundMapping(),
      lookup,
      createUser,
    });
    expect(createUser).not.toHaveBeenCalled();
    expect(report.blocked).toBe(1);
    expect(report.verdict).toBe("WORKOS_CREATE_BLOCKED");
    expect(report.created).toBe(0);
  });

  test("inconsistent mapping issues no write calls", async () => {
    const lookup = vi.fn(async () => [] as string[]);
    const createUser = vi.fn(async () => ({
      kind: "created" as const,
      id: "user_01NEW",
      status: 201,
    }));
    await expect(
      createMissingWorkosUsers({
        bundle: emptyBundle([alice]),
        mapping: passMapping([
          {
            legacy_user_id: B,
            email: "bob@example.com",
            status: "NOT_FOUND",
            workos_user_id: null,
          },
        ]),
        lookup,
        createUser,
      }),
    ).rejects.toBeInstanceOf(WorkosMapError);
    expect(lookup).not.toHaveBeenCalled();
    expect(createUser).not.toHaveBeenCalled();
  });

  test("duplicate email in mapping issues no POST", async () => {
    const lookup = vi.fn(async () => [] as string[]);
    const createUser = vi.fn(async () => ({
      kind: "created" as const,
      id: "user_01NEW",
      status: 201,
    }));
    await expect(
      createMissingWorkosUsers({
        bundle: emptyBundle([
          alice,
          authUser(B, { email: "alice@example.com", is_anonymous: false }),
        ]),
        mapping: notFoundMapping(),
        lookup,
        createUser,
      }),
    ).rejects.toMatchObject({ code: "DUPLICATE_NORMALIZED_EMAIL" });
    expect(createUser).not.toHaveBeenCalled();
  });

  test("duplicate legacyUuid issues no POST", async () => {
    const lookup = vi.fn(async () => [] as string[]);
    const createUser = vi.fn(async () => ({
      kind: "created" as const,
      id: "user_01NEW",
      status: 201,
    }));
    await expect(
      createMissingWorkosUsers({
        bundle: emptyBundle([alice, { ...alice }]),
        mapping: passMapping([
          {
            legacy_user_id: A,
            email: "alice@example.com",
            status: "NOT_FOUND",
            workos_user_id: null,
          },
        ]),
        lookup,
        createUser,
      }),
    ).rejects.toMatchObject({ code: "DUPLICATE_LEGACY_UUID" });
    expect(createUser).not.toHaveBeenCalled();
  });

  test("rerun after create uses GET and does not POST again", async () => {
    const created = new Set<string>();
    const lookup = vi.fn(async (email: string) =>
      created.has(email) ? ["user_01ALICE"] : [],
    );
    const createUser = vi.fn(async (input: { email: string }) => {
      created.add(input.email);
      return { kind: "created" as const, id: "user_01ALICE", status: 201 };
    });
    const first = await createMissingWorkosUsers({
      bundle: emptyBundle([alice]),
      mapping: passMapping([
        {
          legacy_user_id: A,
          email: "alice@example.com",
          status: "NOT_FOUND",
          workos_user_id: null,
        },
      ]),
      lookup,
      createUser,
    });
    expect(createUser).toHaveBeenCalledTimes(1);
    const second = await createMissingWorkosUsers({
      bundle: emptyBundle([alice]),
      mapping: first.mapping,
      lookup,
      createUser,
    });
    expect(createUser).toHaveBeenCalledTimes(1);
    expect(second.created).toBe(0);
    expect(second.already_existed).toBe(0);
    expect(second.mapping.entries[0]?.status).toBe("EXISTING_WORKOS_USER");
  });

  test("successful POST stores WorkOS id in mapping", async () => {
    const report = await createMissingWorkosUsers({
      bundle: emptyBundle([alice]),
      mapping: passMapping([
        {
          legacy_user_id: A,
          email: "alice@example.com",
          status: "NOT_FOUND",
          workos_user_id: null,
        },
      ]),
      lookup: async () => [],
      createUser: async () => ({ kind: "created", id: "user_01STORED", status: 201 }),
    });
    expect(report.mapping.entries[0]?.workos_user_id).toBe("user_01STORED");
  });

  test("ambiguous POST reconciles with GET before any new create", async () => {
    let posted = false;
    const lookup = vi.fn(async () => (posted ? ["user_01RECON"] : []));
    const createUser = vi.fn(async () => {
      posted = true;
      return { kind: "ambiguous" as const, status: 500 };
    });
    const report = await createMissingWorkosUsers({
      bundle: emptyBundle([alice]),
      mapping: passMapping([
        {
          legacy_user_id: A,
          email: "alice@example.com",
          status: "NOT_FOUND",
          workos_user_id: null,
        },
      ]),
      lookup,
      createUser,
    });
    expect(createUser).toHaveBeenCalledTimes(1);
    expect(lookup).toHaveBeenCalledTimes(2);
    expect(report.already_existed).toBe(1);
    expect(report.mapping.entries[0]?.workos_user_id).toBe("user_01RECON");
  });

  test("WorkOS POST body has email only, never a password hash", async () => {
    type FetchMock = (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>;
    const fetchImpl = vi.fn<FetchMock>(async (input, init) => {
      if (init?.method === "POST") {
        return new Response(
          JSON.stringify({ id: "user_01ALICE", email: "alice@example.com" }),
          { status: 201 },
        );
      }
      return new Response(JSON.stringify({ data: [] }), { status: 200 });
    });
    const lookup = createWorkosEmailLookup(fetchImpl, "test-key");
    const createUser = createWorkosUser(fetchImpl, "test-key");
    await createMissingWorkosUsers({
      bundle: emptyBundle([alice]),
      mapping: passMapping([
        {
          legacy_user_id: A,
          email: "alice@example.com",
          status: "NOT_FOUND",
          workos_user_id: null,
        },
      ]),
      lookup,
      createUser,
    });
    const post = fetchImpl.mock.calls.find((call) => call[1]?.method === "POST");
    expect(post).toBeTruthy();
    expect(String(post?.[0])).toBe(WORKOS_USERS_URL);
    const body = JSON.parse(String(post?.[1]?.body ?? "{}")) as Record<string, unknown>;
    expect(Object.keys(body).sort()).toEqual(["email", "email_verified"]);
    expect(body.password).toBeUndefined();
    expect(body.password_hash).toBeUndefined();
    expect(JSON.stringify(body)).not.toContain("encrypted");
  });

  test("terminal report has no email or API key", async () => {
    const report = await createMissingWorkosUsers({
      bundle: emptyBundle([alice]),
      mapping: passMapping([
        {
          legacy_user_id: A,
          email: "alice@example.com",
          status: "NOT_FOUND",
          workos_user_id: null,
        },
      ]),
      lookup: async () => [],
      createUser: async () => ({ kind: "created", id: "user_01ALICE", status: 201 }),
    });
    const text = formatWorkosCreateReport(report);
    expect(text).not.toMatch(/@/);
    expect(text).not.toContain("example.com");
    expect(text).not.toContain("test-key");
    expect(text).toContain("CREATED: 1");
  });

  test("remote writes are only the expected WorkOS POST", async () => {
    type FetchMock = (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>;
    const fetchImpl = vi.fn<FetchMock>(async (_input, init) => {
      if (init?.method === "POST") {
        return new Response(
          JSON.stringify({ id: "user_01ALICE", email: "alice@example.com" }),
          { status: 201 },
        );
      }
      return new Response(JSON.stringify({ data: [] }), { status: 200 });
    });
    await createMissingWorkosUsers({
      bundle: emptyBundle([alice]),
      mapping: passMapping([
        {
          legacy_user_id: A,
          email: "alice@example.com",
          status: "NOT_FOUND",
          workos_user_id: null,
        },
      ]),
      lookup: createWorkosEmailLookup(fetchImpl, "test-key"),
      createUser: createWorkosUser(fetchImpl, "test-key"),
    });
    const methods = fetchImpl.mock.calls.map((call) => call[1]?.method ?? "GET");
    expect(methods).toEqual(["GET", "POST"]);
    expect(methods).not.toContain("PUT");
    expect(methods).not.toContain("PATCH");
    expect(methods).not.toContain("DELETE");
  });
});
