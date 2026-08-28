-- Sources de facturation (Stripe / Google Play / manuel).
-- Executer manuellement. Ne pas ecraser supabase/schema.sql.
-- user_entitlements reste le cache gameplay (demo|full) lu par Flutter et RLS.
-- FULL global = au moins une source encore valide. Ne jamais ecrire depuis le client.

create table if not exists entitlement_sources (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null
    check (provider in ('stripe', 'google_play', 'manual')),
  provider_ref text not null default 'legacy',
  status text not null default 'active'
    check (status in (
      'active',
      'pending',
      'canceled',
      'expired',
      'on_hold',
      'revoked'
    )),
  current_period_end timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, provider, provider_ref)
);

create index if not exists entitlement_sources_user_id_idx
  on entitlement_sources (user_id);

alter table entitlement_sources enable row level security;

revoke all on table entitlement_sources from anon, authenticated;
grant all on table entitlement_sources to service_role;

-- FULL en base reste valable tant que expires_at est null ou dans le futur.
create or replace function public.current_access_level()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select case
        when access_level = 'full'
         and (expires_at is null or expires_at > now())
        then 'full'
        else 'demo'
      end
      from user_entitlements
      where user_id = auth.uid()
    ),
    'demo'
  );
$$;

-- Comptes deja FULL (Stripe / admin) : une source perpetuelle pour ne pas
-- les ramener en DEMO au premier recalcul.
insert into entitlement_sources (user_id, provider, provider_ref, status)
select
  user_id,
  case
    when coalesce(metadata->>'provider', '') = 'google_play' then 'google_play'
    when coalesce(metadata->>'provider', '') = 'stripe' then 'stripe'
    when source in ('admin', 'promo') then 'manual'
    when source = 'purchase' then 'stripe'
    else 'manual'
  end,
  coalesce(
    nullif(metadata->>'stripe_session_id', ''),
    'legacy'
  ),
  'active'
from user_entitlements
where access_level = 'full'
on conflict (user_id, provider, provider_ref) do nothing;
