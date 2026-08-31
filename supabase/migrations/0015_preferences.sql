-- Préférences d'usage : conservées côté serveur, comme le profil et le quiz.
--
-- Elles ne vivaient que dans les réglages locaux. Une réinstallation ou un changement de
-- téléphone remettait donc le rythme des notifications, le thème et l'apparence des cartes
-- à leurs valeurs par défaut — sans prévenir, et sans que rien ne permette de deviner ce
-- qui avait été choisi. Quelqu'un qui recevait deux citations par jour se retrouvait
-- silencieusement à en recevoir trois.
--
-- `notifications_enabled` retient une intention, pas un droit : l'autorisation système est
-- propre à l'appareil et se revérifie au démarrage. Restaurer l'intention évite seulement
-- de redemander un choix déjà fait.
--
-- Rattachées à user_state comme le reste : la ligne existe déjà pour chaque compte.

alter table public.user_state
  add column if not exists notification_frequency text,
  add column if not exists notifications_enabled boolean,
  add column if not exists app_theme text,
  add column if not exists card_theme text;

-- 0004_premium_grant.sql a retiré les droits d'écriture au niveau de la table pour les
-- redonner colonne par colonne. Toute colonne ajoutée depuis est donc en lecture seule
-- pour l'app tant qu'elle ne figure pas ici — l'upsert échouerait en silence.

grant insert (
    user_id, streak_count, last_open_date, first_name, last_name, gender,
    freezes_remaining, freeze_period, freeze_granted, last_freeze_date,
    quiz_profile, preferred_categories,
    notification_frequency, notifications_enabled, app_theme, card_theme
  ) on public.user_state to authenticated;

grant update (
    user_id, streak_count, last_open_date, first_name, last_name, gender,
    freezes_remaining, freeze_period, freeze_granted, last_freeze_date,
    quiz_profile, preferred_categories,
    notification_frequency, notifications_enabled, app_theme, card_theme
  ) on public.user_state to authenticated;
