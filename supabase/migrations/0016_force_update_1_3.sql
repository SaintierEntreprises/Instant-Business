-- Blocage des versions antérieures à la 1.3.
--
-- La 1.3 est publiée sur l'App Store depuis le 31 août 2026 à 15h48 UTC, vérifié auprès
-- de l'API de recherche Apple et non d'App Store Connect : « accepté » n'y signifie pas
-- « téléchargeable ».
--
-- Portée réelle du blocage : seules les personnes en 1.2 le verront. La 1.1 ne contient
-- pas `AppUpdateGate` — son binaire n'a aucun code pour lire cette table, et rien ne
-- pourra jamais l'y contraindre. Le verrou atteint donc exactement ceux qui avaient mis à
-- jour le plus vite, et laisse les autres tranquilles.
--
-- Pour lever le blocage : `update public.app_config set minimum_version = null;`

update public.app_config
  set minimum_version = '1.3',
      updated_at = now()
  where id = 1;
