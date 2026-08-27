-- Fin de partie. Executer manuellement. Ne pas ecraser supabase/schema.sql.
-- started_at : deja ecrit au start cote Flutter ; on le cree s'il manque.
-- ending : resultat public (victory|defeat|neutral + resume + epilogue).

alter table rooms
  add column if not exists started_at timestamptz,
  add column if not exists finished_at timestamptz,
  add column if not exists game_phase text,
  add column if not exists ending jsonb not null default '{}'::jsonb;
