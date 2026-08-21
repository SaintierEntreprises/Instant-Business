-- Jetons d'appareil pour les notifications push envoyées à la main.
--
-- Distinct des notifications existantes, qui sont programmées localement par chaque
-- téléphone (NotificationManager). Celles-ci partent du serveur vers Apple, ce qui
-- suppose de savoir à quel appareil s'adresser — d'où cette table.
--
-- Une personne peut avoir plusieurs appareils, d'où la clé primaire sur le jeton et
-- non sur l'utilisateur.

create table if not exists public.device_tokens (
  token text primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  -- « sandbox » pour un build lancé depuis Xcode ou TestFlight, « production » pour
  -- l'App Store. Apple utilise deux serveurs distincts et refuse un jeton présenté au
  -- mauvais : sans cette colonne, impossible de choisir le bon.
  environment text not null default 'production',
  app_version text,
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_user_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

-- Chacun n'écrit que ses propres jetons. La lecture reste fermée à l'app : seule la
-- fonction d'envoi, qui contourne RLS, a besoin de parcourir la table.
drop policy if exists "own device tokens" on public.device_tokens;
create policy "own device tokens" on public.device_tokens
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
