import { GameMasterBackendError } from "./errors";
import { parseOpenRouterUsage, type UsageStats } from "./aiUsage";

export const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
export const DEFAULT_MODEL = "google/gemini-3.1-flash-lite";
export const REQUEST_TIMEOUT_MS = 30_000;

export class InvalidOpenRouterJsonError extends GameMasterBackendError {
  stats: UsageStats;
  constructor(stats: UsageStats) {
    super("OpenRouter returned an invalid JSON payload.");
    this.name = "InvalidOpenRouterJsonError";
    this.stats = stats;
  }
}

export type OpenRouterResult = {
  decoded: Record<string, unknown>;
  stats: UsageStats;
};

export async function completeOpenRouterJson(args: {
  messages: Array<{ role: string; content: string }>;
  temperature: number;
  maxTokens: number;
  title: string;
  fetchImpl?: typeof fetch;
}): Promise<OpenRouterResult> {
  const apiKey = process.env.OPENROUTER_API_KEY ?? "";
  if (!apiKey) {
    throw new GameMasterBackendError("OPENROUTER_API_KEY is not configured.");
  }
  const model = process.env.OPENROUTER_MODEL ?? DEFAULT_MODEL;
  const payload = {
    model,
    messages: args.messages,
    temperature: args.temperature,
    max_tokens: args.maxTokens,
    response_format: { type: "json_object" },
  };
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  const started = Date.now();
  let response: Response;
  try {
    const fetchImpl = args.fetchImpl ?? fetch;
    response = await fetchImpl(OPENROUTER_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "X-Title": args.title,
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
  } catch {
    throw new GameMasterBackendError("OpenRouter request failed with status 502.");
  } finally {
    clearTimeout(timer);
  }
  const latencyMs = Date.now() - started;
  if (response.status >= 400) {
    throw new GameMasterBackendError(
      `OpenRouter request failed with status ${response.status}.`,
    );
  }
  const data: unknown = await response.json();
  const stats = parseOpenRouterUsage(data, { model, latencyMs });
  try {
    const content = (
      data as {
        choices: Array<{ message: { content: string } }>;
      }
    ).choices[0].message.content;
    const decoded: unknown = JSON.parse(content);
    if (decoded === null || typeof decoded !== "object" || Array.isArray(decoded)) {
      throw new TypeError("OpenRouter JSON content is not an object.");
    }
    return { decoded: decoded as Record<string, unknown>, stats };
  } catch {
    throw new InvalidOpenRouterJsonError(stats);
  }
}
