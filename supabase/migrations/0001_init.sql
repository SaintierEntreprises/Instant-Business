-- Instant Business — schéma initial (favoris + streak par utilisateur)
-- À exécuter dans le SQL Editor du projet Supabase dédié (Instant Business, pas BetterBets).

create table if not exists public.favorites (
  user_id uuid references auth.users(id) on delete cascade not null,
  quote_id text not null,
  created_at timestamptz default now() not null,
  primary key (user_id, quote_id)
);

alter table public.favorites enable row level security;

create policy "own favorites" on public.favorites
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create table if not exists public.user_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  streak_count integer not null default 0,
  last_open_date date,
  updated_at timestamptz default now() not null
);

alter table public.user_state enable row level security;

create policy "own state" on public.user_state
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
