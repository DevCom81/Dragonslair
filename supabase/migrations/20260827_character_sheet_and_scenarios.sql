-- Fiche 6 caracs + regles de scenario (min joueurs, classes obligatoires).
-- Executer manuellement. Ne pas ecraser supabase/schema.sql.

alter table profiles
  add column if not exists strength integer not null default 10,
  add column if not exists dexterity integer not null default 10,
  add column if not exists constitution integer not null default 10,
  add column if not exists intelligence integer not null default 10,
  add column if not exists wisdom integer not null default 10,
  add column if not exists charisma integer not null default 10,
  add column if not exists sheet_confirmed boolean not null default false;

do $$
begin
  alter table profiles
    add constraint profiles_strength_range check (strength between 8 and 18);
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter table profiles
    add constraint profiles_dexterity_range check (dexterity between 8 and 18);
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter table profiles
    add constraint profiles_constitution_range check (constitution between 8 and 18);
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter table profiles
    add constraint profiles_intelligence_range check (intelligence between 8 and 18);
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter table profiles
    add constraint profiles_wisdom_range check (wisdom between 8 and 18);
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter table profiles
    add constraint profiles_charisma_range check (charisma between 8 and 18);
exception
  when duplicate_object then null;
end $$;

alter table rooms
  add column if not exists scenario_id text,
  add column if not exists min_players integer not null default 1,
  add column if not exists required_class_ids text[] not null default '{}';

do $$
begin
  alter table rooms
    add constraint rooms_min_players_positive check (min_players >= 1);
exception
  when duplicate_object then null;
end $$;

alter table players
  add column if not exists class_id text,
  add column if not exists strength integer not null default 10,
  add column if not exists dexterity integer not null default 10,
  add column if not exists constitution integer not null default 10,
  add column if not exists intelligence integer not null default 10,
  add column if not exists wisdom integer not null default 10,
  add column if not exists charisma integer not null default 10;

create unique index if not exists players_room_class_unique
  on players (room_id, class_id)
  where class_id is not null;

create or replace function public.enforce_room_start_rules()
returns trigger
language plpgsql
as $$
declare
  player_count integer;
  required_id text;
begin
  if new.status = 'playing' and (old.status is distinct from 'playing') then
    select count(*) into player_count
    from players
    where players.room_id = new.id;

    if player_count < new.min_players then
      raise exception 'Pas assez de joueurs (% / %).', player_count, new.min_players
        using errcode = 'P0001';
    end if;

    foreach required_id in array coalesce(new.required_class_ids, '{}') loop
      if not exists (
        select 1
        from players
        where players.room_id = new.id
          and players.class_id = required_id
      ) then
        raise exception 'Classe obligatoire manquante: %', required_id
          using errcode = 'P0001';
      end if;
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_room_start_rules on rooms;

create trigger trg_enforce_room_start_rules
before update of status on rooms
for each row
execute function public.enforce_room_start_rules();
