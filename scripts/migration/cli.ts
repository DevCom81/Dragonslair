import { exportFromSupabase } from "./exportSupabase";
import { loadMigrationDir } from "./loadExport";
import { runDryRun } from "./dryRun";
import { formatHumanReport, writeDryRunReports } from "./report";
import { writeMigrationExport } from "./writeExport";
import { buildWorkosMapping, formatWorkosMapReport } from "./workosMap";
import { createWorkosEmailLookup, createWorkosUser } from "./workosLookup";
import { loadWorkosMapping, writeWorkosMapping } from "./writeWorkosMapping";
import { createMissingWorkosUsers, formatWorkosCreateReport } from "./workosCreate";
import { runConvexImportCommand } from "./convexImportCli";
import type { ImportWriter } from "./convexImportExecute";
import { runConvexAuditCommand } from "./convexAuditCli";

function hasFlag(args: string[], name: string): boolean {
  return args.includes(name);
}

function option(args: string[], name: string, fallback: string): string {
  const index = args.indexOf(name);
  if (index >= 0 && args[index + 1]) {
    return args[index + 1]!;
  }
  return fallback;
}

function refuseImport(args: string[]): void {
  if (args[0] === "convex-import" || args[0] === "convex-audit") {
    return;
  }
  if (args.includes("import") || hasFlag(args, "--import")) {
    throw new Error(
      "LOT 12 refuses a generic import. Use export, --dry-run, workos-map, workos-create, or convex-import.",
    );
  }
}

export type CliExtras = {
  env?: NodeJS.ProcessEnv;
  createImportWriter?: () => ImportWriter;
};

export async function runCli(
  argv: string[],
  fetchImpl: typeof fetch = fetch,
  extras: CliExtras = {},
): Promise<{ code: number; stdout: string }> {
  const args = argv.slice(2);
  refuseImport(args);
  const outDir = option(args, "--out", "migration-export");
  const dir = option(args, "--dir", outDir);
  const wantsConvexImport = args[0] === "convex-import";
  const wantsConvexAudit = args[0] === "convex-audit";
  const wantsExport = args[0] === "export";
  const wantsDryRun =
    !wantsConvexImport &&
    !wantsConvexAudit &&
    (hasFlag(args, "--dry-run") || args[0] === "dry-run" || args[1] === "--dry-run");
  const wantsWorkosMap = args[0] === "workos-map" || hasFlag(args, "--workos-map");
  const wantsWorkosCreate = args[0] === "workos-create";

  if (
    [
      wantsExport,
      wantsDryRun,
      wantsWorkosMap,
      wantsWorkosCreate,
      wantsConvexImport,
      wantsConvexAudit,
    ].filter(Boolean).length > 1
  ) {
    throw new Error(
      "Run export, --dry-run, workos-map, workos-create, convex-import, and convex-audit as separate commands.",
    );
  }
  if (wantsExport) {
    const bundle = await exportFromSupabase(fetchImpl);
    writeMigrationExport(outDir, bundle);
    return {
      code: 0,
      stdout: `Export written to ${outDir} (auth sanitized, no Convex write).\n`,
    };
  }
  if (wantsDryRun) {
    const bundle = loadMigrationDir(dir);
    const report = runDryRun(bundle);
    writeDryRunReports(dir, report);
    const stdout = formatHumanReport(report);
    return {
      code: report.verdict === "DRY_RUN_PASS" ? 0 : 1,
      stdout,
    };
  }
  if (wantsWorkosMap) {
    const bundle = loadMigrationDir(option(args, "--dir", "migration-export"));
    const mappingDir = option(args, "--out", "migration-work");
    const lookup = createWorkosEmailLookup(fetchImpl);
    const mapping = await buildWorkosMapping(bundle, lookup);
    writeWorkosMapping(mappingDir, mapping);
    return {
      code: mapping.verdict === "WORKOS_MAP_PASS" ? 0 : 1,
      stdout: formatWorkosMapReport(mapping),
    };
  }
  if (wantsWorkosCreate) {
    const bundle = loadMigrationDir(option(args, "--dir", "migration-export"));
    const mappingDir = option(args, "--out", "migration-work");
    const mapping = loadWorkosMapping(mappingDir);
    const lookup = createWorkosEmailLookup(fetchImpl);
    const createUser = createWorkosUser(fetchImpl);
    const report = await createMissingWorkosUsers({
      bundle,
      mapping,
      lookup,
      createUser,
      persist: (next) => writeWorkosMapping(mappingDir, next),
    });
    return {
      code: report.verdict === "WORKOS_CREATE_PASS" ? 0 : 1,
      stdout: formatWorkosCreateReport(report),
    };
  }
  if (wantsConvexImport) {
    return await runConvexImportCommand({
      dir: option(args, "--dir", "migration-export"),
      mappingDir: option(args, "--mapping-dir", option(args, "--out", "migration-work")),
      execute: hasFlag(args, "--execute"),
      dryRunFlag: hasFlag(args, "--dry-run"),
      target: option(args, "--target", ""),
      env: extras.env ?? process.env,
      createWriter: extras.createImportWriter,
    });
  }
  if (wantsConvexAudit) {
    if (hasFlag(args, "--execute") || hasFlag(args, "--import")) {
      throw new Error("convex-audit is read-only and refuses --execute/--import");
    }
    return await runConvexAuditCommand({
      dir: option(args, "--dir", "migration-export"),
      mappingDir: option(args, "--mapping-dir", option(args, "--out", "migration-work")),
      target: option(args, "--target", ""),
      env: extras.env ?? process.env,
    });
  }
  throw new Error(
    "Usage: cli.ts export --out migration-export | cli.ts --dry-run --dir migration-export | cli.ts workos-map --dir migration-export --out migration-work | cli.ts workos-create --dir migration-export --out migration-work | cli.ts convex-import --dir migration-export --mapping-dir migration-work [--dry-run|--execute --target <deployment>] | cli.ts convex-audit --dir migration-export --mapping-dir migration-work --target <deployment>",
  );
}

const invoked = process.argv[1] ?? "";
if (invoked.includes("scripts/migration/cli")) {
  runCli(process.argv).then(
    (result) => {
      process.stdout.write(result.stdout);
      process.exit(result.code);
    },
    (error: unknown) => {
      const message = error instanceof Error ? error.message : "CLI failed";
      process.stderr.write(`${message}\n`);
      process.exit(2);
    },
  );
}