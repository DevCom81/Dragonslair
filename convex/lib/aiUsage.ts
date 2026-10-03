export type CostSource = "none" | "openrouter" | "estimate";

export type UsageStats = {
  model: string;
  input_tokens: number | null;
  output_tokens: number | null;
  latency_ms: number;
  cost: number | null;
  cost_source: CostSource;
};

function nonnegInt(value: unknown): number | null {
  if (typeof value === "boolean") {
    return null;
  }
  if (typeof value === "number" && Number.isFinite(value) && value >= 0) {
    return Math.trunc(value);
  }
  return null;
}

function nonnegFloat(value: unknown): number | null {
  if (typeof value === "boolean") {
    return null;
  }
  if (typeof value === "number" && Number.isFinite(value) && value >= 0) {
    return value;
  }
  return null;
}

function envRate(name: string): number | null {
  const raw = (process.env[name] ?? "").trim();
  if (!raw) {
    return null;
  }
  const value = Number.parseFloat(raw);
  if (!Number.isFinite(value) || value < 0) {
    return null;
  }
  return value;
}

export function estimateCostUsd(args: {
  inputTokens: number | null;
  outputTokens: number | null;
}): number | null {
  const inRate = envRate("AI_INPUT_USD_PER_MILLION");
  const outRate = envRate("AI_OUTPUT_USD_PER_MILLION");
  if (inRate === null || outRate === null) {
    return null;
  }
  const prompt = args.inputTokens ?? 0;
  const completion = args.outputTokens ?? 0;
  return (prompt * inRate + completion * outRate) / 1_000_000;
}

export function parseOpenRouterUsage(
  payload: unknown,
  args: { model: string; latencyMs: number },
): UsageStats {
  const usage =
    payload !== null && typeof payload === "object" && !Array.isArray(payload)
      ? (payload as Record<string, unknown>).usage
      : undefined;
  let inputTokens: number | null = null;
  let outputTokens: number | null = null;
  let cost: number | null = null;
  let costSource: CostSource = "none";
  if (usage !== null && typeof usage === "object" && !Array.isArray(usage)) {
    const mapped = usage as Record<string, unknown>;
    inputTokens = nonnegInt(mapped.prompt_tokens);
    outputTokens = nonnegInt(mapped.completion_tokens);
    cost = nonnegFloat(mapped.cost);
    if (cost !== null) {
      costSource = "openrouter";
    }
  }
  if (cost === null && (inputTokens !== null || outputTokens !== null)) {
    const estimated = estimateCostUsd({
      inputTokens,
      outputTokens,
    });
    if (estimated !== null) {
      cost = estimated;
      costSource = "estimate";
    }
  }
  return {
    model: String(args.model || "").trim().slice(0, 120),
    input_tokens: inputTokens,
    output_tokens: outputTokens,
    latency_ms: Math.max(0, Math.trunc(args.latencyMs)),
    cost,
    cost_source: costSource,
  };
}
