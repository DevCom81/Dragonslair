export const DEMO_DURATION_MS = 10 * 60 * 1000;
export const DEMO_SCENARIO_ID = "demo";
export const CLOSED_ROOM_STATUSES = new Set(["finished", "demo_finished"]);

export type DemoPlayStatus = "ok" | "expired" | "forbidden" | "closed";

export type DemoClockResult = {
  startedAt: number;
  expiresAt: number;
  status: DemoPlayStatus;
};

export function normalizeAccessLevel(value: unknown): "demo" | "full" {
  return String(value ?? "")
    .trim()
    .toLowerCase() === "full"
    ? "full"
    : "demo";
}

export function nextDemoClock(args: {
  now: number;
  startedAt?: number;
  expiresAt?: number;
  completedAt?: number;
  pausedAt?: number;
}): DemoClockResult {
  if (args.completedAt !== undefined) {
    const startedAt = args.startedAt ?? args.now;
    const expiresAt = args.expiresAt ?? startedAt + DEMO_DURATION_MS;
    return { startedAt, expiresAt, status: "expired" };
  }
  if (args.startedAt === undefined) {
    return {
      startedAt: args.now,
      expiresAt: args.now + DEMO_DURATION_MS,
      status: "ok",
    };
  }
  const expiresAt = args.expiresAt ?? args.startedAt + DEMO_DURATION_MS;
  const effectiveNow = args.pausedAt ?? args.now;
  if (effectiveNow < expiresAt) {
    return { startedAt: args.startedAt, expiresAt, status: "ok" };
  }
  return { startedAt: args.startedAt, expiresAt, status: "expired" };
}

export function evaluateDemoPlay(args: {
  accessLevel: unknown;
  roomStatus: unknown;
  roomScenarioId: unknown;
  roomHostId: unknown;
  userId: string;
  startedAt?: number;
  expiresAt?: number;
  completedAt?: number;
  pausedAt?: number;
  now?: number;
}): DemoPlayStatus {
  const now = args.now ?? Date.now();
  const status = String(args.roomStatus ?? "")
    .trim()
    .toLowerCase();
  if (CLOSED_ROOM_STATUSES.has(status)) {
    return "closed";
  }
  if (normalizeAccessLevel(args.accessLevel) === "full") {
    return "ok";
  }
  if (String(args.roomScenarioId ?? "") !== DEMO_SCENARIO_ID) {
    return "forbidden";
  }
  if (String(args.roomHostId ?? "") !== args.userId) {
    return "forbidden";
  }
  return nextDemoClock({
    now,
    startedAt: args.startedAt,
    expiresAt: args.expiresAt,
    completedAt: args.completedAt,
    pausedAt: args.pausedAt,
  }).status;
}

export type CannedDemoEnding = {
  narration: string;
  actions: Array<{
    type: "finish_game";
    payload: { result: "neutral"; summary: string; epilogue: string };
  }>;
  choices: Array<{ label: string }>;
};

export function cannedDemoEnding(locale: string): CannedDemoEnding {
  const language = String(locale || "en")
    .trim()
    .toLowerCase();
  if (language === "fr") {
    return {
      narration:
        "Le souffle du wyrm s'engouffre dans la cave. La porte de pierre " +
        "se referme a demi, et l'aventure s'interrompt au seuil du secret.",
      actions: [
        {
          type: "finish_game",
          payload: {
            result: "neutral",
            summary: "La demo s'acheve au moment ou le danger se revele.",
            epilogue: "L'aventure ne fait que commencer.",
          },
        },
      ],
      choices: [{ label: "Revenir a la taverne" }],
    };
  }
  if (language === "de") {
    return {
      narration:
        "Der Atem des Wyrms fuellt den Keller. Die Steintuer schliesst " +
        "sich halb, und das Abenteuer stockt an der Schwelle des Geheimnisses.",
      actions: [
        {
          type: "finish_game",
          payload: {
            result: "neutral",
            summary: "Die Demo endet, als die Gefahr sichtbar wird.",
            epilogue: "Das Abenteuer hat gerade erst begonnen.",
          },
        },
      ],
      choices: [{ label: "Zurueck zur Taverne" }],
    };
  }
  if (language === "es") {
    return {
      narration:
        "El aliento del wyrm llena la bodega. La puerta de piedra se " +
        "cierra a medias y la aventura se detiene al borde del secreto.",
      actions: [
        {
          type: "finish_game",
          payload: {
            result: "neutral",
            summary: "La demo termina cuando el peligro se revela.",
            epilogue: "La aventura no ha hecho mas que empezar.",
          },
        },
      ],
      choices: [{ label: "Volver a la taberna" }],
    };
  }
  return {
    narration:
      "The wyrm's breath floods the cellar. The stone door closes " +
      "halfway, and the adventure halts at the threshold of the secret.",
    actions: [
      {
        type: "finish_game",
        payload: {
          result: "neutral",
          summary: "The demo ends just as the danger reveals itself.",
          epilogue: "The adventure is only beginning.",
        },
      },
    ],
    choices: [{ label: "Return to the tavern" }],
  };
}

export function ensureFinishAction(
  payload: Record<string, unknown>,
  locale: string,
): Record<string, unknown> {
  const actions = payload.actions;
  if (Array.isArray(actions)) {
    for (const action of actions) {
      if (
        action !== null &&
        typeof action === "object" &&
        !Array.isArray(action) &&
        (action as { type?: unknown }).type === "finish_game"
      ) {
        return payload;
      }
    }
  }
  const canned = cannedDemoEnding(locale);
  const existing = Array.isArray(actions) ? [...actions] : [];
  const merged: Record<string, unknown> = {
    ...payload,
    actions: [...existing, ...canned.actions],
  };
  if (!merged.narration) {
    merged.narration = canned.narration;
  }
  return merged;
}
