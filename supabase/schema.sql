-- Schéma Supabase pour JdR Mobile
-- Exécuter dans l'éditeur SQL Supabase après création du projet

create table if not exists rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  scenario text,
  status text default 'waiting' check (status in ('waiting', 'playing', 'finished')),
  created_at timestamptz default now(),
  host_id uuid references auth.users(id)
);

create table if not exists players (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references rooms(id) on delete cascade,
  user_id uuid references auth.users(id),
  figurine_id integer not null check (figurine_id >= 0 and figurine_id <= 39),
  figurine_name text not null,
  position_x float default 0.5 check (position_x >= 0 and position_x <= 1),
  position_y float default 0.5 check (position_y >= 0 and position_y <= 1),
  hp integer default 100 check (hp >= 0),
  inventory jsonb default '[]'::jsonb,
  joined_at timestamptz default now()
);

create table if not exists game_events (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references rooms(id) on delete cascade,
  player_id uuid references players(id),
  type text not null check (type in ('action', 'narration', 'system')),
  content text not null,
  created_at timestamptz default now()
);

create index if not exists idx_players_room_id on players(room_id);
create index if not exists idx_game_events_room_id on game_events(room_id);
create index if not exists idx_rooms_status on rooms(status);

alter table rooms enable row level security;
alter table players enable row level security;
alter table game_events enable row level security;

-- Politiques MVP : accès ouvert aux utilisateurs authentifiés (y compris anonymes)
create policy "rooms_select" on rooms for select to authenticated using (true);
create policy "rooms_insert" on rooms for insert to authenticated with check (auth.uid() = host_id);
create policy "rooms_update" on rooms for update to authenticated using (true);

create policy "players_select" on players for select to authenticated using (true);
create policy "players_insert" on players for insert to authenticated with check (auth.uid() = user_id);
create policy "players_update" on players for update to authenticated using (true);

create policy "events_select" on game_events for select to authenticated using (true);
create policy "events_insert" on game_events for insert to authenticated with check (true);

-- Realtime
alter publication supabase_realtime add table rooms;
alter publication supabase_realtime add table players;
alter publication supabase_realtime add table game_events;
