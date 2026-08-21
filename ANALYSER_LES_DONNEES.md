# Analyser les données d'usage

Toutes les requêtes se collent dans **supabase.com → projet Instant Business →
SQL Editor** (icône `>_` à gauche) → nouvel onglet → **Run**.

Les données sont dans la table `events`. Chaque ligne = une action de quelqu'un
dans l'app. Rien de nominatif n'y est stocké : ni prénom, ni nom, ni e-mail, ni
texte saisi.

---

## ⭐ Le tableau de bord — une seule requête, tous les chiffres clés

Celle-ci répond d'un coup à « combien de monde en ce moment, aujourd'hui, cette
semaine ». Garde cet onglet ouvert dans le SQL Editor : il suffit de recliquer
**Run** pour rafraîchir.

```sql
select
  count(distinct user_id) filter (where created_at > now() - interval '5 minutes')  as en_ce_moment,
  count(distinct user_id) filter (where created_at > now() - interval '1 hour')     as derniere_heure,
  count(distinct user_id) filter (where created_at::date = current_date)            as aujourdhui,
  count(distinct user_id) filter (where created_at > now() - interval '7 days')     as cette_semaine,
  count(distinct user_id) filter (where created_at > now() - interval '30 days')    as ce_mois,
  count(*) filter (where name = 'app_opened' and created_at::date = current_date)   as ouvertures_aujourdhui,
  count(*) filter (where name = 'app_opened' and created_at > now() - interval '7 days') as ouvertures_semaine
from public.events;
```

**« En ce moment »** = les personnes ayant fait quelque chose dans les 5 dernières
minutes. C'est le plus proche du direct qu'on puisse avoir sans complexité
inutile : l'app n'envoie un évènement que quand il se passe quelque chose, elle
ne signale pas sa présence en continu.

### Inscrits et abonnés

```sql
select
  (select count(*) from auth.users)                                       as comptes_crees,
  (select count(*) from auth.users where created_at > now() - interval '7 days')  as inscrits_cette_semaine,
  (select count(*) from public.user_state)                                as profils_actifs,
  (select count(*) from public.user_state where premium_granted)          as premium_offerts;
```

### Activité jour par jour, sur 14 jours

Le vrai indicateur de santé : est-ce que la courbe monte, stagne ou descend ?

```sql
select
  created_at::date as jour,
  count(distinct user_id) as personnes,
  count(*) filter (where name = 'app_opened') as ouvertures,
  count(*) filter (where name = 'quote_favorited') as favoris,
  count(*) filter (where name = 'quote_shared') as partages
from public.events
where created_at > now() - interval '14 days'
group by 1
order by 1 desc;
```

### À quelle heure les gens ouvrent-ils l'app ?

Directement utile : si personne n'ouvre à 4h du matin, cette notification-là ne
sert qu'à agacer.

```sql
select
  extract(hour from created_at)::int as heure,
  count(*) as ouvertures
from public.events
where name = 'app_opened'
  and created_at > now() - interval '30 days'
group by 1
order by 1;
```

---

## Vue d'ensemble : que se passe-t-il dans l'app ?

```sql
select name, count(*) as total, count(distinct user_id) as personnes
from public.events
where created_at > now() - interval '30 days'
group by name
order by total desc;
```

---

## Les notifications servent-elles vraiment ?

C'est **la** question à surveiller avec 6 notifications par jour : si le taux
d'ouverture est bas, tu fatigues les gens pour rien.

```sql
select
  count(*) filter (where name = 'notification_opened') as notifications_ouvertes,
  count(*) filter (where name = 'app_opened' and properties->>'source' = 'notification') as ouvertures_via_notif,
  count(*) filter (where name = 'app_opened') as ouvertures_totales,
  round(
    100.0 * count(*) filter (where name = 'app_opened' and properties->>'source' = 'notification')
    / nullif(count(*) filter (where name = 'app_opened'), 0), 1
  ) as pourcentage_via_notif
from public.events
where created_at > now() - interval '30 days';
```

### Les gens désactivent-ils les notifications ?

```sql
select date_trunc('day', created_at)::date as jour, name, count(*)
from public.events
where name in ('notifications_enabled', 'notifications_disabled')
  and created_at > now() - interval '30 days'
group by 1, 2
order by 1 desc;
```

---

## Le paywall convertit-il, et depuis où ?

`origin` vaut `category_filter` (barre de catégories du fil), `author_page`
(l'encart sur une page auteur), ou `settings`.

```sql
select
  properties->>'origin' as origine,
  count(*) filter (where name = 'paywall_shown') as vus,
  count(*) filter (where name = 'purchase_started') as achats_lances,
  count(*) filter (where name = 'purchase_completed') as achats_finis,
  round(
    100.0 * count(*) filter (where name = 'purchase_completed')
    / nullif(count(*) filter (where name = 'paywall_shown'), 0), 1
  ) as taux_conversion
from public.events
where name in ('paywall_shown', 'purchase_started', 'purchase_completed')
  and created_at > now() - interval '90 days'
group by 1
order by vus desc;
```

---

## Le partage fonctionne-t-il ? (ton levier de croissance)

```sql
select
  properties->>'origin' as depuis,
  count(*) as partages,
  count(distinct user_id) as personnes
from public.events
where name = 'quote_shared'
  and created_at > now() - interval '30 days'
group by 1
order by partages desc;
```

### Quelles citations sont les plus partagées ?

Utile pour savoir quoi mettre en avant, et quel style de citation ajouter.

```sql
select
  properties->>'author' as auteur,
  properties->>'category' as categorie,
  count(*) as partages
from public.events
where name = 'quote_shared'
group by 1, 2
order by partages desc
limit 20;
```

---

## Quelles citations et quels auteurs plaisent le plus ?

```sql
select
  properties->>'author' as auteur,
  count(*) filter (where name = 'quote_favorited') as ajouts,
  count(*) filter (where name = 'quote_unfavorited') as retraits
from public.events
where name in ('quote_favorited', 'quote_unfavorited')
group by 1
order by ajouts desc
limit 25;
```

### Et par catégorie ?

Si Mindset domine largement alors que c'est la seule catégorie gratuite, c'est un
signe que les autres ne sont pas assez visibles, pas qu'elles n'intéressent pas.

```sql
select properties->>'category' as categorie, count(*) as ajouts_favoris
from public.events
where name = 'quote_favorited'
group by 1
order by ajouts_favoris desc;
```

---

## Où les gens abandonnent-ils à l'inscription ?

```sql
select
  count(distinct user_id) filter (where name = 'onboarding_completed') as intro_finie,
  count(distinct user_id) filter (where name = 'profile_completed') as profil_fini,
  count(distinct user_id) filter (where name = 'quiz_completed') as quiz_fini
from public.events;
```

### Quels profils de quiz sortent le plus ?

```sql
select properties->>'profile' as profil, count(*) as personnes
from public.events
where name = 'quiz_completed'
group by 1
order by personnes desc;
```

---

## Les gens reviennent-ils ?

Nombre de personnes actives par jour sur les 30 derniers jours.

```sql
select date_trunc('day', created_at)::date as jour,
       count(distinct user_id) as personnes_actives
from public.events
where name = 'app_opened'
  and created_at > now() - interval '30 days'
group by 1
order by 1 desc;
```

### Répartition des séries en cours

```sql
select (properties->>'streak')::int as serie, count(distinct user_id) as personnes
from public.events
where name = 'app_opened'
  and created_at > now() - interval '7 days'
group by 1
order by 1 desc;
```

---

## Le verrou Premium bloque-t-il beaucoup de monde ?

Chaque `locked_category_tapped` est quelqu'un qui a voulu une catégorie payante.

```sql
select properties->>'category' as categorie,
       count(*) as tentatives,
       count(distinct user_id) as personnes
from public.events
where name = 'locked_category_tapped'
group by 1
order by tentatives desc;
```

---

## Tout ce qu'a fait une personne en particulier

Remplace l'identifiant. Tu le trouves dans le Table Editor, colonne `user_id` de
`user_state`.

```sql
select created_at, name, properties
from public.events
where user_id = 'COLLE-ICI-LE-USER-ID'
order by created_at desc
limit 100;
```

---

## Ménage (à faire de temps en temps)

Le plan gratuit Supabase a une limite de stockage. Si la table grossit beaucoup,
supprime les évènements anciens.

```sql
delete from public.events where created_at < now() - interval '12 months';
```
