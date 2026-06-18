import * as SecureStore from 'expo-secure-store';
import { create } from 'zustand';

import { buildSystemPrompt } from '@/constants/gameRules';
import { parseMJResponse } from '@/lib/mjParser';
import { callMJ, type Message } from '@/lib/openrouter';
import { ensureAuthSession, isSupabaseConfigured, supabase } from '@/lib/supabase';
import type { GameEvent, PendingMove, Player, Room } from '@/types/game';

const API_KEY_STORAGE = 'openrouter_api_key';
const MODEL_STORAGE = 'openrouter_model';
const DEFAULT_MODEL = 'anthropic/claude-3.5-sonnet';
const HISTORY_LIMIT = 10;

interface GameState {
  currentPlayer: Player | null;
  room: Room | null;
  players: Player[];
  events: GameEvent[];
  isWaitingForMJ: boolean;
  isConnected: boolean;
  pendingMove: PendingMove | null;
  openrouterApiKey: string;
  selectedModel: string;
  setRoom: (room: Room | null) => void;
  setPlayers: (players: Player[]) => void;
  setEvents: (events: GameEvent[]) => void;
  addEvent: (event: GameEvent) => void;
  setCurrentPlayer: (player: Player | null) => void;
  setConnected: (connected: boolean) => void;
  setPendingMove: (move: PendingMove | null) => void;
  loadSettings: () => Promise<void>;
  setApiKey: (key: string) => Promise<void>;
  setModel: (model: string) => Promise<void>;
  submitAction: (action: string) => Promise<void>;
  requestMove: (x: number, y: number) => Promise<void>;
  subscribeToRoom: (roomId: string) => () => void;
  refreshRoomData: (roomId: string) => Promise<void>;
}

function normalizePlayer(row: Record<string, unknown>): Player {
  return {
    id: String(row.id),
    room_id: String(row.room_id),
    user_id: row.user_id ? String(row.user_id) : null,
    figurine_id: Number(row.figurine_id),
    figurine_name: String(row.figurine_name),
    user_name: row.user_name ? String(row.user_name) : undefined,
    position_x: Number(row.position_x),
    position_y: Number(row.position_y),
    hp: Number(row.hp),
    inventory: Array.isArray(row.inventory)
      ? (row.inventory as string[])
      : [],
    joined_at: String(row.joined_at),
  };
}

function eventsToHistory(events: GameEvent[]): Message[] {
  return events.slice(-HISTORY_LIMIT).map((event) => {
    if (event.type === 'narration') {
      return { role: 'assistant' as const, content: event.content };
    }
    return { role: 'user' as const, content: event.content };
  });
}

async function applyParsedEffects(
  parsed: ReturnType<typeof parseMJResponse>,
  players: Player[],
  currentPlayer: Player | null,
  pendingMove: PendingMove | null,
) {
  for (const hpChange of parsed.hpChanges) {
    const target = players.find(
      (p) => p.figurine_name.toLowerCase() === hpChange.figurineName.toLowerCase(),
    );
    if (target) {
      await supabase
        .from('players')
        .update({ hp: Math.max(0, target.hp + hpChange.delta) })
        .eq('id', target.id);
    }
  }

  for (const invChange of parsed.inventoryChanges) {
    const target = players.find(
      (p) => p.figurine_name.toLowerCase() === invChange.figurineName.toLowerCase(),
    );
    if (target) {
      await supabase
        .from('players')
        .update({ inventory: [...target.inventory, invChange.item] })
        .eq('id', target.id);
    }
  }

  if (parsed.movementAccepted === true && currentPlayer && pendingMove) {
    await supabase
      .from('players')
      .update({
        position_x: pendingMove.x,
        position_y: pendingMove.y,
      })
      .eq('id', currentPlayer.id);
  }
}

export const useGameStore = create<GameState>((set, get) => ({
  currentPlayer: null,
  room: null,
  players: [],
  events: [],
  isWaitingForMJ: false,
  isConnected: true,
  pendingMove: null,
  openrouterApiKey: '',
  selectedModel: DEFAULT_MODEL,

  setRoom: (room) => set({ room }),
  setPlayers: (players) => set({ players }),
  setEvents: (events) => set({ events }),
  addEvent: (event) =>
    set((state) => ({ events: [...state.events, event] })),
  setCurrentPlayer: (player) => set({ currentPlayer: player }),
  setConnected: (connected) => set({ isConnected: connected }),
  setPendingMove: (move) => set({ pendingMove: move }),

  loadSettings: async () => {
    const [apiKey, model] = await Promise.all([
      SecureStore.getItemAsync(API_KEY_STORAGE),
      SecureStore.getItemAsync(MODEL_STORAGE),
    ]);
    set({
      openrouterApiKey: apiKey ?? '',
      selectedModel: model ?? DEFAULT_MODEL,
    });
  },

  setApiKey: async (key) => {
    await SecureStore.setItemAsync(API_KEY_STORAGE, key);
    set({ openrouterApiKey: key });
  },

  setModel: async (model) => {
    await SecureStore.setItemAsync(MODEL_STORAGE, model);
    set({ selectedModel: model });
  },

  refreshRoomData: async (roomId) => {
    const [roomRes, playersRes, eventsRes] = await Promise.all([
      supabase.from('rooms').select('*').eq('id', roomId).single(),
      supabase.from('players').select('*').eq('room_id', roomId),
      supabase
        .from('game_events')
        .select('*')
        .eq('room_id', roomId)
        .order('created_at', { ascending: true }),
    ]);

    if (roomRes.data) {
      set({ room: roomRes.data as Room });
    }
    if (playersRes.data) {
      set({ players: playersRes.data.map(normalizePlayer) });
    }
    if (eventsRes.data) {
      set({ events: eventsRes.data as GameEvent[] });
    }
  },

  subscribeToRoom: (roomId) => {
    const channel = supabase
      .channel(`room-${roomId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'rooms', filter: `id=eq.${roomId}` },
        (payload) => {
          if (payload.new) {
            set({ room: payload.new as Room });
          }
        },
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'players', filter: `room_id=eq.${roomId}` },
        async () => {
          const { data } = await supabase
            .from('players')
            .select('*')
            .eq('room_id', roomId);
          if (data) {
            set({ players: data.map(normalizePlayer) });
          }
        },
      )
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'game_events', filter: `room_id=eq.${roomId}` },
        (payload) => {
          const event = payload.new as GameEvent;
          set((state) => {
            if (state.events.some((e) => e.id === event.id)) {
              return state;
            }
            return { events: [...state.events, event], isWaitingForMJ: false };
          });
        },
      )
      .subscribe((status) => {
        set({ isConnected: status === 'SUBSCRIBED' });
      });

    return () => {
      supabase.removeChannel(channel);
    };
  },

  submitAction: async (action) => {
    const { room, currentPlayer, events, openrouterApiKey, selectedModel, pendingMove, players } =
      get();

    if (!room || !currentPlayer || !action.trim()) {
      return;
    }

    if (!isSupabaseConfigured) {
      throw new Error('Supabase non configuré');
    }

    const session = await ensureAuthSession();
    const userMessage = `[${currentPlayer.figurine_name}] : ${action.trim()}`;

    const { data: actionEvent, error } = await supabase
      .from('game_events')
      .insert({
        room_id: room.id,
        player_id: currentPlayer.id,
        type: 'action',
        content: userMessage,
      })
      .select('*')
      .single();

    if (error) {
      throw error;
    }

    const nextEvents = [...events, actionEvent as GameEvent];
    set({ events: nextEvents, isWaitingForMJ: true });

    const isHost = session?.user?.id === room.host_id;
    if (!isHost) {
      return;
    }

    if (!openrouterApiKey) {
      set({ isWaitingForMJ: false });
      throw new Error('Clé OpenRouter manquante. Configurez-la dans Paramètres.');
    }

    try {
      const systemPrompt = buildSystemPrompt(room.scenario ?? '', players);
      const rawResponse = await callMJ({
        model: selectedModel,
        apiKey: openrouterApiKey,
        systemPrompt,
        history: eventsToHistory(nextEvents.slice(0, -1)),
        newUserMessage: userMessage,
      });

      const parsed = parseMJResponse(rawResponse);

      await supabase.from('game_events').insert({
        room_id: room.id,
        player_id: null,
        type: 'narration',
        content: parsed.narration || rawResponse,
      });

      await applyParsedEffects(parsed, players, currentPlayer, pendingMove);

      if (parsed.movementAccepted === false) {
        set({ pendingMove: null });
      } else if (parsed.movementAccepted === true) {
        set({ pendingMove: null });
      }
    } finally {
      set({ isWaitingForMJ: false });
    }
  },

  requestMove: async (x, y) => {
    const { currentPlayer } = get();
    if (!currentPlayer) {
      return;
    }

    set({ pendingMove: { x, y } });

    const zoneDescription = `position (${Math.round(x * 100)}%, ${Math.round(y * 100)}%)`;
    await get().submitAction(
      `tente de se déplacer vers ${zoneDescription}`,
    );
  },
}));

export { DEFAULT_MODEL, HISTORY_LIMIT };
