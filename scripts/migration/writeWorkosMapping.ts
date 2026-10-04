import { existsSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import type { WorkosMapEntry, WorkosMapping } from "./types";
import { WorkosMapError } from "./workosMap";

export const WORKOS_MAPPING_FILENAME = "workos-mapping.json";

export function writeWorkosMapping(dir: string, mapping: WorkosMapping): void {
  const staging = `${dir}.inprogress`;
  const backup = `${dir}.bak`;
  rmSync(staging, { recursive: true, force: true });
  rmSync(backup, { recursive: true, force: true });
  mkdirSync(staging, { recursive: true });
  try {
    writeFileSync(
      join(staging, WORKOS_MAPPING_FILENAME),
      `${JSON.stringify(mapping, null, 2)}\n`,
    );
    try {
      renameSync(dir, backup);
    } catch (error) {
      const code = (error as NodeJS.ErrnoException).code;
      if (code !== "ENOENT") {
        throw error;
      }
    }
    renameSync(staging, dir);
    rmSync(backup, { recursive: true, force: true });
  } catch (error) {
    rmSync(staging, { recursive: true, force: true });
    if (!existsSync(dir) && existsSync(backup)) {
      renameSync(backup, dir);
    }
    throw error;
  }
}

function asEntry(value: unknown): WorkosMapEntry {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new WorkosMapError("INVALID_WORKOS_MAPPING", "WorkOS mapping entry is invalid");
  }
  const row = value as Record<string, unknown>;
  const legacy_user_id = String(row.legacy_user_id ?? "").trim();
  const email = String(row.email ?? "").trim();
  const status = String(row.status ?? "").trim();
  const workosRaw = row.workos_user_id;
  const workos_user_id =
    workosRaw === null || workosRaw === undefined ? null : String(workosRaw).trim() || null;
  if (!legacy_user_id || !email) {
    throw new WorkosMapError("INVALID_WORKOS_MAPPING", "WorkOS mapping entry is incomplete");
  }
  if (
    status !== "EXISTING_WORKOS_USER" &&
    status !== "NOT_FOUND" &&
    status !== "AMBIGUOUS_WORKOS_USER"
  ) {
    throw new WorkosMapError("INVALID_WORKOS_MAPPING", "WorkOS mapping status is invalid");
  }
  return {
    legacy_user_id,
    email,
    status,
    workos_user_id,
  };
}

export function loadWorkosMapping(dir: string): WorkosMapping {
  const raw = JSON.parse(readFileSync(join(dir, WORKOS_MAPPING_FILENAME), "utf8")) as unknown;
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) {
    throw new WorkosMapError("INVALID_WORKOS_MAPPING", "WorkOS mapping file is invalid");
  }
  const row = raw as Record<string, unknown>;
  const verdict = String(row.verdict ?? "").trim();
  if (verdict !== "WORKOS_MAP_PASS" && verdict !== "WORKOS_MAP_BLOCKED") {
    throw new WorkosMapError("INVALID_WORKOS_MAPPING", "WorkOS mapping verdict is invalid");
  }
  if (!Array.isArray(row.entries)) {
    throw new WorkosMapError("INVALID_WORKOS_MAPPING", "WorkOS mapping entries are invalid");
  }
  return {
    version: String(row.version ?? "").trim() || "lot12-b3",
    generated_at: String(row.generated_at ?? "").trim(),
    verdict,
    entries: row.entries.map(asEntry),
    findings: Array.isArray(row.findings) ? (row.findings as WorkosMapping["findings"]) : [],
  };
}
