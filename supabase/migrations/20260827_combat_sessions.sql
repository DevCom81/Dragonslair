-- Etat de combat MVP. Executer manuellement. Ne pas ecraser supabase/schema.sql.
-- Creation / mutation : service role (backend MJ) uniquement.
-- Lecture : hote ou participant de la room.
-- Une ligne par room (pas d'initiative complexe).

create table if not exists combat_sessions (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null unique references rooms(id) on delete cascade,
  active boolean not null default false,
  round integer not null default 0
    check (round >= 0 and round <= 999),
  started_at timestamptz,
  ended_at timestamptz,
  updated_at timestamptz not null default now()
);

create index if not exists idx_combat_sessions_room_id on combat_sessions(room_id);

create or replace function public.combat_sessions_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_combat_sessions_set_updated_at on combat_sessions;

create trigger trg_combat_sessions_set_updated_at
before update on combat_sessions
for each row
execute function public.combat_sessions_set_updated_at();

alter table combat_sessions enable row level security;

drop policy if exists "combat_sessions_select" on combat_sessions;

create policy "combat_sessions_select"
on combat_sessions for select
to authenticated
using (
  public.is_room_host(room_id)
  or public.is_room_participant(room_id)
);

do $$
begin
  alter publication supabase_realtime add table combat_sessions;
exception
  when duplicate_object then
    null;
end $$;
