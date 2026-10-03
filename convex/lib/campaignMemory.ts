export const RECENT_EVENT_LIMIT = 8;
export const SUMMARY_THRESHOLD = 12;
export const CAMPAIGN_SUMMARY_MAX_CHARS = 1800;
export const EVENT_LINE_MAX_CHARS = 160;
export const EVENT_PROMPT_MAX_CHARS = 400;

export type Memory = {
  campaign_summary: string;
  summarized_event_count: number;
};

export function shouldSummarize(args: {
  eventCount: number;
  summarizedEventCount: number;
}): boolean {
  const oldCount = Math.max(0, args.eventCount - RECENT_EVENT_LIMIT);
  return oldCount - Math.max(0, args.summarizedEventCount) >= SUMMARY_THRESHOLD;
}

export function summaryWindow(args: {
  eventCount: number;
  summarizedEventCount: number;
}): { start: number; limit: number } {
  const start = Math.max(0, args.summarizedEventCount);
  const end = Math.max(0, args.eventCount - RECENT_EVENT_LIMIT);
  if (end <= start) {
    return { start, limit: 0 };
  }
  return { start, limit: end - start };
}

export function capRecentEvents<T>(events: T[], limit = RECENT_EVENT_LIMIT): T[] {
  if (events.length <= limit) {
    return [...events];
  }
  return events.slice(-limit);
}

export function parseMemory(gmState: unknown): Memory {
  if (gmState === null || typeof gmState !== "object" || Array.isArray(gmState)) {
    return { campaign_summary: "", summarized_event_count: 0 };
  }
  const data = gmState as Record<string, unknown>;
  let summary = String(data.campaign_summary ?? "").trim();
  if (summary.length > CAMPAIGN_SUMMARY_MAX_CHARS) {
    summary = summary.slice(-CAMPAIGN_SUMMARY_MAX_CHARS);
  }
  const rawCount = data.summarized_event_count ?? 0;
  let count = Number.parseInt(String(rawCount), 10);
  if (!Number.isFinite(count)) {
    count = 0;
  }
  if (count < 0) {
    count = 0;
  }
  return { campaign_summary: summary, summarized_event_count: count };
}

export function eventLine(event: { type?: unknown; content?: unknown }): string {
  const kind = String(event.type ?? "system").trim() || "system";
  let content = String(event.content ?? "")
    .replace(/\n/g, " ")
    .trim();
  if (content.length > EVENT_LINE_MAX_CHARS) {
    content = content.slice(0, EVENT_LINE_MAX_CHARS);
  }
  if (!content) {
    return "";
  }
  return `[${kind}] ${content}`;
}

export function mergeCampaignSummary(
  previous: string,
  foldedEvents: Array<{ type?: unknown; content?: unknown }>,
): string {
  const lines: string[] = [];
  for (const event of foldedEvents) {
    const line = eventLine(event);
    if (line) {
      lines.push(line);
    }
  }
  const chunk = lines.join("\n");
  const prev = (previous || "").trim();
  let text = "";
  if (!prev) {
    text = chunk;
  } else if (!chunk) {
    text = prev;
  } else {
    text = `${prev}\n${chunk}`;
  }
  if (text.length <= CAMPAIGN_SUMMARY_MAX_CHARS) {
    return text;
  }
  return `…${text.slice(-(CAMPAIGN_SUMMARY_MAX_CHARS - 1))}`;
}

export function nextMemory(args: {
  previous: Memory;
  foldedEvents: Array<{ type?: unknown; content?: unknown }>;
  eventCount: number;
}): Memory {
  return {
    campaign_summary: mergeCampaignSummary(
      args.previous.campaign_summary,
      args.foldedEvents,
    ),
    summarized_event_count: Math.max(0, args.eventCount - RECENT_EVENT_LIMIT),
  };
}

export function recentEventsFromRows(
  rows: Array<{ type?: unknown; content?: unknown }>,
): Array<{ type: "action" | "narration" | "system"; content: string }> {
  const events: Array<{
    type: "action" | "narration" | "system";
    content: string;
  }> = [];
  for (const row of rows) {
    const kind = row.type;
    const content = String(row.content ?? "").trim();
    if (
      (kind !== "action" && kind !== "narration" && kind !== "system") ||
      !content
    ) {
      continue;
    }
    events.push({ type: kind, content: content.slice(0, 2000) });
  }
  return capRecentEvents(events);
}

export function applyMemoryToGmState(
  gmState: unknown,
  memory: Memory,
): Record<string, unknown> {
  const merged =
    gmState !== null && typeof gmState === "object" && !Array.isArray(gmState)
      ? { ...(gmState as Record<string, unknown>) }
      : {};
  delete merged.gm_secrets;
  merged.campaign_summary = String(memory.campaign_summary || "");
  merged.summarized_event_count = Number(memory.summarized_event_count || 0);
  return merged;
}
