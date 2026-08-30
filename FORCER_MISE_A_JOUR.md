# Forcer une mise à jour

## Pourquoi ça n'a pas marché la dernière fois

`minimum_version` a bien été passée à `'1.1'` le 21 août 2026 à 12h04. La commande
SQL était correcte et la valeur est toujours en base. Rien ne s'est passé pour
**deux raisons cumulées**, aucune des deux n'étant une erreur de manipulation.

**1. `'1.1'` ne bloque personne quand tout le monde est déjà en 1.1.**
Le blocage vise les versions *antérieures* à la valeur posée. Mettre `1.1` alors
que la version publiée est `1.1` ne désigne personne. Pour bloquer les gens en
1.1, il faut poser `1.2`.

**2. La 1.1 publiée ne contient pas le mécanisme de blocage.**
C'est la raison de fond, et la plus importante à comprendre.

| Quand | Quoi |
|---|---|
| nuit du 20 au 21 août | la 1.1 (build 19) est approuvée et publiée |
| 21 août, 11h56 | commit `508a1cf` : **ajout de `AppUpdateGate`** |
| 21 août, 12h04 | `minimum_version` passée à `'1.1'` |

Le code qui lit `app_config` est arrivé **après** la publication. Les téléphones
en 1.1 n'ont donc aucune ligne de code qui interroge cette table : quelle que
soit la valeur qu'on y met, ils ne la liront jamais.

## La règle qui en découle

> **Un blocage ne peut jamais atteindre une version publiée avant lui.**

Concrètement, pour Instant Business :

- Les gens restés en **1.0 ou 1.1 ne seront jamais bloqués**. Ce mécanisme ne
  pourra rien pour eux — ils mettront à jour d'eux-mêmes, ou pas.
- La **1.2 est la première version qui embarque le blocage**. Une fois qu'elle
  sera en ligne et installée, elle pourra être bloquée par une valeur ultérieure.
- Donc `minimum_version = '1.3'` fonctionnera, le jour où la 1.3 sera publiée,
  pour pousser les gens en 1.2 à passer en 1.3.

## Faut-il poser `'1.2'` maintenant ?

**Non, et surtout pas avant que la 1.2 soit en ligne.**

Ça ne servirait à rien pour les utilisateurs publics (ils sont en 1.1, sans le
code de blocage), mais ça **te bloquerait toi**. Les builds TestFlight 20, 21 et
22 portent le numéro de version `1.1` **et contiennent le blocage**. Poser `1.2`
tout de suite verrouillerait ces installations sur un écran « Mise à jour
requise » pointant vers une 1.2 qui n'est pas publique.

La valeur actuelle `'1.1'` est inoffensive : elle ne désigne aucune version
installée. On peut la laisser, ou la remettre à `null` pour éviter toute
confusion future :

```sql
update public.app_config set minimum_version = null;
```

## L'ordre à respecter, à chaque fois

1. Soumettre la nouvelle version à Apple
2. Attendre l'approbation
3. Cliquer sur « Release » pour la rendre publique
4. Vérifier que le statut est bien **« Prête pour la vente »**, pas seulement
   « Approuvée »
5. Laisser passer quelques jours, pour que les mises à jour automatiques fassent
   leur travail — bloquer trop vite fait porter la brutalité du blocage à des
   gens qui allaient se mettre à jour tout seuls
6. **Seulement là**, poser la version qu'on veut rendre obligatoire

## La commande

Où : supabase.com → projet Instant Business (`lexbvkrvgsaprrgijsrf`) →
**SQL Editor** (icône `>_` à gauche) → nouvel onglet → coller → **Run**.

```sql
update public.app_config set minimum_version = '1.3';
```

Remplacer `1.3` par la version que l'on veut rendre obligatoire — jamais par
celle qu'on vient de soumettre, toujours par celle qui est **déjà en ligne**.

## Vérifier ce qui est réellement en base

Sans passer par le SQL Editor, en lisant exactement ce que l'app lit :

```bash
curl -s "https://lexbvkrvgsaprrgijsrf.supabase.co/rest/v1/app_config?select=minimum_version,updated_at" \
  -H "apikey: sb_publishable_g8_VCsQ6TkvjGIbKy3ylvQ_cqIt77tk"
```

## Désactiver le blocage

```sql
update public.app_config set minimum_version = null;
```

Effet immédiat au prochain passage au premier plan de chaque app.
