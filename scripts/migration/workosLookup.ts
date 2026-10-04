import { normalizeEmail } from "./classify";

export const WORKOS_USERS_URL = "https://api.workos.com/user_management/users";

export type WorkosEmailLookup = (normalizedEmail: string) => Promise<string[]>;

function requireWorkosApiKey(): string {
  const apiKey = (process.env.WORKOS_API_KEY ?? "").trim();
  if (!apiKey) {
    throw new Error("WORKOS_API_KEY is required for WorkOS migration commands");
  }
  return apiKey;
}

function readUsers(payload: unknown): Array<{ id: string; email: string | null }> {
  const rows =
    payload !== null &&
    typeof payload === "object" &&
    Array.isArray((payload as { data?: unknown }).data)
      ? ((payload as { data: unknown[] }).data)
      : Array.isArray(payload)
        ? payload
        : [];
  const users: Array<{ id: string; email: string | null }> = [];
  for (const row of rows) {
    if (row === null || typeof row !== "object") {
      continue;
    }
    const id = String((row as { id?: unknown }).id ?? "").trim();
    if (!id) {
      continue;
    }
    users.push({
      id,
      email: normalizeEmail(String((row as { email?: unknown }).email ?? "")),
    });
  }
  return users;
}

export function createWorkosEmailLookup(
  fetchImpl: typeof fetch = fetch,
  apiKey: string = requireWorkosApiKey(),
): WorkosEmailLookup {
  return async (normalizedEmail: string): Promise<string[]> => {
    const email = normalizeEmail(normalizedEmail);
    if (!email) {
      throw new Error("WorkOS lookup requires a normalized email");
    }
    const url = new URL(WORKOS_USERS_URL);
    url.searchParams.set("email", email);
    url.searchParams.set("limit", "100");
    const response = await fetchImpl(url.toString(), {
      method: "GET",
      headers: {
        Authorization: `Bearer ${apiKey}`,
      },
    });
    if (response.status >= 400) {
      throw new Error(`WorkOS user lookup failed (${response.status})`);
    }
    const payload = (await response.json()) as unknown;
    const matches = readUsers(payload).filter((row) => row.email === email);
    return [...new Set(matches.map((row) => row.id))];
  };
}

export type WorkosCreateUserInput = {
  email: string;
  email_verified?: boolean;
};

export type WorkosCreateAttempt =
  | { kind: "created"; id: string; status: number }
  | { kind: "ambiguous"; status: number | null };

function readCreatedUser(payload: unknown): { id: string; email: string | null } | null {
  if (payload === null || typeof payload !== "object") {
    return null;
  }
  const id = String((payload as { id?: unknown }).id ?? "").trim();
  if (!id) {
    return null;
  }
  return {
    id,
    email: normalizeEmail(String((payload as { email?: unknown }).email ?? "")),
  };
}

export function createWorkosUser(
  fetchImpl: typeof fetch = fetch,
  apiKey: string = requireWorkosApiKey(),
): (input: WorkosCreateUserInput) => Promise<WorkosCreateAttempt> {
  return async (input: WorkosCreateUserInput): Promise<WorkosCreateAttempt> => {
    const email = normalizeEmail(input.email);
    if (!email) {
      throw new Error("WorkOS create requires a normalized email");
    }
    const body: WorkosCreateUserInput = { email };
    if (input.email_verified === true) {
      body.email_verified = true;
    }
    let response: Response;
    try {
      response = await fetchImpl(WORKOS_USERS_URL, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      });
    } catch {
      return { kind: "ambiguous", status: null };
    }
    if (response.status === 200 || response.status === 201) {
      const created = readCreatedUser((await response.json()) as unknown);
      if (created && created.email === email) {
        return { kind: "created", id: created.id, status: response.status };
      }
      return { kind: "ambiguous", status: response.status };
    }
    return { kind: "ambiguous", status: response.status };
  };
}
