// @vitest-environment node
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, test, vi } from "vitest";
import type { MigrationBundle, SanitizedAuthUser } from "./types";
import { buildWorkosMapping, formatWorkosMapReport, WorkosMapError } from "./workosMap";
import { createWorkosEmailLookup, WORKOS_USERS_URL } from "./workosLookup";
import { WORKOS_MAPPING_FILENAME, writeWorkosMapping } from "./writeWorkosMapping";

const A = "11111111-1111-4111-8111-111111111111";
const B = "22222222-2222-4222-8222-222222222222";
const C = "33333333-3333-4333-8333-333333333333";
const D = "44444444-4444-4444-8444-444444444444";
const ANON = "55555555-5555-4555-8555-555555555555";

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

function fourEmailUsers(): SanitizedAuthUser[] {
  return [
    authUser(A, { email: "Alice@Example.com", is_anonymous: false }),
    authUser(B, { email: "bob@example.com", is_anonymous: false }),
    authUser(C, { email: "cara@example.com", is_anonymous: false }),
    authUser(D, { email: "dan@example.com", is_anonymous: false }),
    authUser(ANON),
  ];
}

const tempDirs: string[] = [];

afterEach(() => {
  while (tempDirs.length > 0) {
    const dir = tempDirs.pop();
    if (dir) {
      rmSync(dir, { recursive: true, force: true });
    }
  }
});

describe("LOT 12 B3 WorkOS mapping", () => {
  test("four unique emails produce a deterministic mapping", async () => {
    const lookup = vi.fn(async (email: string) => {
      const ids: Record<string, string> = {
        "alice@example.com": "user_01ALICE",
        "bob@example.com": "user_01BOB",
        "cara@example.com": "user_01CARA",
        "dan@example.com": "user_01DAN",
      };
      return ids[email] ? [ids[email]] : [];
    });
    const first = await buildWorkosMapping(emptyBundle(fourEmailUsers()), lookup);
    expect(first.verdict).toBe("WORKOS_MAP_PASS");
    expect(first.entries.map((row) => row.legacy_user_id)).toEqual([A, B, C, D]);
    expect(first.entries.map((row) => row.status)).toEqual([
      "EXISTING_WORKOS_USER",
      "EXISTING_WORKOS_USER",
      "EXISTING_WORKOS_USER",
      "EXISTING_WORKOS_USER",
    ]);
    const expectedLookupOrder = [
      "alice@example.com",
      "bob@example.com",
      "cara@example.com",
      "dan@example.com",
    ];
    expect(lookup.mock.calls.map((call) => call[0])).toEqual(expectedLookupOrder);
    lookup.mockClear();
    const second = await buildWorkosMapping(emptyBundle(fourEmailUsers()), lookup);
    expect(lookup.mock.calls.map((call) => call[0])).toEqual(expectedLookupOrder);
    expect(first.entries).toEqual(second.entries);
    expect(first.verdict).toBe(second.verdict);
    expect(first.findings).toEqual(second.findings);
  });

  test("NOT_FOUND when WorkOS has no user", async () => {
    const mapping = await buildWorkosMapping(emptyBundle(fourEmailUsers()), async () => []);
    expect(mapping.verdict).toBe("WORKOS_MAP_PASS");
    expect(mapping.entries.every((row) => row.status === "NOT_FOUND")).toBe(true);
    expect(mapping.entries.every((row) => row.workos_user_id === null)).toBe(true);
  });

  test("EXISTING_WORKOS_USER keeps the WorkOS id", async () => {
    const mapping = await buildWorkosMapping(
      emptyBundle([authUser(A, { email: "alice@example.com", is_anonymous: false })]),
      async () => ["user_01ALICE"],
    );
    expect(mapping.entries[0]).toMatchObject({
      legacy_user_id: A,
      status: "EXISTING_WORKOS_USER",
      workos_user_id: "user_01ALICE",
    });
  });

  test("WorkOS duplicate users BLOCKED", async () => {
    const lookup = vi.fn(async () => ["user_01A", "user_01B"]);
    const mapping = await buildWorkosMapping(
      emptyBundle([authUser(A, { email: "alice@example.com", is_anonymous: false })]),
      lookup,
    );
    expect(mapping.verdict).toBe("WORKOS_MAP_BLOCKED");
    expect(mapping.entries[0]?.status).toBe("AMBIGUOUS_WORKOS_USER");
    expect(mapping.entries[0]?.workos_user_id).toBeNull();
    expect(mapping.findings.some((item) => item.code === "AMBIGUOUS_WORKOS_USER")).toBe(
      true,
    );
  });

  test("duplicate normalized email in source BLOCKED before lookup", async () => {
    const lookup = vi.fn(async () => ["user_01A"]);
    await expect(
      buildWorkosMapping(
        emptyBundle([
          authUser(A, { email: "Alice@example.com", is_anonymous: false }),
          authUser(B, { email: "alice@example.com", is_anonymous: false }),
        ]),
        lookup,
      ),
    ).rejects.toBeInstanceOf(WorkosMapError);
    expect(lookup).not.toHaveBeenCalled();
  });

  test("same WorkOS id for two legacy users BLOCKED", async () => {
    const mapping = await buildWorkosMapping(
      emptyBundle([
        authUser(A, { email: "alice@example.com", is_anonymous: false }),
        authUser(B, { email: "bob@example.com", is_anonymous: false }),
      ]),
      async () => ["user_01SHARED"],
    );
    expect(mapping.verdict).toBe("WORKOS_MAP_BLOCKED");
    expect(mapping.findings.some((item) => item.code === "WORKOS_USER_SHARED")).toBe(
      true,
    );
    expect(mapping.entries.every((row) => row.workos_user_id === null)).toBe(true);
    expect(mapping.entries.every((row) => row.status === "AMBIGUOUS_WORKOS_USER")).toBe(
      true,
    );
  });

  test("duplicate legacy uuid BLOCKED before lookup", async () => {
    const lookup = vi.fn(async () => ["user_01A"]);
    const user = authUser(A, { email: "alice@example.com", is_anonymous: false });
    await expect(
      buildWorkosMapping(emptyBundle([user, { ...user }]), lookup),
    ).rejects.toMatchObject({ code: "DUPLICATE_LEGACY_UUID" });
    expect(lookup).not.toHaveBeenCalled();
  });

  test("terminal report never includes emails", async () => {
    const mapping = await buildWorkosMapping(
      emptyBundle(fourEmailUsers()),
      async (email) => (email === "alice@example.com" ? ["user_01ALICE"] : []),
    );
    const report = formatWorkosMapReport(mapping);
    expect(report).not.toMatch(/@/);
    expect(report).not.toContain("example.com");
    expect(report).toContain("EXISTING_WORKOS_USER");
    expect(report).toContain("NOT_FOUND");
  });

  test("local artefact is serialized atomically with emails only on disk", async () => {
    const mapping = await buildWorkosMapping(
      emptyBundle([authUser(A, { email: "alice@example.com", is_anonymous: false })]),
      async () => ["user_01ALICE"],
    );
    const dir = mkdtempSync(join(tmpdir(), "jdr-workos-"));
    tempDirs.push(dir);
    writeWorkosMapping(dir, mapping);
    const raw = readFileSync(join(dir, WORKOS_MAPPING_FILENAME), "utf8");
    const parsed = JSON.parse(raw) as { entries: Array<{ email: string }> };
    expect(parsed.entries[0]?.email).toBe("alice@example.com");
    expect(raw).toContain("user_01ALICE");
  });

  test("WorkOS lookup path is GET-only and never mutates remotely", async () => {
    type FetchMock = (
      input: RequestInfo | URL,
      init?: RequestInit,
    ) => Promise<Response>;
    const fetchImpl = vi.fn<FetchMock>(
      async (_input, _init) =>
        new Response(
          JSON.stringify({ data: [{ id: "user_01ALICE", email: "alice@example.com" }] }),
          {
            status: 200,
            headers: { "content-type": "application/json" },
          },
        ),
    );
    const lookup = createWorkosEmailLookup(fetchImpl, "test-workos-key");
    const ids = await lookup("Alice@Example.com");
    expect(ids).toEqual(["user_01ALICE"]);
    expect(fetchImpl).toHaveBeenCalledTimes(1);
    const [url, init] = fetchImpl.mock.calls[0]!;
    expect(String(url).startsWith(WORKOS_USERS_URL)).toBe(true);
    expect(init?.method).toBe("GET");
    expect(JSON.stringify(init)).not.toContain("POST");
    expect(JSON.stringify(init)).not.toContain("PUT");
    expect(JSON.stringify(init)).not.toContain("PATCH");
    expect(JSON.stringify(init)).not.toContain("DELETE");
  });

  test("anonymous users are not mapped", async () => {
    const lookup = vi.fn(async () => ["user_01NOPE"]);
    const mapping = await buildWorkosMapping(emptyBundle([authUser(ANON)]), lookup);
    expect(mapping.entries).toEqual([]);
    expect(lookup).not.toHaveBeenCalled();
    expect(mapping.verdict).toBe("WORKOS_MAP_PASS");
  });

  test("HTTP errors do not include the API key", async () => {
    const lookup = createWorkosEmailLookup(async () => new Response("nope", { status: 401 }), "secret-key-value");
    await expect(lookup("alice@example.com")).rejects.toThrow(/failed \(401\)/);
    try {
      await lookup("alice@example.com");
    } catch (error) {
      expect(String(error)).not.toContain("secret-key-value");
    }
  });
});
