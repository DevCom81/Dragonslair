-- Mode demo. Executer manuellement. Ne pas ecraser supabase/schema.sql.
-- Compte sans licence FULL : solo, scenario demo, 10 min de jeu effectif.
-- Le chrono demarre au premier appel ensure_demo_play (action MJ), pas a la fiche.
-- Profils deja presents : FULL / admin pour ne pas bloquer les parties en cours.
-- Nouveaux profils : demo / default.

create table if not exists user_entitlements (
  user_id uuid primary key references auth.users(id) on delete cascade,
  access_level text not null default 'demo'
    check (access_level in ('demo', 'full')),
  source text not null default 'default'
    check (source in ('default', 'purchase', 'admin', 'promo')),
  granted_at timestamptz not null default now(),
  expires_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

alter table user_entitlements enable row level security;

drop policy if exists "user_entitlements_select" on user_entitlements;
create policy "user_entitlements_select"
on user_entitlements for select
to authenticated
using (user_id = auth.uid());

create table if not exists demo_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  room_id uuid references rooms(id) on delete set null,
  started_at timestamptz,
  expires_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table demo_sessions enable row level security;

drop policy if exists "demo_sessions_select" on demo_sessions;
create policy "demo_sessions_select"
on demo_sessions for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "demo_sessions_insert" on demo_sessions;
create policy "demo_sessions_insert"
on demo_sessions for insert
to authenticated
with check (
  user_id = auth.uid()
  and started_at is null
  and expires_at is null
  and completed_at is null
);

create or replace function public.current_access_level()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select access_level
      from user_entitlements
      where user_id = auth.uid()
    ),
    'demo'
  );
$$;

grant execute on function public.current_access_level() to authenticated;

create or replace function public.ensure_default_entitlement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into user_entitlements (user_id, access_level, source)
  values (new.id, 'demo', 'default')
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_ensure_default_entitlement on profiles;
create trigger trg_ensure_default_entitlement
after insert on profiles
for each row
execute function public.ensure_default_entitlement();

insert into user_entitlements (user_id, access_level, source)
select id, 'full', 'admin'
from profiles
on conflict (user_id) do nothing;

do $$
declare
  cname text;
begin
  select conname into cname
  from pg_constraint
  where conrelid = 'public.rooms'::regclass
    and contype = 'c'
    and conname = 'rooms_status_check';
  if cname is not null then
    execute format('alter table public.rooms drop constraint %I', cname);
  end if;
end $$;

alter table rooms drop constraint if exists rooms_status_check;

alter table rooms
  add constraint rooms_status_check
  check (status in ('waiting', 'playing', 'paused', 'finished', 'demo_finished'));

create or replace function public.enforce_demo_room_create()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_access_level() = 'full' then
    return new;
  end if;
  if new.scenario_id is distinct from 'demo'
     or new.min_players is distinct from 1
     or coalesce(array_length(new.required_class_ids, 1), 0) > 0
     or btrim(coalesce(new.scenario_prompt, '')) <> '' then
    raise exception 'La demo est limitee au scenario solo.'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_demo_room_create on rooms;
create trigger trg_enforce_demo_room_create
before insert on rooms
for each row
execute function public.enforce_demo_room_create();

create or replace function public.bind_demo_session_on_room()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.scenario_id is distinct from 'demo' then
    return new;
  end if;
  if public.current_access_level() = 'full' then
    return new;
  end if;
  insert into demo_sessions (user_id, room_id)
  values (new.host_id, new.id);
  return new;
exception
  when unique_violation then
    raise exception 'La demo a deja ete utilisee.'
      using errcode = 'P0001';
end;
$$;

drop trigger if exists trg_bind_demo_session_on_room on rooms;
create trigger trg_bind_demo_session_on_room
after insert on rooms
for each row
execute function public.bind_demo_session_on_room();

create or replace function public.enforce_demo_join()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_access_level() = 'full' then
    return new;
  end if;
  if not exists (
    select 1
    from rooms
    where rooms.id = new.room_id
      and rooms.scenario_id = 'demo'
      and rooms.host_id = auth.uid()
      and new.user_id = auth.uid()
  ) then
    raise exception 'La demo est solo uniquement.'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_demo_join on players;
create trigger trg_enforce_demo_join
before insert on players
for each row
execute function public.enforce_demo_join();

create or replace function public.complete_demo_session_on_finish()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status in ('finished', 'demo_finished')
     and old.status is distinct from new.status then
    update demo_sessions
    set completed_at = coalesce(completed_at, now())
    where room_id = new.id
      and completed_at is null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_complete_demo_session_on_finish on rooms;
create trigger trg_complete_demo_session_on_finish
after update of status on rooms
for each row
execute function public.complete_demo_session_on_finish();

create or replace function public.ensure_demo_play(target_room_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  level text;
  room_host uuid;
  room_scenario text;
  room_status text;
  sess demo_sessions%rowtype;
begin
  if target_room_id is null then
    return 'forbidden';
  end if;

  level := public.current_access_level();

  select host_id, scenario_id, status
  into room_host, room_scenario, room_status
  from rooms
  where id = target_room_id;

  if room_host is null then
    return 'forbidden';
  end if;

  if room_status in ('finished', 'demo_finished') then
    return 'expired';
  end if;

  if level = 'full' then
    return 'ok';
  end if;

  if room_scenario is distinct from 'demo'
     or room_host is distinct from auth.uid() then
    return 'forbidden';
  end if;

  select * into sess
  from demo_sessions
  where user_id = auth.uid();

  if not found then
    insert into demo_sessions (user_id, room_id, started_at, expires_at)
    values (auth.uid(), target_room_id, now(), now() + interval '10 minutes');
    return 'ok';
  end if;

  if sess.completed_at is not null then
    return 'expired';
  end if;

  if sess.started_at is null then
    update demo_sessions
    set started_at = now(),
        expires_at = now() + interval '10 minutes',
        room_id = coalesce(room_id, target_room_id)
    where user_id = auth.uid();
    return 'ok';
  end if;

  if sess.expires_at is not null and now() < sess.expires_at then
    return 'ok';
  end if;

  return 'expired';
end;
$$;

grant execute on function public.ensure_demo_play(uuid) to authenticated;

drop policy if exists "rooms_select" on rooms;

create policy "rooms_select"
on rooms for select
to authenticated
using (
  (
    status = 'waiting'
    and coalesce(scenario_id, '') is distinct from 'demo'
  )
  or host_id = auth.uid()
  or public.is_room_participant(id)
);
