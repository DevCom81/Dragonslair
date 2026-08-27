-- Pause host-only. Executer manuellement. Ne pas ecraser supabase/schema.sql.

do $$
declare
  cname text;
begin
  select conname into cname
  from pg_constraint
  where conrelid = 'public.rooms'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) ilike '%waiting%'
    and pg_get_constraintdef(oid) ilike '%playing%'
    and pg_get_constraintdef(oid) ilike '%finished%'
    and pg_get_constraintdef(oid) not ilike '%paused%';
  if cname is not null then
    execute format('alter table public.rooms drop constraint %I', cname);
  end if;
end $$;

alter table rooms drop constraint if exists rooms_status_check;

alter table rooms
  add constraint rooms_status_check
  check (status in ('waiting', 'playing', 'paused', 'finished'));

drop policy if exists "rooms_update" on rooms;

create policy "rooms_update"
on rooms for update
to authenticated
using (host_id = auth.uid())
with check (host_id = auth.uid());

create or replace function public.enforce_join_only_while_waiting()
returns trigger
language plpgsql
as $$
declare
  room_status text;
begin
  select rooms.status into room_status
  from rooms
  where rooms.id = new.room_id;

  if room_status is distinct from 'waiting' then
    raise exception 'Impossible de rejoindre une partie deja lancee.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_join_only_while_waiting on players;

create trigger trg_enforce_join_only_while_waiting
before insert on players
for each row
execute function public.enforce_join_only_while_waiting();
