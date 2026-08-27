-- Compte persistant : pseudo unique + classe sur le profil.
-- Executer manuellement. Ne pas ecraser supabase/schema.sql.

do $$
begin
  if exists (
    select 1
    from profiles
    group by lower(btrim(display_name))
    having count(*) > 1
  ) then
    raise exception 'Doublons de display_name. Nettoie ces lignes avant de relancer.';
  end if;
end $$;

create unique index if not exists profiles_display_name_lower_key
  on profiles (lower(btrim(display_name)));

alter table profiles
  add column if not exists class_id text;
