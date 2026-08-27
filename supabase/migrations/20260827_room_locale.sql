-- Langue de narration de la room. Executer manuellement. Ne pas ecraser supabase/schema.sql.
-- Une langue par partie, definie par l'hote a la creation. Fallback: en.

alter table rooms
  add column if not exists locale text not null default 'en';

update rooms
set locale = 'en'
where locale is null
   or locale not in ('fr', 'en', 'de', 'es');

alter table rooms drop constraint if exists rooms_locale_check;

alter table rooms
  add constraint rooms_locale_check
  check (locale in ('fr', 'en', 'de', 'es'));
