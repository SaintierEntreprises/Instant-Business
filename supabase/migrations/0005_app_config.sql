-- Version minimale exigée, pilotable sans republier l'app.
--
-- Une seule ligne, identifiée par `id = 1`. Laisser `minimum_version` à NULL revient à
-- ne rien bloquer : c'est l'état par défaut, et c'est volontaire — le mécanisme est mis
-- en place maintenant pour être disponible le jour où il servira, pas pour servir tout
-- de suite.

create table if not exists public.app_config (
  id integer primary key default 1,
  minimum_version text,
  updated_at timestamptz not null default now(),
  constraint app_config_single_row check (id = 1)
);

insert into public.app_config (id, minimum_version)
  values (1, null)
  on conflict (id) do nothing;

alter table public.app_config enable row level security;

-- Lecture ouverte à tous, y compris avant connexion : le blocage doit pouvoir s'appliquer
-- à quelqu'un qui n'a pas encore de compte.
drop policy if exists "read app config" on public.app_config;
create policy "read app config" on public.app_config
  for select
  using (true);

-- Personne ne l'écrit depuis l'app. Seul le dashboard (service_role) peut la modifier.
revoke insert, update, delete on public.app_config from authenticated, anon;
