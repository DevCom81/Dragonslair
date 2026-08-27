-- Observabilite couts IA. Executer manuellement. Ne pas ecraser supabase/schema.sql.
-- Ecriture service role uniquement. Aucune policy client : les joueurs ne lisent pas ces lignes.
-- Cout d'une partie :
--   select room_id, count(*), sum(input_tokens), sum(output_tokens), sum(cost)
--   from ai_usage_events group by room_id;

create table if not exists ai_usage_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  room_id uuid references rooms(id) on delete set null,
  model text not null default '',
  kind text not null default 'game_master'
    check (kind in ('game_master', 'scenario')),
  input_tokens integer,
  output_tokens integer,
  latency_ms integer,
  cost numeric,
  cost_source text not null default 'none'
    check (cost_source in ('none', 'openrouter', 'estimate')),
  created_at timestamptz not null default now()
);

create index if not exists ai_usage_events_room_id_created_at_idx
  on ai_usage_events (room_id, created_at);

create index if not exists ai_usage_events_user_id_created_at_idx
  on ai_usage_events (user_id, created_at);

alter table ai_usage_events enable row level security;

revoke all on table ai_usage_events from anon, authenticated;
grant all on table ai_usage_events to service_role;
