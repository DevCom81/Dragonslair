// @vitest-environment node
import { describe, expect, test } from "vitest";
import { exportFromSupabase, parseContentRange } from "./exportSupabase";

const ENV = {
  supabaseUrl: "https://example.supabase.co",
  serviceRoleKey: "service-role-test-value",
};

const TABLES = [
  "profiles",
  "entitlement_sources",
  "user_entitlements",
  "rooms",
  "players",
  "room_gm_state",
  "game_events",
  "enemies",
  "combat_sessions",
  "pending_rolls",
  "demo_sessions",
  "ai_usage_events",
] as const;

function jsonResponse(
  body: unknown,
  headers: Record<string, string> = {},
  status = 200,
): Response {
  return new Response(JSON.stringify(body), { status, headers });
}

describe("parseContentRange", () => {
  test("parses numbered and empty totals", () => {
    expect(parseContentRange("0-999/2500")).toEqual({ total: 2500 });
    expect(parseContentRange("*/0")).toEqual({ total: 0 });
    expect(parseContentRange(null)).toBeNull();
    expect(parseContentRange("0-24/*")).toBeNull();
  });
});

describe("exportFromSupabase", () => {
  test("pages REST until Content-Range total and sanitizes Auth first", async () => {
    const restHits: string[] = [];
    const fetchImpl: typeof fetch = async (input, init) => {
      const url = String(input);
      if (url.includes("/auth/v1/admin/users")) {
        const page = new URL(url).searchParams.get("page");
        if (page === "1") {
          return jsonResponse({
            users: [
              {
                id: "u1",
                email: "a@example.com",
                encrypted_password: "hash",
                recovery_token: "tok",
              },
            ],
          });
        }
        if (page === "2") {
          return jsonResponse({
            users: [{ id: "u2", email: "b@example.com", is_anonymous: true }],
          });
        }
        return jsonResponse({ users: [] });
      }
      const table = TABLES.find((name) => url.includes(`/rest/v1/${name}`));
      expect(init?.method).toBe("GET");
      const range = String(
        (init?.headers as Record<string, string> | undefined)?.Range ?? "",
      );
      restHits.push(`${table}:${range}`);
      if (table === "profiles") {
        if (range === "0-999") {
          return jsonResponse([{ id: "p1" }], {
            "content-range": "0-0/2",
          });
        }
        if (range === "1-1000") {
          return jsonResponse([{ id: "p2" }], {
            "content-range": "1-1/2",
          });
        }
        throw new Error(`unexpected profiles range ${range}`);
      }
      return jsonResponse([], { "content-range": "*/0" });
    };

    const bundle = await exportFromSupabase(fetchImpl, ENV);
    expect(bundle.auth_users.map((row) => row.id)).toEqual(["u1", "u2"]);
    expect(JSON.stringify(bundle.auth_users)).not.toContain("encrypted_password");
    expect(JSON.stringify(bundle.auth_users)).not.toContain("recovery_token");
    expect(bundle.profiles.map((row) => row.id)).toEqual(["p1", "p2"]);
    expect(bundle.manifest.table_counts.profiles).toBe(2);
    expect(bundle.manifest.table_counts.auth_users).toBe(2);
    expect(restHits.filter((hit) => hit.startsWith("profiles:"))).toEqual([
      "profiles:0-999",
      "profiles:1-1000",
    ]);
  });

  test("refuses REST export without Content-Range", async () => {
    const fetchImpl: typeof fetch = async (input) => {
      const url = String(input);
      if (url.includes("/auth/v1/admin/users")) {
        return jsonResponse({ users: [] });
      }
      return jsonResponse([{ id: "p1" }]);
    };
    await expect(exportFromSupabase(fetchImpl, ENV)).rejects.toThrow(
      "missing Content-Range",
    );
  });

  test("refuses Auth pagination that repeats user ids", async () => {
    const fetchImpl: typeof fetch = async (input) => {
      const url = String(input);
      if (url.includes("/auth/v1/admin/users")) {
        return jsonResponse({ users: [{ id: "u1", email: "a@example.com" }] });
      }
      return jsonResponse([], { "content-range": "*/0" });
    };
    await expect(exportFromSupabase(fetchImpl, ENV)).rejects.toThrow(
      "repeated a user id",
    );
  });

  test("HTTP errors do not include the service role key", async () => {
    const fetchImpl: typeof fetch = async () =>
      jsonResponse({ message: "denied" }, {}, 401);
    await expect(exportFromSupabase(fetchImpl, ENV)).rejects.toThrow(
      /failed \(401\)/,
    );
    try {
      await exportFromSupabase(fetchImpl, ENV);
    } catch (error) {
      expect(String(error)).not.toContain(ENV.serviceRoleKey);
    }
  });
});
