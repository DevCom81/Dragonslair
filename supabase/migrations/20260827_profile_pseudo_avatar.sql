-- Pseudo non unique + figurine d avatar sur le profil.
-- Executer manuellement. Ne pas ecraser supabase/schema.sql.

drop index if exists profiles_display_name_lower_key;

alter table profiles
  add column if not exists avatar_figurine_id integer;

do $$
begin
  alter table profiles
    add constraint profiles_avatar_figurine_id_range
    check (avatar_figurine_id is null or avatar_figurine_id between 0 and 39);
exception
  when duplicate_object then null;
end $$;

update players p
set figurine_name = pr.display_name
from profiles pr
where p.user_id = pr.id
  and p.figurine_name ~ '^Figurine [0-9]+$';
