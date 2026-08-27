-- RLS players_update : propre ligne seulement.
-- Executer manuellement. Ne pas ecraser supabase/schema.sql.
-- Le backend (service role) contourne RLS ; les potions / deplacements client restent possibles sur SA ligne.
-- Drop aussi l'ancienne policy owner_or_host si elle a ete collee a la main.

drop policy if exists "players_update" on players;
drop policy if exists "players_update_owner_or_host" on players;

create policy "players_update"
on players for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create or replace function public.enforce_player_row_identity()
returns trigger
language plpgsql
as $$
begin
  if new.room_id is distinct from old.room_id
     or new.user_id is distinct from old.user_id then
    raise exception 'Impossible de reassigner une figurine.'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_player_row_identity on players;

create trigger trg_enforce_player_row_identity
before update on players
for each row
execute function public.enforce_player_row_identity();
