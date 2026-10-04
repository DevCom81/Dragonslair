import { normalizeEmail } from "./classify";
import type {
  Finding,
  MigrationBundle,
  SanitizedAuthUser,
  WorkosMapEntry,
  WorkosMapping,
} from "./types";
import { WORKOS_MAP_VERSION } from "./types";
import type { WorkosCreateAttempt, WorkosEmailLookup } from "./workosLookup";
import { idPrefix, selectMigratableEmailUsers, WorkosMapError } from "./workosMap";

export type WorkosCreateOutcome = "CREATED" | "ALREADY_EXISTED" | "BLOCKED";

export type WorkosCreateReport = {
  verdict: "WORKOS_CREATE_PASS" | "WORKOS_CREATE_BLOCKED";
  created: number;
  already_existed: number;
  blocked: number;
  mapping: WorkosMapping;
  findings: Finding[];
  outcomes: Array<{
    legacy_user_id: string;
    outcome: WorkosCreateOutcome;
    workos_user_id: string | null;
  }>;
};

export type WorkosCreateUserFn = (input: {
  email: string;
  email_verified?: boolean;
}) => Promise<WorkosCreateAttempt>;

function entryKey(legacy_user_id: string, email: string): string {
  return `${legacy_user_id}\0${email}`;
}

function authById(bundle: MigrationBundle): Map<string, SanitizedAuthUser> {
  return new Map(bundle.auth_users.map((row) => [row.id, row]));
}

function assertMappingMatchesExport(
  bundle: MigrationBundle,
  mapping: WorkosMapping,
): ReturnType<typeof selectMigratableEmailUsers> {
  if (mapping.verdict !== "WORKOS_MAP_PASS") {
    throw new WorkosMapError(
      "WORKOS_MAP_NOT_PASS",
      "WorkOS mapping verdict is not WORKOS_MAP_PASS",
    );
  }
  const candidates = selectMigratableEmailUsers(bundle);
  const mappingLegacy = new Set<string>();
  const mappingEmails = new Set<string>();
  for (const entry of mapping.entries) {
    if (entry.status === "AMBIGUOUS_WORKOS_USER") {
      throw new WorkosMapError(
        "AMBIGUOUS_WORKOS_USER",
        "WorkOS mapping contains an ambiguous entry",
      );
    }
    const email = normalizeEmail(entry.email);
    if (!email) {
      throw new WorkosMapError(
        "MIGRATABLE_EMAIL_MISSING",
        "WorkOS mapping entry is missing a normalized email",
      );
    }
    if (email !== entry.email) {
      throw new WorkosMapError(
        "EMAIL_NORMALIZATION_MISMATCH",
        "WorkOS mapping email is not normalized",
      );
    }
    if (mappingLegacy.has(entry.legacy_user_id)) {
      throw new WorkosMapError(
        "DUPLICATE_LEGACY_UUID",
        "Duplicate legacy user id in WorkOS mapping",
      );
    }
    if (mappingEmails.has(email)) {
      throw new WorkosMapError(
        "DUPLICATE_NORMALIZED_EMAIL",
        "Duplicate normalized email in WorkOS mapping",
      );
    }
    mappingLegacy.add(entry.legacy_user_id);
    mappingEmails.add(email);
    if (entry.status === "EXISTING_WORKOS_USER" && !entry.workos_user_id) {
      throw new WorkosMapError(
        "INVALID_WORKOS_MAPPING",
        "EXISTING_WORKOS_USER is missing a WorkOS user id",
      );
    }
    if (entry.status === "NOT_FOUND" && entry.workos_user_id) {
      throw new WorkosMapError(
        "INVALID_WORKOS_MAPPING",
        "NOT_FOUND entry must not already have a WorkOS user id",
      );
    }
  }
  if (mapping.entries.length !== candidates.length) {
    throw new WorkosMapError(
      "MAPPING_EXPORT_MISMATCH",
      "WorkOS mapping entries do not match migratable users",
    );
  }
  const candidateKeys = new Set(
    candidates.map((row) => entryKey(row.legacy_user_id, row.email)),
  );
  for (const entry of mapping.entries) {
    if (!candidateKeys.has(entryKey(entry.legacy_user_id, entry.email))) {
      throw new WorkosMapError(
        "MAPPING_EXPORT_MISMATCH",
        "WorkOS mapping entry does not match a migratable user",
      );
    }
  }
  return candidates;
}

function replaceEntry(mapping: WorkosMapping, next: WorkosMapEntry): WorkosMapping {
  return {
    ...mapping,
    version: WORKOS_MAP_VERSION,
    generated_at: new Date().toISOString(),
    entries: mapping.entries.map((row) =>
      row.legacy_user_id === next.legacy_user_id ? next : row,
    ),
  };
}

export async function createMissingWorkosUsers(args: {
  bundle: MigrationBundle;
  mapping: WorkosMapping;
  lookup: WorkosEmailLookup;
  createUser: WorkosCreateUserFn;
  persist?: (mapping: WorkosMapping) => void;
}): Promise<WorkosCreateReport> {
  assertMappingMatchesExport(args.bundle, args.mapping);
  const users = authById(args.bundle);
  let mapping = args.mapping;
  const findings: Finding[] = [...mapping.findings];
  const outcomes: WorkosCreateReport["outcomes"] = [];
  let created = 0;
  let already_existed = 0;
  let blocked = 0;

  const persist = () => {
    args.persist?.(mapping);
  };

  for (const entry of mapping.entries) {
    if (entry.status !== "NOT_FOUND") {
      continue;
    }
    const ids = await args.lookup(entry.email);
    if (ids.length > 1) {
      blocked += 1;
      mapping = {
        ...replaceEntry(mapping, {
          ...entry,
          status: "AMBIGUOUS_WORKOS_USER",
          workos_user_id: null,
        }),
        verdict: "WORKOS_MAP_BLOCKED",
        findings: [
          ...findings,
          {
            severity: "CRITICAL",
            code: "AMBIGUOUS_WORKOS_USER",
            message: "Multiple WorkOS users match one migratable email",
            refs: { legacy_user_id: entry.legacy_user_id },
          },
        ],
      };
      findings.push(mapping.findings[mapping.findings.length - 1]!);
      outcomes.push({
        legacy_user_id: entry.legacy_user_id,
        outcome: "BLOCKED",
        workos_user_id: null,
      });
      persist();
      return finish(mapping, created, already_existed, blocked, findings, outcomes);
    }
    if (ids.length === 1) {
      const workos_user_id = ids[0]!;
      mapping = replaceEntry(mapping, {
        ...entry,
        status: "EXISTING_WORKOS_USER",
        workos_user_id,
      });
      already_existed += 1;
      outcomes.push({
        legacy_user_id: entry.legacy_user_id,
        outcome: "ALREADY_EXISTED",
        workos_user_id,
      });
      persist();
      continue;
    }

    const auth = users.get(entry.legacy_user_id);
    const email_verified = Boolean(auth?.email_confirmed_at);
    const attempt = await args.createUser({
      email: entry.email,
      ...(email_verified ? { email_verified: true } : {}),
    });
    if (attempt.kind === "created") {
      mapping = replaceEntry(mapping, {
        ...entry,
        status: "EXISTING_WORKOS_USER",
        workos_user_id: attempt.id,
      });
      created += 1;
      outcomes.push({
        legacy_user_id: entry.legacy_user_id,
        outcome: "CREATED",
        workos_user_id: attempt.id,
      });
      persist();
      continue;
    }

    const reconciled = await args.lookup(entry.email);
    if (reconciled.length === 1) {
      const workos_user_id = reconciled[0]!;
      mapping = replaceEntry(mapping, {
        ...entry,
        status: "EXISTING_WORKOS_USER",
        workos_user_id,
      });
      already_existed += 1;
      outcomes.push({
        legacy_user_id: entry.legacy_user_id,
        outcome: "ALREADY_EXISTED",
        workos_user_id,
      });
      persist();
      continue;
    }

    blocked += 1;
    mapping = {
      ...replaceEntry(mapping, {
        ...entry,
        status: "AMBIGUOUS_WORKOS_USER",
        workos_user_id: null,
      }),
      verdict: "WORKOS_MAP_BLOCKED",
      findings: [
        ...findings,
        {
          severity: "CRITICAL",
          code: "WORKOS_CREATE_AMBIGUOUS",
          message: "WorkOS create result could not be reconciled; manual review required",
          refs: { legacy_user_id: entry.legacy_user_id },
        },
      ],
    };
    findings.push(mapping.findings[mapping.findings.length - 1]!);
    outcomes.push({
      legacy_user_id: entry.legacy_user_id,
      outcome: "BLOCKED",
      workos_user_id: null,
    });
    persist();
    return finish(mapping, created, already_existed, blocked, findings, outcomes);
  }

  mapping = {
    ...mapping,
    verdict: "WORKOS_MAP_PASS",
  };
  persist();
  return finish(mapping, created, already_existed, blocked, findings, outcomes);
}

function finish(
  mapping: WorkosMapping,
  created: number,
  already_existed: number,
  blocked: number,
  findings: Finding[],
  outcomes: WorkosCreateReport["outcomes"],
): WorkosCreateReport {
  return {
    verdict: blocked > 0 ? "WORKOS_CREATE_BLOCKED" : "WORKOS_CREATE_PASS",
    created,
    already_existed,
    blocked,
    mapping,
    findings,
    outcomes,
  };
}

export function formatWorkosCreateReport(report: WorkosCreateReport): string {
  const lines = [
    `WorkOS create: ${report.verdict}`,
    `CREATED: ${report.created}`,
    `ALREADY_EXISTED: ${report.already_existed}`,
    `BLOCKED: ${report.blocked}`,
  ];
  for (const row of report.outcomes) {
    const workos = row.workos_user_id ? idPrefix(row.workos_user_id) : "-";
    lines.push(`${idPrefix(row.legacy_user_id)} | ${row.outcome} | ${workos}`);
  }
  if (report.findings.length > 0) {
    lines.push("findings:");
    for (const finding of report.findings) {
      lines.push(`  [${finding.severity}] ${finding.code}: ${finding.message}`);
    }
  }
  return `${lines.join("\n")}\n`;
}
