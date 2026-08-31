-- Réglages de notification pilotables sans republier l'app.
--
-- Motif : la logique de programmation est calendaire, ne se reproduit à la main qu'en
-- changeant l'heure du téléphone, et ses défauts ne se voient que chez les utilisateurs.
-- Un correctif y demande un build, une revue Apple et une adoption qui prend des jours.
-- Ces trois boutons permettent d'éteindre le symptôme en attendant.
--
-- Portée volontairement étroite. Un réglage à distance ne tourne que des boutons que le
-- code sait déjà tourner : ceci ne rend pas « tout bug réparable en SQL », ça équipe
-- l'endroit dont on sait qu'il est fragile.
--
-- `null` partout = aucune opinion, l'app garde son comportement compilé. C'est l'état
-- normal, et c'est ce qui rend le mécanisme sûr : une table vide ou injoignable ne change
-- rien.

alter table public.app_config
  -- Coupe toute programmation locale. Dernier recours : les gens ne reçoivent plus rien
  -- plutôt que de recevoir n'importe quoi.
  add column if not exists notifications_enabled boolean,
  -- 'first' : la citation du jour va au premier créneau. 'off' : aucun créneau ne la
  -- porte, tout devient rotation. C'est ce réglage qui aurait éteint le doublon du
  -- 31 août sans attendre la 1.4.
  add column if not exists daily_quote_mode text,
  -- Horaires par rythme, ex. {"duo": [8, 19]}. Un rythme absent garde les siens.
  add column if not exists notification_hours jsonb;

-- Lecture déjà ouverte à tous par 0005 : la policy porte sur la table, les colonnes
-- ajoutées en héritent. Écriture toujours réservée à service_role.
