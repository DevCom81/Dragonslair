-- Ambiance musicale partagee de la room (pas le combat).
-- Combat = combat_sessions.active. Executer manuellement. Ne pas ecraser supabase/schema.sql.

alter table rooms
  add column if not exists music_mood text not null default 'exploration';

update rooms
set music_mood = 'exploration'
where music_mood is null
   or music_mood not in ('tavern', 'exploration', 'mystery', 'tension');

alter table rooms drop constraint if exists rooms_music_mood_check;

alter table rooms
  add constraint rooms_music_mood_check
  check (music_mood in ('tavern', 'exploration', 'mystery', 'tension'));
