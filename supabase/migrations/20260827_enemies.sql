-- Ennemis persistants. Executer manuellement. Ne pas ecraser supabase/schema.sql.
-- Mutations INSERT/UPDATE/DELETE : service role (backend MJ) uniquement.
-- Les clients authentifies peuvent seulement LIRE les ennemis de leur room.

create table if not exists enemies (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 80),
  enemy_type text not null check (char_length(trim(enemy_type)) between 1 and 40),
  position_x float not null default 0.5 check (position_x >= 0 and position_x <= 1),
  position_y float not null default 0.5 check (position_y >= 0 and position_y <= 1),
  hp integer not null default 20 check (hp >= 0),
  max_hp integer not null default 20 check (max_hp >= 1),
  status text not null default 'active'
    check (status in ('active', 'defeated', 'escaped')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint enemies_hp_within_max check (hp <= max_hp)
);

create index if not exists idx_enemies_room_id on enemies(room_id);
create index if not exists idx_enemies_room_status on enemies(room_id, status);

create or replace function public.enemies_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_enemies_set_updated_at on enemies;

create trigger trg_enemies_set_updated_at
before update on enemies
for each row
execute function public.enemies_set_updated_at();

alter table enemies enable row level security;

drop policy if exists "enemies_select" on enemies;

create policy "enemies_select"
on enemies for select
to authenticated
using (
  public.is_room_host(room_id)
  or public.is_room_participant(room_id)
);

do $$
begin
  alter publication supabase_realtime add table enemies;
exception
  when duplicate_object then
    null;
end $$;
