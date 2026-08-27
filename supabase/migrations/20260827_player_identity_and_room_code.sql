-- Migration recommandee : identite joueur + code de room + RLS ciblees.
-- A executer manuellement dans l'editeur SQL Supabase apres validation.
-- Ne pas ecraser supabase/schema.sql.
--
-- Avant execution, verifier les doublons :
--   select room_id, user_id, count(*) from players group by 1, 2 having count(*) > 1;
--   select room_id, figurine_id, count(*) from players group by 1, 2 having count(*) > 1;
--   select count(*) from players where user_id is null;

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 2 and 32),
  created_at timestamptz not null default now()
);

alter table profiles enable row level security;

alter table rooms
  add column if not exists join_code text;

update rooms
set join_code = upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6))
where join_code is null or btrim(join_code) = '';

alter table rooms
  alter column join_code set not null;

create unique index if not exists rooms_join_code_key on rooms (join_code);
create index if not exists idx_rooms_join_code on rooms (join_code);

do $$
begin
  alter table players alter column user_id set not null;
exception
  when not_null_violation then
    raise exception 'players.user_id contient des null. Nettoie ces lignes avant de relancer.';
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'players_room_user_unique'
      and conrelid = 'public.players'::regclass
  ) then
    alter table players add constraint players_room_user_unique unique (room_id, user_id);
  end if;
exception
  when unique_violation then
    raise exception 'Doublons (room_id, user_id) dans players.';
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'players_room_figurine_unique'
      and conrelid = 'public.players'::regclass
  ) then
    alter table players add constraint players_room_figurine_unique unique (room_id, figurine_id);
  end if;
exception
  when unique_violation then
    raise exception 'Doublons (room_id, figurine_id) dans players.';
end $$;

create or replace function public.is_room_host(target_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from rooms
    where rooms.id = target_room_id
      and rooms.host_id = auth.uid()
  );
$$;

create or replace function public.is_room_participant(target_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from players
    where players.room_id = target_room_id
      and players.user_id = auth.uid()
  );
$$;

drop policy if exists "profiles_select" on profiles;
drop policy if exists "profiles_insert" on profiles;
drop policy if exists "profiles_update" on profiles;

create policy "profiles_select"
on profiles for select
to authenticated
using (true);

create policy "profiles_insert"
on profiles for insert
to authenticated
with check (auth.uid() = id);

create policy "profiles_update"
on profiles for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "rooms_select" on rooms;

create policy "rooms_select"
on rooms for select
to authenticated
using (
  status = 'waiting'
  or host_id = auth.uid()
  or public.is_room_participant(id)
);

drop policy if exists "players_select" on players;

create policy "players_select"
on players for select
to authenticated
using (
  public.is_room_host(room_id)
  or public.is_room_participant(room_id)
  or exists (
    select 1
    from rooms
    where rooms.id = players.room_id
      and rooms.status = 'waiting'
  )
);

drop policy if exists "events_select" on game_events;

create policy "events_select"
on game_events for select
to authenticated
using (
  public.is_room_host(room_id)
  or public.is_room_participant(room_id)
);
