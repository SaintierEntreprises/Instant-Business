-- Premium offert à la main, sans passer par un achat.
--
-- `premium_granted` à true suffit ; `premium_until` est facultatif : laissé nul, l'accès
-- est illimité ; renseigné, il expire tout seul à la date indiquée.

alter table public.user_state
  add column if not exists premium_granted boolean not null default false,
  add column if not exists premium_until timestamptz;

-- ⚠️ Sans ce qui suit, la fonctionnalité est une faille ouverte.
--
-- La politique « own state » de 0001_init.sql autorise `for all` sur sa propre ligne :
-- n'importe qui muni de son propre jeton (la clé publishable est dans l'app, c'est normal)
-- pourrait donc s'offrir Premium en une requête. On retire les droits d'écriture au niveau
-- de la table, puis on les redonne colonne par colonne, en laissant de côté les deux
-- nouvelles. La lecture reste entière : l'app doit pouvoir constater le cadeau.
--
-- Postgres ne permet pas de retirer une seule colonne d'un droit accordé sur la table
-- entière — d'où le revoke global suivi d'un grant explicite.

revoke insert, update on public.user_state from authenticated, anon;

grant insert (user_id, streak_count, last_open_date, first_name, last_name, gender)
  on public.user_state to authenticated;

-- `user_id` figure aussi dans le grant d'update : un upsert PostgREST génère un
-- `on conflict do update set` portant sur toutes les colonnes envoyées, clé comprise.
-- Aucun risque, la politique RLS impose déjà `auth.uid() = user_id`.
grant update (user_id, streak_count, last_open_date, first_name, last_name, gender)
  on public.user_state to authenticated;

-- `service_role` n'est pas concerné : il contourne RLS et garde tous ses droits, c'est
-- lui qui sert à accorder le cadeau depuis le SQL Editor ou l'API d'administration.
