-- Journal d'évènements, pour comprendre ce que les gens font réellement dans l'app.
--
-- Chez Supabase plutôt qu'un SDK tiers : la base existe déjà, ça évite une dépendance
-- de plus, et surtout aucune donnée ne part chez un tiers — ce qui évite d'avoir à
-- déclarer un traceur externe dans la fiche de confidentialité App Store.

create table if not exists public.events (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id) on delete cascade,
  name text not null,
  -- Tout ce qui varie d'un évènement à l'autre : catégorie, écran d'origine, durée…
  -- En JSON pour ne pas avoir à migrer la table à chaque nouvelle mesure.
  properties jsonb not null default '{}'::jsonb,
  app_version text,
  is_premium boolean,
  created_at timestamptz not null default now()
);

-- Les deux lectures qu'on fait vraiment : « tel évènement sur telle période » et
-- « tout ce qu'a fait telle personne ».
create index if not exists events_name_created_at_idx on public.events (name, created_at desc);
create index if not exists events_user_idx on public.events (user_id, created_at desc);

alter table public.events enable row level security;

-- Écriture seule, et uniquement sur sa propre ligne. Personne ne peut relire le journal
-- depuis l'app : ces données sont pour toi, pas pour l'utilisateur, et une lecture
-- ouverte exposerait le comportement de tous les autres.
drop policy if exists "insert own events" on public.events;
create policy "insert own events" on public.events
  for insert
  with check (auth.uid() = user_id);

revoke update, delete on public.events from authenticated, anon;
