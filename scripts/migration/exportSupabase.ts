import { sanitizeAuthUser, stripForbiddenFields } from "./sanitize";
import { buildManifest } from "./writeExport";
import type { MigrationBundle, SanitizedAuthUser } from "./types";

export type SupabaseExportEnv = {
  supabaseUrl: string;
  serviceRoleKey: string;
};

function requireEnv(): SupabaseExportEnv {
  const supabaseUrl = (process.env.SUPABASE_URL ?? "").trim().replace(/\/+$/, "");
  const serviceRoleKey = (process.env.SUPABASE_SERVICE_ROLE_KEY ?? "").trim();
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required for export");
  }
  return { supabaseUrl, serviceRoleKey };
}

export function parseContentRange(
  header: string | null,
): { total: number } | null {
  const raw = String(header ?? "").trim();
  if (!raw) {
    return null;
  }
  const numbered = raw.match(/^\d+-\d+\/(\d+)$/);
  if (numbered) {
    return { total: Number(numbered[1]) };
  }
  const empty = raw.match(/^\*\/(\d+)$/);
  if (empty) {
    return { total: Number(empty[1]) };
  }
  return null;
}

async function restRows(
  env: SupabaseExportEnv,
  table: string,
  fetchImpl: typeof fetch,
): Promise<unknown[]> {
  const rows: unknown[] = [];
  const pageSize = 1000;
  let from = 0;
  let expectedTotal: number | null = null;
  for (;;) {
    const to = from + pageSize - 1;
    const url = `${env.supabaseUrl}/rest/v1/${table}?select=*`;
    const response = await fetchImpl(url, {
      method: "GET",
      headers: {
        apikey: env.serviceRoleKey,
        Authorization: `Bearer ${env.serviceRoleKey}`,
        Range: `${from}-${to}`,
        Prefer: "count=exact",
      },
    });
    if (response.status >= 400) {
      throw new Error(`Supabase REST ${table} failed (${response.status})`);
    }
    const payload = (await response.json()) as unknown;
    const chunk = Array.isArray(payload) ? payload : [];
    const range = parseContentRange(response.headers.get("content-range"));
    if (range === null) {
      throw new Error(
        `Supabase REST ${table} missing Content-Range; refusing incomplete export`,
      );
    }
    if (expectedTotal === null) {
      expectedTotal = range.total;
    } else if (expectedTotal !== range.total) {
      throw new Error(`Supabase REST ${table} Content-Range total changed`);
    }
    if (from === 0 && chunk.length === 0) {
      if (expectedTotal !== 0) {
        throw new Error(
          `Supabase REST ${table} incomplete (0/${expectedTotal})`,
        );
      }
      return [];
    }
    rows.push(...chunk.map((row) => stripForbiddenFields(row)));
    if (rows.length === expectedTotal) {
      return rows;
    }
    if (chunk.length === 0 || rows.length > expectedTotal) {
      throw new Error(
        `Supabase REST ${table} incomplete (${rows.length}/${expectedTotal})`,
      );
    }
    from += chunk.length;
  }
}

async function exportAuthUsers(
  env: SupabaseExportEnv,
  fetchImpl: typeof fetch,
): Promise<SanitizedAuthUser[]> {
  const users: SanitizedAuthUser[] = [];
  const seen = new Set<string>();
  let page = 1;
  const perPage = 200;
  for (;;) {
    const url = `${env.supabaseUrl}/auth/v1/admin/users?page=${page}&per_page=${perPage}`;
    const response = await fetchImpl(url, {
      method: "GET",
      headers: {
        apikey: env.serviceRoleKey,
        Authorization: `Bearer ${env.serviceRoleKey}`,
      },
    });
    if (response.status >= 400) {
      throw new Error(`Supabase Auth admin export failed (${response.status})`);
    }
    const payload = (await response.json()) as unknown;
    const list = Array.isArray(payload)
      ? payload
      : payload !== null &&
          typeof payload === "object" &&
          Array.isArray((payload as { users?: unknown }).users)
        ? ((payload as { users: unknown[] }).users)
        : [];
    if (list.length === 0) {
      break;
    }
    let newOnPage = 0;
    for (const raw of list) {
      const sanitized = sanitizeAuthUser(raw);
      if (!sanitized) {
        continue;
      }
      if (seen.has(sanitized.id)) {
        throw new Error(
          "Supabase Auth admin pagination repeated a user id; refusing incomplete export",
        );
      }
      seen.add(sanitized.id);
      users.push(sanitized);
      newOnPage += 1;
    }
    if (newOnPage === 0) {
      throw new Error(
        "Supabase Auth admin pagination returned unsanitizable users; refusing incomplete export",
      );
    }
    page += 1;
  }
  return users;
}

export async function exportFromSupabase(
  fetchImpl: typeof fetch = fetch,
  env: SupabaseExportEnv = requireEnv(),
): Promise<MigrationBundle> {
  const auth_users = await exportAuthUsers(env, fetchImpl);
  const data = {
    auth_users,
    profiles: (await restRows(env, "profiles", fetchImpl)) as MigrationBundle["profiles"],
    entitlement_sources: (await restRows(
      env,
      "entitlement_sources",
      fetchImpl,
    )) as MigrationBundle["entitlement_sources"],
    user_entitlements: (await restRows(
      env,
      "user_entitlements",
      fetchImpl,
    )) as MigrationBundle["user_entitlements"],
    rooms: (await restRows(env, "rooms", fetchImpl)) as MigrationBundle["rooms"],
    players: (await restRows(env, "players", fetchImpl)) as MigrationBundle["players"],
    room_gm_state: (await restRows(
      env,
      "room_gm_state",
      fetchImpl,
    )) as MigrationBundle["room_gm_state"],
    game_events: (await restRows(
      env,
      "game_events",
      fetchImpl,
    )) as MigrationBundle["game_events"],
    enemies: (await restRows(env, "enemies", fetchImpl)) as MigrationBundle["enemies"],
    combat_sessions: (await restRows(
      env,
      "combat_sessions",
      fetchImpl,
    )) as MigrationBundle["combat_sessions"],
    pending_rolls: (await restRows(
      env,
      "pending_rolls",
      fetchImpl,
    )) as MigrationBundle["pending_rolls"],
    demo_sessions: (await restRows(
      env,
      "demo_sessions",
      fetchImpl,
    )) as MigrationBundle["demo_sessions"],
    ai_usage_events: (await restRows(
      env,
      "ai_usage_events",
      fetchImpl,
    )) as MigrationBundle["ai_usage_events"],
  };
  return {
    manifest: buildManifest(data),
    ...data,
  };
}
