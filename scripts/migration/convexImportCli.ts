import {
  assertConvexExecuteAllowed,
  createConvexRunWriter,
  executeConvexImportPlan,
  type ImportWriter,
} from "./convexImportExecute";
import { buildConvexImportPlan, formatConvexImportPlan } from "./convexImportPlan";
import { loadMigrationDir } from "./loadExport";
import { loadWorkosMapping } from "./writeWorkosMapping";

export type ConvexImportCliEnv = {
  CONVEX_DEPLOYMENT?: string;
  CONVEX_MIGRATION_CONFIRM?: string;
};

export async function runConvexImportCommand(args: {
  dir: string;
  mappingDir: string;
  execute: boolean;
  dryRunFlag: boolean;
  target?: string;
  env?: ConvexImportCliEnv;
  createWriter?: () => ImportWriter;
}): Promise<{ code: number; stdout: string }> {
  const bundle = loadMigrationDir(args.dir);
  const mapping = loadWorkosMapping(args.mappingDir);
  const plan = buildConvexImportPlan(bundle, mapping);
  const deployment = String(args.env?.CONVEX_DEPLOYMENT ?? "").trim();
  const lines = [
    `Convex target: ${deployment || "(unset)"}`,
    args.execute ? "mode: execute" : "mode: dry-run (zero Convex writes)",
    formatConvexImportPlan(plan).trimEnd(),
  ];
  if (plan.verdict !== "CONVEX_IMPORT_READY") {
    return { code: 1, stdout: `${lines.join("\n")}\n` };
  }
  if (!args.execute) {
    return { code: 0, stdout: `${lines.join("\n")}\n` };
  }
  assertConvexExecuteAllowed({
    execute: args.execute,
    dryRunFlag: args.dryRunFlag,
    target: args.target,
    deployment,
    confirm: args.env?.CONVEX_MIGRATION_CONFIRM,
  });
  const writer = args.createWriter ? args.createWriter() : createConvexRunWriter();
  const result = await executeConvexImportPlan(plan, writer);
  lines.push(`writes: ${result.writes}`);
  return { code: 0, stdout: `${lines.join("\n")}\n` };
}
