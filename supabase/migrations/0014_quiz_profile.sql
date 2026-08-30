-- Résultat du quiz : conservé côté serveur, comme le prénom et le genre.
--
-- Le profil était restauré à la réinstallation, le quiz non : il ne vivait que dans les
-- réglages locaux. Une désinstallation, un changement de téléphone ou une connexion
-- depuis un autre appareil suffisait donc à reposer les questions à quelqu'un qui y avait
-- déjà répondu — sans jamais redemander son prénom, ce qui rendait l'oubli d'autant plus
-- visible.
--
-- Rattachés à user_state comme le reste : la ligne existe déjà pour chaque compte.

alter table public.user_state
  add column if not exists quiz_profile text,
  add column if not exists preferred_categories text[];

-- 0004_premium_grant.sql a retiré les droits d'écriture au niveau de la table pour les
-- redonner colonne par colonne. Toute colonne ajoutée depuis est donc en lecture seule
-- pour l'app tant qu'elle ne figure pas ici — l'upsert du quiz échouerait en silence.

grant insert (
    user_id, streak_count, last_open_date, first_name, last_name, gender,
    freezes_remaining, freeze_period, freeze_granted, last_freeze_date,
    quiz_profile, preferred_categories
  ) on public.user_state to authenticated;

grant update (
    user_id, streak_count, last_open_date, first_name, last_name, gender,
    freezes_remaining, freeze_period, freeze_granted, last_freeze_date,
    quiz_profile, preferred_categories
  ) on public.user_state to authenticated;
