import { archivedLegacyIds, compareMigrationAudit, formatB5Report } from "./convexAudit";
import { runInternalConvexMutation } from "./convexImportExecute";
import { buildConvexImportPlan } from "./convexImportPlan";
import { loadMigrationDir } from "./loadExport";
import { loadWorkosMapping } from "./writeWorkosMapping";
import type { MigrationAuditSnapshot } from "./convexAudit";

export async function runConvexAuditCommand(args: {
  dir: string;
  mappingDir: string;
  target?: string;
  env?: { CONVEX_DEPLOYMENT?: string };
  loadSnapshot?: () => Promise<MigrationAuditSnapshot>;
}): Promise<{ code: number; stdout: string }> {
  const deployment = String(args.env?.CONVEX_DEPLOYMENT ?? "").trim();
  const target = String(args.target ?? "").trim();
  if (/prod/i.test(deployment) || /prod/i.test(target)) {
    throw new Error("convex-audit refuses a production Convex target");
  }
  if (target && deployment && target !== deployment) {
    throw new Error("--target does not match CONVEX_DEPLOYMENT");
  }
  const bundle = loadMigrationDir(args.dir);
  const mapping = loadWorkosMapping(args.mappingDir);
  const plan = buildConvexImportPlan(bundle, mapping);
  const lines = [
    `Convex target: ${deployment || "(unset)"}`,
    "mode: audit (read-only, zero Convex writes)",
  ];
  if (plan.verdict !== "CONVEX_IMPORT_READY") {
    lines.push("LOT12 B5: B5_BLOCKED", "findings:", "  [CRITICAL] PLAN_BLOCKED: import plan is not READY");
    return { code: 1, stdout: `${lines.join("\n")}\n` };
  }
  const snapshot = args.loadSnapshot
    ? await args.loadSnapshot()
    : ((await runInternalConvexMutation(
        "internal.migrationAudit.snapshot",
        {},
        { phase: "audit", operation: "snapshot" },
      )) as MigrationAuditSnapshot);
  const report = compareMigrationAudit(plan, archivedLegacyIds(bundle), snapshot);
  lines.push(formatB5Report(report).trimEnd());
  return { code: report.verdict === "B5_PASS" ? 0 : 1, stdout: `${lines.join("\n")}\n` };
}
