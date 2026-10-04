import { classifyAuthUsers, normalizeEmail } from "./classify";
import type {
  Finding,
  MigrationBundle,
  WorkosMapEntry,
  WorkosMapping,
} from "./types";
import { WORKOS_MAP_VERSION } from "./types";
import type { WorkosEmailLookup } from "./workosLookup";

export class WorkosMapError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

export function idPrefix(value: string, size = 8): string {
  return String(value ?? "").trim().slice(0, size);
}

export function selectMigratableEmailUsers(bundle: MigrationBundle): Array<{
  legacy_user_id: string;
  email: string;
}> {
  const emailsByValue = new Map<string, string[]>();
  const ids = new Set<string>();
  for (const user of bundle.auth_users) {
    if (ids.has(user.id)) {
      throw new WorkosMapError(
        "DUPLICATE_LEGACY_UUID",
        "Duplicate legacy user id among auth users",
      );
    }
    ids.add(user.id);
    const email = normalizeEmail(user.email);
    if (!email) {
      continue;
    }
    const list = emailsByValue.get(email) ?? [];
    list.push(user.id);
    emailsByValue.set(email, list);
  }
  for (const idsForEmail of emailsByValue.values()) {
    if (idsForEmail.length > 1) {
      throw new WorkosMapError(
        "DUPLICATE_NORMALIZED_EMAIL",
        "Duplicate normalized email among auth users",
      );
    }
  }

  const classified = classifyAuthUsers({
    authUsers: bundle.auth_users,
    sources: bundle.entitlement_sources,
    entitlements: bundle.user_entitlements,
    rooms: bundle.rooms,
    players: bundle.players,
    demos: bundle.demo_sessions,
  });
  const rows: Array<{ legacy_user_id: string; email: string }> = [];
  for (const user of bundle.auth_users) {
    if (classified[user.id] !== "migratable_email") {
      continue;
    }
    const email = normalizeEmail(user.email);
    if (!email) {
      throw new WorkosMapError(
        "MIGRATABLE_EMAIL_MISSING",
        "Migratable user is missing a normalized email",
      );
    }
    rows.push({ legacy_user_id: user.id, email });
  }
  rows.sort((a, b) => a.legacy_user_id.localeCompare(b.legacy_user_id));
  return rows;
}

export async function buildWorkosMapping(
  bundle: MigrationBundle,
  lookup: WorkosEmailLookup,
): Promise<WorkosMapping> {
  const candidates = selectMigratableEmailUsers(bundle);
  const lookedUp: Array<{ legacy_user_id: string; email: string; ids: string[] }> = [];
  for (const candidate of candidates) {
    lookedUp.push({
      ...candidate,
      ids: await lookup(candidate.email),
    });
  }

  const workosOwners = new Map<string, string[]>();
  for (const row of lookedUp) {
    if (row.ids.length !== 1) {
      continue;
    }
    const workosUserId = row.ids[0]!;
    const owners = workosOwners.get(workosUserId) ?? [];
    owners.push(row.legacy_user_id);
    workosOwners.set(workosUserId, owners);
  }

  const entries: WorkosMapEntry[] = [];
  const findings: Finding[] = [];
  const sharedReported = new Set<string>();

  for (const row of lookedUp) {
    if (row.ids.length === 0) {
      entries.push({
        legacy_user_id: row.legacy_user_id,
        email: row.email,
        status: "NOT_FOUND",
        workos_user_id: null,
      });
      continue;
    }
    if (row.ids.length > 1) {
      entries.push({
        legacy_user_id: row.legacy_user_id,
        email: row.email,
        status: "AMBIGUOUS_WORKOS_USER",
        workos_user_id: null,
      });
      findings.push({
        severity: "CRITICAL",
        code: "AMBIGUOUS_WORKOS_USER",
        message: "Multiple WorkOS users match one migratable email",
        refs: { legacy_user_id: row.legacy_user_id },
      });
      continue;
    }
    const workosUserId = row.ids[0]!;
    const owners = workosOwners.get(workosUserId) ?? [];
    if (owners.length > 1) {
      entries.push({
        legacy_user_id: row.legacy_user_id,
        email: row.email,
        status: "AMBIGUOUS_WORKOS_USER",
        workos_user_id: null,
      });
      if (!sharedReported.has(workosUserId)) {
        sharedReported.add(workosUserId);
        findings.push({
          severity: "CRITICAL",
          code: "WORKOS_USER_SHARED",
          message: "WorkOS user id is attached to multiple legacy users",
          refs: { legacy_user_id: row.legacy_user_id },
        });
      }
      continue;
    }
    entries.push({
      legacy_user_id: row.legacy_user_id,
      email: row.email,
      status: "EXISTING_WORKOS_USER",
      workos_user_id: workosUserId,
    });
  }

  const blocked = findings.some((item) => item.severity === "CRITICAL");
  return {
    version: WORKOS_MAP_VERSION,
    generated_at: new Date().toISOString(),
    verdict: blocked ? "WORKOS_MAP_BLOCKED" : "WORKOS_MAP_PASS",
    entries,
    findings,
  };
}

export function formatWorkosMapReport(mapping: WorkosMapping): string {
  const lines = [`WorkOS map: ${mapping.verdict}`, `entries: ${mapping.entries.length}`];
  for (const entry of mapping.entries) {
    const workos = entry.workos_user_id ? idPrefix(entry.workos_user_id) : "-";
    lines.push(`${idPrefix(entry.legacy_user_id)} | ${entry.status} | ${workos}`);
  }
  if (mapping.findings.length > 0) {
    lines.push("findings:");
    for (const finding of mapping.findings) {
      lines.push(`  [${finding.severity}] ${finding.code}: ${finding.message}`);
    }
  }
  return `${lines.join("\n")}\n`;
}
