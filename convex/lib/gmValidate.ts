import { GameMasterBackendError } from "./errors";
import type { GmAction } from "./stateEffects";

export const GM_ACTION_TYPES = new Set([
  "narrate",
  "spawn_enemy",
  "move_enemy",
  "damage_enemy",
  "heal_enemy",
  "defeat_enemy",
  "damage_player",
  "heal_player",
  "give_item",
  "remove_item",
  "start_combat",
  "end_combat",
  "system_message",
  "request_roll",
  "apply_effect",
  "remove_effect",
  "finish_game",
  "set_music_mood",
]);

export const VALID_MUSIC_MOODS = new Set([
  "tavern",
  "exploration",
  "mystery",
  "tension",
]);

export type GmChoice = { label: string; action?: string };
export type GmResponse = {
  narration: string;
  actions: GmAction[];
  choices: GmChoice[];
};

function asObject(value: unknown): Record<string, unknown> | null {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return null;
}

function foldMood(raw: Record<string, unknown>): Record<string, unknown> {
  const payload = asObject(raw.payload) ?? {};
  const mood = raw.mood ?? payload.mood;
  if (mood !== undefined) {
    payload.mood = mood;
  }
  return payload;
}

export function parseGameMasterResponse(decoded: unknown): GmResponse {
  const data = asObject(decoded);
  if (data === null) {
    throw new GameMasterBackendError(
      "OpenRouter returned an invalid game master payload.",
    );
  }
  const narration = String(data.narration ?? "");
  if (narration.length < 1 || narration.length > 4000) {
    throw new GameMasterBackendError(
      "OpenRouter returned an invalid game master payload.",
    );
  }
  const rawActions = data.actions;
  if (rawActions !== undefined && !Array.isArray(rawActions)) {
    throw new GameMasterBackendError(
      "OpenRouter returned an invalid game master payload.",
    );
  }
  const actionsIn = Array.isArray(rawActions) ? rawActions : [];
  if (actionsIn.length > 12) {
    throw new GameMasterBackendError(
      "OpenRouter returned an invalid game master payload.",
    );
  }
  const actions: GmAction[] = [];
  for (const item of actionsIn) {
    const mapped = asObject(item);
    if (mapped === null || typeof mapped.type !== "string") {
      throw new GameMasterBackendError(
        "OpenRouter returned an invalid game master payload.",
      );
    }
    if (!GM_ACTION_TYPES.has(mapped.type)) {
      throw new GameMasterBackendError(
        "OpenRouter returned an invalid game master payload.",
      );
    }
    const payload = foldMood(mapped);
    if (mapped.type === "set_music_mood") {
      const mood = String(payload.mood ?? "")
        .trim()
        .toLowerCase();
      if (!VALID_MUSIC_MOODS.has(mood)) {
        continue;
      }
    }
    actions.push({ type: mapped.type, payload });
  }

  const rawChoices = data.choices;
  if (rawChoices !== undefined && !Array.isArray(rawChoices)) {
    throw new GameMasterBackendError(
      "OpenRouter returned an invalid game master payload.",
    );
  }
  const choicesIn = Array.isArray(rawChoices) ? rawChoices : [];
  if (choicesIn.length > 6) {
    throw new GameMasterBackendError(
      "OpenRouter returned an invalid game master payload.",
    );
  }
  const choices: GmChoice[] = [];
  for (const item of choicesIn) {
    const mapped = asObject(item);
    if (mapped === null || typeof mapped.label !== "string") {
      throw new GameMasterBackendError(
        "OpenRouter returned an invalid game master payload.",
      );
    }
    const label = mapped.label;
    if (label.length < 1 || label.length > 160) {
      throw new GameMasterBackendError(
        "OpenRouter returned an invalid game master payload.",
      );
    }
    const choice: GmChoice = { label };
    if (typeof mapped.action === "string") {
      if (mapped.action.length > 240) {
        throw new GameMasterBackendError(
          "OpenRouter returned an invalid game master payload.",
        );
      }
      choice.action = mapped.action;
    }
    choices.push(choice);
  }
  return { narration, actions, choices };
}

export type GeneratedScenario = {
  title: string;
  setting: string;
  tone: string;
  public_objective: string;
  starting_location: { name: string; description: string };
  initial_situation: string;
  known_facts: string[];
  starting_npcs: Array<{ name: string; role: string }>;
  initial_threats: Array<{ name: string; hint: string }>;
  opening_narration: string;
  gm_secrets: string[];
};

function clipString(value: unknown, max: number, fallback = ""): string {
  return String(value ?? fallback).trim().slice(0, max);
}

export function parseGeneratedScenario(decoded: unknown): GeneratedScenario {
  const data = asObject(decoded);
  if (data === null) {
    throw new GameMasterBackendError(
      "OpenRouter returned an invalid scenario payload.",
    );
  }
  const title = clipString(data.title, 80);
  const setting = clipString(data.setting, 800);
  const publicObjective = clipString(data.public_objective, 400);
  const opening = clipString(data.opening_narration, 2000);
  const location = asObject(data.starting_location);
  const locName = clipString(location?.name, 80);
  if (!title || !setting || !publicObjective || !opening || !locName) {
    throw new GameMasterBackendError(
      "OpenRouter returned an invalid scenario payload.",
    );
  }
  const secretsRaw = Array.isArray(data.gm_secrets) ? data.gm_secrets : [];
  const knownRaw = Array.isArray(data.known_facts) ? data.known_facts : [];
  const npcsRaw = Array.isArray(data.starting_npcs) ? data.starting_npcs : [];
  const threatsRaw = Array.isArray(data.initial_threats)
    ? data.initial_threats
    : [];
  return {
    title,
    setting,
    tone: clipString(data.tone, 80),
    public_objective: publicObjective,
    starting_location: {
      name: locName,
      description: clipString(location?.description, 400),
    },
    initial_situation: clipString(data.initial_situation, 800),
    known_facts: knownRaw
      .filter((item): item is string => typeof item === "string")
      .map((item) => item.trim())
      .filter(Boolean)
      .slice(0, 12),
    starting_npcs: npcsRaw
      .map((item) => asObject(item))
      .filter((item): item is Record<string, unknown> => item !== null)
      .map((item) => ({
        name: clipString(item.name, 80),
        role: clipString(item.role, 120),
      }))
      .filter((item) => item.name.length > 0)
      .slice(0, 8),
    initial_threats: threatsRaw
      .map((item) => asObject(item))
      .filter((item): item is Record<string, unknown> => item !== null)
      .map((item) => ({
        name: clipString(item.name, 80),
        hint: clipString(item.hint, 200),
      }))
      .filter((item) => item.name.length > 0)
      .slice(0, 8),
    opening_narration: opening,
    gm_secrets: secretsRaw
      .filter((item): item is string => typeof item === "string")
      .map((item) => item.trim().slice(0, 240))
      .filter(Boolean)
      .slice(0, 12),
  };
}

const HIDDEN_WORLD_KEYS = new Set(["gm_secrets", "gm_state", "secrets", "secret"]);

export function publicWorldState(
  value: unknown,
): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  const output: Record<string, unknown> = {};
  for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
    if (HIDDEN_WORLD_KEYS.has(key)) {
      continue;
    }
    output[key] = item;
  }
  return output;
}

export function generatedPublicDict(
  generated: GeneratedScenario,
): Record<string, unknown> {
  const data = { ...generated } as Record<string, unknown>;
  delete data.gm_secrets;
  return data;
}
