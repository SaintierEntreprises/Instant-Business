-- Jokers de série : une journée manquée absorbée sans repartir de zéro.
--
-- Rattachés à user_state comme le reste de l'état de série : la ligne existe déjà pour
-- chaque compte, et une table dédiée n'apporterait qu'une jointure de plus.
--
-- `freeze_granted` retient le quota accordé pour la période, sans quoi le complément
-- premium se rejouerait à chaque ouverture. `last_freeze_date` sert à réafficher le
-- flocon sur le bon jour après un changement d'appareil.

alter table public.user_state
  add column if not exists freezes_remaining integer not null default 0,
  add column if not exists freeze_period text,
  add column if not exists freeze_granted integer not null default 0,
  add column if not exists last_freeze_date date;

-- 0004_premium_grant.sql a retiré les droits d'écriture au niveau de la table pour les
-- redonner colonne par colonne. Toute colonne ajoutée depuis est donc en lecture seule
-- pour l'app tant qu'elle ne figure pas ici — l'upsert de série échouerait en silence.

grant insert (
    user_id, streak_count, last_open_date, first_name, last_name, gender,
    freezes_remaining, freeze_period, freeze_granted, last_freeze_date
  ) on public.user_state to authenticated;

grant update (
    user_id, streak_count, last_open_date, first_name, last_name, gender,
    freezes_remaining, freeze_period, freeze_granted, last_freeze_date
  ) on public.user_state to authenticated;
