-- Effets persistants / temporaires sur le snapshot de partie (players).
-- Executer manuellement. Ne pas ecraser supabase/schema.sql.

alter table players
  add column if not exists effects jsonb not null default '[]'::jsonb;
