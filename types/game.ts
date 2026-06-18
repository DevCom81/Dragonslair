export type RoomStatus = 'waiting' | 'playing' | 'finished';
export type GameEventType = 'action' | 'narration' | 'system';

export interface Room {
  id: string;
  name: string;
  scenario: string | null;
  status: RoomStatus;
  created_at: string;
  host_id: string | null;
}

export interface Player {
  id: string;
  room_id: string;
  user_id: string | null;
  figurine_id: number;
  figurine_name: string;
  user_name?: string;
  position_x: number;
  position_y: number;
  hp: number;
  inventory: string[];
  joined_at: string;
}

export interface GameEvent {
  id: string;
  room_id: string;
  player_id: string | null;
  type: GameEventType;
  content: string;
  created_at: string;
}

export interface PendingMove {
  x: number;
  y: number;
}
