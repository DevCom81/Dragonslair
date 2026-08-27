-- Scenarios libres. Executer manuellement. Ne pas ecraser supabase/schema.sql.
-- world_state : lisible par hote/participant (faits publics).
-- gm_secrets : table separee, service role uniquement. Aucune policy SELECT client.

alter table rooms
  add column if not exists scenario_prompt text not null default '',
  add column if not exists world_state jsonb not null default '{}'::jsonb;

create table if not exists room_gm_state (
  room_id uuid primary key references rooms(id) on delete cascade,
  gm_secrets jsonb not null default '[]'::jsonb,
  gm_state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create or replace function public.room_gm_state_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_room_gm_state_set_updated_at on room_gm_state;

create trigger trg_room_gm_state_set_updated_at
before update on room_gm_state
for each row
execute function public.room_gm_state_set_updated_at();

alter table room_gm_state enable row level security;
