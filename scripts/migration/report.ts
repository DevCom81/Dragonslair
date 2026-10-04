import { writeFileSync } from "node:fs";
import { join } from "node:path";
import type { DryRunReport } from "./types";

export function writeDryRunReports(dir: string, report: DryRunReport): void {
  writeFileSync(join(dir, "migration_report.json"), `${JSON.stringify(report, null, 2)}\n`);
  writeFileSync(
    join(dir, "pending_identity_link.json"),
    `${JSON.stringify(report.pending_identity_link, null, 2)}\n`,
  );
  writeFileSync(
    join(dir, "unresolved_entitlements.json"),
    `${JSON.stringify(report.unresolved_entitlements, null, 2)}\n`,
  );
  writeFileSync(
    join(dir, "collisions.json"),
    `${JSON.stringify(
      report.findings.filter((item) =>
        [
          "DUPLICATE_EMAIL",
          "PLAY_REF_SHARED",
          "STRIPE_CS_SHARED",
          "JOIN_CODE_COLLISION",
          "MULTIPLE_COMBATS",
          "MULTIPLE_OPEN_ROLLS",
        ].includes(item.code),
      ),
      null,
      2,
    )}\n`,
  );
  writeFileSync(
    join(dir, "orphan_report.json"),
    `${JSON.stringify(
      {
        orphans: report.orphans,
        findings: report.findings.filter((item) => item.code.startsWith("ORPHAN")),
      },
      null,
      2,
    )}\n`,
  );
}

export function formatHumanReport(report: DryRunReport): string {
  const lines = [
    `Verdict: ${report.verdict}`,
    "",
    "Source dataset:",
    ...Object.entries(report.source_counts).map(
      ([name, count]) => `  ${name}: ${count}`,
    ),
    "",
    "Migratable dataset:",
    ...Object.entries(report.migratable_counts).map(
      ([name, count]) => `  ${name}: ${count}`,
    ),
    "",
    "Archived/ignored:",
    ...Object.entries(report.archived_counts).map(
      ([name, count]) => `  ${name}: ${count}`,
    ),
    "",
    "User categories:",
    ...Object.entries(report.category_counts).map(
      ([name, count]) => `  ${name}: ${count}`,
    ),
    "",
    `pending_identity_link: ${report.pending_identity_link.length}`,
    `ambiguous_identity: ${report.ambiguous_identity.length}`,
    `orphans: ${report.orphans.length}`,
    `unresolved_entitlements: ${report.unresolved_entitlements.length}`,
    "",
    "Findings:",
  ];
  if (report.findings.length === 0) {
    lines.push("  none");
  } else {
    for (const finding of report.findings) {
      lines.push(`  [${finding.severity}] ${finding.code}: ${finding.message}`);
    }
  }
  return `${lines.join("\n")}\n`;
}
