-- Chrono demo : 10 minutes de jeu effectif. Pause room = freeze.
-- Executer manuellement. Ne pas ecraser supabase/schema.sql.

alter table demo_sessions
  add column if not exists paused_at timestamptz;

create or replace function public.sync_demo_clock_on_room_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'paused' and old.status is distinct from 'paused' then
    update demo_sessions
    set paused_at = now()
    where room_id = new.id
      and started_at is not null
      and completed_at is null
      and paused_at is null;
  elsif old.status = 'paused' and new.status = 'playing' then
    update demo_sessions
    set expires_at = expires_at + (now() - paused_at),
        paused_at = null
    where room_id = new.id
      and paused_at is not null
      and expires_at is not null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_demo_clock_on_room_status on rooms;
create trigger trg_sync_demo_clock_on_room_status
after update of status on rooms
for each row
execute function public.sync_demo_clock_on_room_status();

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
  effective_now timestamptz;
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
    if room_status = 'paused' then
      return 'ok';
    end if;
    insert into demo_sessions (user_id, room_id, started_at, expires_at)
    values (auth.uid(), target_room_id, now(), now() + interval '10 minutes');
    return 'ok';
  end if;

  if sess.completed_at is not null then
    return 'expired';
  end if;

  if sess.started_at is null then
    if room_status = 'paused' then
      return 'ok';
    end if;
    update demo_sessions
    set started_at = now(),
        expires_at = now() + interval '10 minutes',
        room_id = coalesce(room_id, target_room_id)
    where user_id = auth.uid();
    return 'ok';
  end if;

  effective_now := coalesce(sess.paused_at, now());
  if sess.expires_at is not null and effective_now < sess.expires_at then
    return 'ok';
  end if;

  return 'expired';
end;
$$;

grant execute on function public.ensure_demo_play(uuid) to authenticated;
