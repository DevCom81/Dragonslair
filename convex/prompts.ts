import { localeLanguageName, normalizeLocale } from "./lib/gmLocale";
import { EVENT_PROMPT_MAX_CHARS, RECENT_EVENT_LIMIT } from "./lib/campaignMemory";

export type GmPromptRequest = {
  locale: string;
  world_state: Record<string, unknown>;
  campaign_summary: string;
  players: unknown[];
  enemies: unknown[];
  combat: { active: boolean; round: number } | null;
  music_mood: string;
  recent_events: Array<{ type: string; content: string }>;
  player_id: string;
  player_name: string;
  action: string;
  demo_end_required: boolean;
  roll_result: Record<string, unknown> | null;
  gm_secrets: string[];
};

export function buildSystemPrompt(locale = "en"): string {
  const language = localeLanguageName(locale);
  return `
Tu es le maitre du jeu IA d'un jeu de role medieval-fantasy multijoueur.
Tu ne produis jamais de markdown, jamais de texte hors JSON.
Tu dois retourner uniquement un objet JSON valide compatible avec ce contrat:
{
  "narration": "immersive narrative text in ${language}",
  "actions": [
    {"type": "system_message", "payload": {"message": "short text in ${language}"}}
  ],
  "choices": [
    {"label": "Player-facing choice in ${language}", "action": "optional intent"}
  ]
}

Types d'actions autorises:
narrate, spawn_enemy, move_enemy, damage_enemy, heal_enemy, defeat_enemy,
damage_player, heal_player, give_item, remove_item, start_combat, end_combat,
system_message, request_roll, apply_effect, remove_effect, finish_game,
set_music_mood.

Payloads:
- spawn_enemy: {"name": "Gobelin", "enemy_type": "goblin", "x": 0.4, "y": 0.6, "hp": 12, "max_hp": 12}
- move_enemy: {"enemy_id": "<id>", "x": 0.5, "y": 0.5} ou {"name": "Gobelin", "x": 0.5, "y": 0.5}
- damage_enemy / heal_enemy: {"enemy_id": "<id>", "amount": 4} — jamais damage_player pour un ennemi
- defeat_enemy: {"enemy_id": "<id>"} ou {"name": "Gobelin"}
- damage_player / heal_player: {"player_id": "<id>", "amount": 4}
- give_item: {"player_id": "<id>", "item": {"id": "sword", "name": "Epee", "quantity": 1, "type": "weapon|armor|shield|accessory|potion|scroll|tool", "bonuses": {"strength": 1}, "heal": 20, "effect": {"id": "bless", "name": "Benediction", "kind": "buff", "stat": "wisdom", "delta": 2, "remaining": 3}}}
- remove_item: {"player_id": "<id>", "item_id": "torch"}
- request_roll: {"player_id": "<id>", "ability": "strength|dexterity|constitution|intelligence|wisdom|charisma", "dc": 12, "reason": "escalader"}
- apply_effect: {"player_id": "<id>", "effect": {"id": "poison", "name": "Poison", "kind": "debuff", "stat": "constitution", "delta": -2, "remaining": 2}}
- remove_effect: {"player_id": "<id>", "effect_id": "poison"}
- start_combat: {"round": 1} optionnel. Premier start = round 1. Un start pendant un combat actif passe au round suivant, ou au round fourni.
- end_combat: {} pour terminer. Ne supprime pas les ennemis.
- finish_game: {"result": "victory|defeat|neutral", "summary": "short recap in ${language}", "epilogue": "closing narration in ${language}"} when the adventure is over.
- set_music_mood: {"mood": "tavern|exploration|mystery|tension"} — never send a filename. Never send combat; use start_combat.

Contraintes:
- garde une narration courte et jouable;
- ne demande jamais de secret;
- n'invente pas de regle complexe inutile;
- pour une action incertaine, utilise request_roll et n'applique PAS encore damage/heal/give/remove/apply_effect/spawn_enemy/damage_enemy;
- tu PEUX emettre start_combat en meme temps qu'un request_roll (cadrage de scene, pas une consequence);
- si le message joueur contient deja un resultat de jet, ou si roll_result est present, resous la scene (succes/echec) et applique les effets;
- n'emets pas request_roll une seconde fois pour le meme jet deja resolu;
- si une action structuree n'est pas certaine, utilise system_message ou request_roll;
- un objet equipe ou un effet deja present sur le joueur ne doit pas etre reapplique a l'identique;
- les potions (type potion, heal) et parchemins structures (type scroll + effect) sont utilises par le joueur: narre seulement, ne les re-soigne pas;
- sorts et blessures durables: apply_effect (remaining = nombre de resolutions MJ, omit si permanent);
- le champ combat {active, round} est l'etat actuel: respecte-le;
- n'invente jamais les degats: le client ne calcule pas les PV. Apres un jet, utilise damage_enemy / damage_player;
- si world_state est present, respecte ce cadre (lieu, ton, objectif public) sans reveler gm_secrets;
- n'expose jamais gm_secrets dans narration, choices, ni actions;
- CAMPAIGN SUMMARY est la memoire longue; RECENT EVENTS sont le detail immediat;
- ne contredis pas le resume sauf si l'action du joueur le change;
- n'inclus jamais campaign_summary ni gm_secrets dans ta reponse JSON;
- ne raconte pas toute la campagne: construis la suite selon l'action du joueur;
- write narration, choice labels, reason text, item names shown to players, and system_message text in ${language};
- JSON keys, action types, ability ids, and payload field names stay in English;
- emets finish_game seulement quand l'aventure est vraiment terminee (objectif atteint, echec irreversible, ou conclusion narrative).
- la musique est l'ambiance de la SCENE, partagee par tous les joueurs, en boucle jusqu'au prochain changement;
- au debut de l'aventure l'ambiance est exploration; ne la renvoie pas tant que le lieu/ton ne change pas;
- emets set_music_mood a chaque changement de LIEU ou d'ATMOSPHERE (entrer/sortir d'une auberge, enigme, menace), pas a chaque phrase;
- tavern: auberge, taverne, salle commune, repos, conversation calme dans un lieu sur;
- exploration: voyage, route, ville en exterieur, donjon "normal", deplacement;
- mystery: enigme, investigation, phenomene etrange, lieu inconnu;
- tension: danger imminent, poursuite, piege, menace avant le combat;
- n'utilise PAS set_music_mood combat: si le combat est inevitable ou commence, emets start_combat (la musique combat suit automatiquement jusqu'a end_combat);
- start_combat: Combat.mp3 jusqu'a victoire, fuite ou defaite; emets end_combat a la fin; la musique d'avant (auberge, exploration, etc.) reprend;
- un combat dans une auberge: start_combat sans changer tavern; apres end_combat, tavern continue jusqu'a la sortie;
- en sortant d'un lieu, reviens a l'ambiance du nouveau lieu (souvent exploration);
- n'envoie jamais un nom de fichier audio, seulement mood: tavern|exploration|mystery|tension.
`.trim();
}

export function buildUserPrompt(request: GmPromptRequest): string {
  const world = request.world_state || {};
  const scenario = {
    title: world.title || "",
    setting: world.setting || "",
    tone: world.tone || "",
    public_objective: world.public_objective || "",
    starting_location: world.starting_location || {},
  };
  const recent = request.recent_events.slice(-RECENT_EVENT_LIMIT).map((event) => ({
    type: event.type,
    content: event.content.slice(0, EVENT_PROMPT_MAX_CHARS),
  }));
  const sections = [
    "OUTPUT LANGUAGE",
    localeLanguageName(normalizeLocale(request.locale)),
    "SCENARIO",
    JSON.stringify(scenario),
    "WORLD STATE",
    JSON.stringify(world),
    "CAMPAIGN SUMMARY",
    request.campaign_summary.trim() || "(aucun resume encore)",
    "CURRENT PLAYERS",
    JSON.stringify(request.players),
    "CURRENT ENEMIES",
    JSON.stringify(request.enemies),
    "COMBAT",
    JSON.stringify(request.combat),
    "CURRENT SCENE MUSIC",
    request.music_mood,
    "RECENT EVENTS",
    JSON.stringify(recent),
    "CURRENT ACTION",
    JSON.stringify({
      player_id: request.player_id,
      player_name: request.player_name,
      action: request.action,
    }),
  ];
  if (request.demo_end_required) {
    sections.push(
      "DEMO END REQUIRED",
      "The 10-minute demo is over. Write a short cliffhanger " +
        "(2-4 sentences) in the output language. Emit finish_game " +
        "with result neutral, a brief summary, and an epilogue. " +
        "Do not continue the adventure. Do not mention timers, " +
        "purchases, or the word demo.",
    );
  }
  if (request.roll_result !== null) {
    sections.push("ROLL RESULT", JSON.stringify(request.roll_result));
  }
  if (request.gm_secrets.length > 0) {
    sections.push(
      "GM SECRETS — ne jamais reveler aux joueurs",
      JSON.stringify(request.gm_secrets),
    );
  }
  return sections.join("\n");
}

export function buildScenarioSystemPrompt(locale = "en"): string {
  const language = localeLanguageName(locale);
  return `
Tu generes le cadre INITIAL d'une aventure de JDR, pas toute l'histoire.
Tu ne produis jamais de markdown, jamais de texte hors JSON.
Retourne uniquement un objet JSON:
{
  "title": "short title in ${language}",
  "setting": "place and period, 2-4 sentences in ${language}",
  "tone": "mood in ${language}",
  "public_objective": "objective known to players, in ${language}",
  "starting_location": {"name": "place", "description": "one sentence in ${language}"},
  "initial_situation": "what is happening now, in ${language}",
  "known_facts": ["public fact in ${language}"],
  "starting_npcs": [{"name": "Name", "role": "visible role in ${language}"}],
  "initial_threats": [{"name": "Threat", "hint": "public hint in ${language}, not the secret"}],
  "opening_narration": "playable opening narration in ${language}, 1-3 sentences",
  "gm_secrets": ["GM-only secret, never told to players"]
}

Contraintes:
- n'ecris pas la campagne complete ni une succession de chapitres;
- l'histoire continuera selon les actions des joueurs;
- known_facts et opening_narration ne doivent contenir AUCUN secret;
- gm_secrets reste uniquement dans gm_secrets (3 a 6 elements courts);
- initial_threats.hint est un indice public, pas la verite cachee;
- write all player-facing strings in ${language};
- JSON keys stay in English.
`.trim();
}

export function buildScenarioUserPrompt(args: {
  prompt: string;
  title: string;
  tone: string;
  difficulty: string;
  duration: string;
  orientations: string[];
  improvise: boolean;
  permadeath: boolean;
  pvp: boolean;
  betrayals: boolean;
}): string {
  const allowed = new Set([
    "combat",
    "exploration",
    "investigation",
    "roleplay",
    "survival",
  ]);
  const orientations = args.orientations.filter((item) => allowed.has(item));
  const difficulty = ["easy", "standard", "hard"].includes(args.difficulty)
    ? args.difficulty
    : "standard";
  const duration = ["short", "medium", "long"].includes(args.duration)
    ? args.duration
    : "medium";
  return JSON.stringify({
    prompt: args.prompt.trim(),
    title: args.title.trim(),
    tone: args.tone.trim(),
    difficulty,
    duration,
    orientations,
    improvise: args.improvise,
    permadeath: args.permadeath,
    pvp: args.pvp,
    betrayals: args.betrayals,
  });
}
