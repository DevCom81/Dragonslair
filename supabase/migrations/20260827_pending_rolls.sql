-- Jets MJ synchronises. Executer manuellement. Ne pas ecraser supabase/schema.sql.
-- Creation / resolution : service role (backend) uniquement.
-- Lecture : hote ou participant de la room.

create table if not exists pending_rolls (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  player_id uuid not null references players(id) on delete cascade,
  ability text not null check (
    ability in (
      'strength',
      'dexterity',
      'constitution',
      'intelligence',
      'wisdom',
      'charisma'
    )
  ),
  dc integer not null check (dc >= 5 and dc <= 25),
  reason text not null default '',
  status text not null default 'pending'
    check (status in ('pending', 'resolved', 'cancelled')),
  result integer check (result is null or (result >= 1 and result <= 20)),
  modifier integer,
  total integer,
  success boolean,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index if not exists idx_pending_rolls_room_id on pending_rolls(room_id);
create index if not exists idx_pending_rolls_room_status
  on pending_rolls(room_id, status);
create index if not exists idx_pending_rolls_player_id on pending_rolls(player_id);

create unique index if not exists pending_rolls_one_open_per_player
  on pending_rolls (player_id)
  where status = 'pending';

alter table pending_rolls enable row level security;

drop policy if exists "pending_rolls_select" on pending_rolls;

create policy "pending_rolls_select"
on pending_rolls for select
to authenticated
using (
  public.is_room_host(room_id)
  or public.is_room_participant(room_id)
);

do $$
begin
  alter publication supabase_realtime add table pending_rolls;
exception
  when duplicate_object then
    null;
end $$;
