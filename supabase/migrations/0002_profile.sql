-- Prénom et genre, saisis juste après la connexion pour personnaliser l'expérience
-- (accord des profils du quiz au féminin, salutation par prénom dans le fil).
-- Rattachés à user_state plutôt qu'à une table dédiée : la ligne existe déjà pour
-- chaque compte, et les règles d'accès y sont en place.

alter table public.user_state
  add column if not exists first_name text,
  add column if not exists gender text check (gender in ('homme', 'femme'));
