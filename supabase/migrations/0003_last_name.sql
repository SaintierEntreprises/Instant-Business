-- Nom de famille, demandé sur une troisième étape après le genre et le prénom.
-- Même emplacement que first_name/gender : la ligne user_state existe déjà pour
-- chaque compte et ses règles d'accès sont en place.

alter table public.user_state
  add column if not exists last_name text;
