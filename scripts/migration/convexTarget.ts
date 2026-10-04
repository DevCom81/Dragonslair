export class ConvexImportExecuteError extends Error {
  readonly code: string;
  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

/** Non-secret arming phrase. Absent by default. Not an API key. */
export const CONVEX_PRODUCTION_CONFIRM_VALUE = "DRAGONSLAIR_PRODUCTION";

export type ConvexGuardMode = "execute" | "dry-run" | "audit";

export function isProductionConvexSelector(
  selector: string,
  explicitProductionDeployment = "",
): boolean {
  const value = selector.trim();
  if (!value) {
    return false;
  }
  if (/^prod:/i.test(value) || /prod/i.test(value)) {
    return true;
  }
  const explicit = explicitProductionDeployment.trim();
  return explicit.length > 0 && value === explicit;
}

export function isProductionConvexTarget(args: {
  target?: string;
  deployment?: string;
  productionDeployment?: string;
}): boolean {
  const explicit = args.productionDeployment ?? "";
  return (
    isProductionConvexSelector(String(args.target ?? ""), explicit) ||
    isProductionConvexSelector(String(args.deployment ?? ""), explicit)
  );
}

export function assertConvexTargetPair(args: {
  target?: string;
  deployment?: string;
  requiredFor: "execute" | "audit";
}): { target: string; deployment: string } {
  const deployment = String(args.deployment ?? "").trim();
  const target = String(args.target ?? "").trim();
  if (!deployment || !target) {
    throw new ConvexImportExecuteError(
      "CONVEX_TARGET_MISSING",
      args.requiredFor === "audit"
        ? "CONVEX_DEPLOYMENT and --target are required for convex-audit"
        : "CONVEX_DEPLOYMENT and --target are required for --execute",
    );
  }
  if (target !== deployment) {
    throw new ConvexImportExecuteError(
      "CONVEX_TARGET_MISMATCH",
      " --target does not match CONVEX_DEPLOYMENT",
    );
  }
  return { target, deployment };
}

export function formatConvexGuardBanner(args: {
  target?: string;
  deployment?: string;
  mode: ConvexGuardMode;
  production: boolean;
  productionArmed: boolean;
}): string {
  const productionWrite =
    args.mode !== "execute"
      ? "not requested"
      : args.production
        ? args.productionArmed
          ? "ARMED"
          : "UNARMED"
        : "not applicable";
  return [
    `requested --target: ${String(args.target ?? "").trim() || "(unset)"}`,
    `CONVEX_DEPLOYMENT: ${String(args.deployment ?? "").trim() || "(unset)"}`,
    `mode: ${
      args.mode === "execute"
        ? "execute"
        : args.mode === "audit"
          ? "audit (read-only, zero Convex writes)"
          : "dry-run (zero Convex writes)"
    }`,
    `environment: ${args.production ? "PRODUCTION" : "staging/dev"}`,
    `production write: ${productionWrite}`,
  ].join("\n");
}
