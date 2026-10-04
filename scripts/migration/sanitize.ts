const FORBIDDEN_KEY =
  /(password|passwd|secret|token|jwt|authorization|api[_-]?key|private[_-]?key|refresh|service[_-]?role|encrypted)/i;

const GAMEPLAY_EXPORT_KEYS = new Set(["gm_secrets", "gm_state"]);

export function isForbiddenExportKey(key: string): boolean {
  if (GAMEPLAY_EXPORT_KEYS.has(key)) {
    return false;
  }
  return FORBIDDEN_KEY.test(key);
}

export function stripForbiddenFields(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => stripForbiddenFields(item));
  }
  if (value !== null && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [key, nested] of Object.entries(value)) {
      if (isForbiddenExportKey(key)) {
        continue;
      }
      out[key] = stripForbiddenFields(nested);
    }
    return out;
  }
  return value;
}

export function sanitizeAuthUser(raw: unknown): {
  id: string;
  email: string | null;
  is_anonymous: boolean;
  created_at: string | null;
  email_confirmed_at: string | null;
  deleted_at: string | null;
} | null {
  const cleaned = stripForbiddenFields(raw);
  if (cleaned === null || typeof cleaned !== "object" || Array.isArray(cleaned)) {
    return null;
  }
  const row = cleaned as Record<string, unknown>;
  const id = String(row.id ?? "").trim();
  if (!id) {
    return null;
  }
  const emailRaw = String(row.email ?? "").trim();
  return {
    id,
    email: emailRaw ? emailRaw.toLowerCase() : null,
    is_anonymous: row.is_anonymous === true,
    created_at: optionalString(row.created_at),
    email_confirmed_at: optionalString(row.email_confirmed_at),
    deleted_at: optionalString(row.deleted_at),
  };
}

function optionalString(value: unknown): string | null {
  const text = String(value ?? "").trim();
  return text ? text : null;
}

export function assertNoForbiddenPayload(value: unknown, path = "root"): string[] {
  const leaks: string[] = [];
  if (Array.isArray(value)) {
    value.forEach((item, index) => {
      leaks.push(...assertNoForbiddenPayload(item, `${path}[${index}]`));
    });
    return leaks;
  }
  if (value !== null && typeof value === "object") {
    for (const [key, nested] of Object.entries(value)) {
      if (isForbiddenExportKey(key)) {
        leaks.push(`${path}.${key}`);
      }
      leaks.push(...assertNoForbiddenPayload(nested, `${path}.${key}`));
    }
  }
  return leaks;
}
