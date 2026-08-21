# Forcer la mise à jour vers 1.1

## ⚠️ Ordre à respecter absolument

Ne PAS exécuter la commande tant que la 1.1 n'est pas **réellement disponible**
sur l'App Store (statut "Prête pour la vente" / "Ready for Sale", pas juste
"Approuvée").

Si tu actives le blocage trop tôt, tout le monde qui est encore en 1.0 se
retrouve coincé sur l'écran "Mise à jour requise", avec un bouton qui renvoie
vers une version 1.1 qui n'existe pas encore publiquement. Personne ne peut
plus rien faire tant que tu n'as pas désactivé le blocage à la main.

## L'ordre correct

1. Soumettre la 1.1 à Apple
2. Attendre l'approbation
3. Cliquer sur "Release" pour la rendre publique
4. Vérifier que le statut de la 1.1 est bien "Prête pour la vente"
5. **Seulement à ce moment-là**, exécuter la commande ci-dessous

## La commande à exécuter

Où : supabase.com → projet Instant Business → **SQL Editor** (icône `>_` dans
la barre de gauche) → nouvel onglet → coller → bouton **Run**.

```sql
update public.app_config set minimum_version = '1.1';
```

Ça bloque immédiatement toute personne encore en version 1.0 : elle verra un
écran "Mise à jour requise" avec un bouton vers l'App Store, sans pouvoir
accéder au reste de l'app.

## Pour désactiver le blocage (si besoin)

```sql
update public.app_config set minimum_version = null;
```

## Pour la prochaine mise à jour (1.2, 1.3, etc.)

Même règle à chaque fois : ne jamais lever `minimum_version` avant que la
nouvelle version soit effectivement en ligne sur l'App Store. Remplacer juste
le numéro dans la commande.
