# Instant Business — état du projet

Document de passation, réécrit le 30 août 2026. Lis ce fichier en entier avant toute action — il remplace l'historique de conversation d'une session précédente qui a rempli son quota.

## Ce qu'est l'app

App iOS native (Swift/SwiftUI + WidgetKit), en français, façon Punchlines/Instant Bible mais pour l'entrepreneuriat : citations business affichées sur écran d'accueil/verrouillage, **573 citations, 258 auteurs**, en 4 catégories (Mindset, Vente, Leadership, Finance), compte obligatoire (Sign in with Apple/Google) pour synchroniser favoris et série, abonnement Premium via StoreKit, notifications locales programmables, et un tableau de bord analytique maison (hors app, page web privée).

**Statut : publiée sur l'App Store.** ⚠️ **Seule la 1.1 est en ligne.** Version prête à soumettre : **1.2 (28)** — les builds 26 et 27 ont déjà été téléversés chez Apple, tout nouveau build doit donc partir de 28. La 1.2 a été préparée mais jamais soumise — une session antérieure a cru à tort qu'elle était publiée et avait fait monter la version à 1.3 sans raison. Corrigé : `project.yml` porte `MARKETING_VERSION 1.2`, `CURRENT_PROJECT_VERSION 25` (le build reste supérieur au 22 déjà téléversé, donc jamais en conflit). **Vérifier l'état réel sur App Store Connect avant de toucher au numéro de version.**

## ⚠️ Priorité n°1 pour la prochaine session : 4 commits locaux non poussés

```
git log origin/main..HEAD --oneline
```

```
6fb8b3b Resserre les descriptions de profil et remonte l'insigne
8f0148c Retire le nom de profil de l'écran de résultat
d71dce7 Réduit le parcours d'inscription de dix écrans à sept
506f9e5 Laisse choisir le rythme des notifications, et ne réveille plus la nuit
```

S'y ajoute, **non commité**, tout le chantier du suivi de série décrit plus bas.

`git push` reste bloqué par le classificateur de sécurité automatique de l'outil — c'est normal, il faut que l'utilisateur le lance lui-même dans son terminal, ou confirme explicitement avant une nouvelle tentative.

Fichiers non suivis, laissés tels quels sans demande explicite : dossier `IB designs/` (exports marketing), `Logo-InstantBusiness-5000.png` (logo haute résolution).

## ✅ Fait le 30 août 2026, non commité : suivi de série (sheet + réglages)

Tout est dans l'arbre de travail, **rien n'est commité** — aucune demande explicite en ce sens.

**Nouveaux fichiers**
- `InstantBusiness/Models/StreakWeek.swift` — `StreakDay` (état d'un jour, déjà résolu pour la vue), `StreakWeek.days(streak:openDays:reference:)` (semaine lundi→dimanche, calendrier forcé à `firstWeekday = 2`), `StreakMilestone` (paliers 3/7/14/30/60/100/180/365 + progression vers le suivant).
- `InstantBusiness/Views/Components/StreakWeekTracker.swift` — `StreakPalette` (dégradé flamme partagé), `StreakWeekTracker` (tailles `.compact` / `.prominent`), `StreakMilestoneBar`.
- `InstantBusiness/Views/Components/StreakCelebrationSheet.swift` — la bottom sheet de célébration.

**Stockage** — `SharedDefaults` gagne `openDays` (ensemble de jours `yyyy-MM-dd`, tronqué à 400), `bestStreak` (+ `bestStreakKey` pour `@AppStorage`) et `lastStreakSheetDate`. Les trois sont effacés par `resetAccountData()`. `StreakManager.recordVisit(streak:on:calendar:)` inscrit le jour courant **et** reconstitue à rebours les `streak - 1` jours précédents : sans ça, un changement de téléphone afficherait une semaine vide sous un compteur à 40. Appelé depuis `InstantBusinessApp.syncOnForeground()`, après la résolution de la série.

**Pourquoi un historique et pas seulement le compteur** — le compteur dit combien de jours consécutifs tiennent, pas quels jours ont été ouverts. Un jour ouvert avant une coupure apparaît donc coché en gris (fait, hors série) plutôt que vide.

**Déclenchement de la sheet** (`ContentView.presentStreakCelebrationIfNeeded`) :
- systématiquement à l'ouverture depuis le rappel de série (`forced`), grâce à `NotificationPayload.kindKey` / `.streakKind` posé sur la notification et lu par `AppDelegate` → `AppRouter.pendingStreakCelebration` ;
- sinon une fois par jour, à la première ouverture, et jamais avant d'avoir ouvert l'app deux jours distincts (`openDays.count >= 2`) — quelqu'un qui sort des sept écrans d'inscription n'a pas de progression à consulter.
- `AppRouter.streakRefreshTick`, incrémenté en fin de `syncOnForeground()`, est le signal qui dit « la série et l'historique sont posés, tu peux décider » : à l'apparition de la vue, la synchronisation serveur n'est pas encore revenue.

**Design** — la série est soulignée par un **bandeau continu** sous les jours consécutifs, pas par de fins traits entre les ronds : sept ronds sur la largeur d'un iPhone ne laissent que ~4 pt entre chacun, testé et illisible. Vérifié en clair et en sombre au simulateur.

**Haptics** — `Haptics.prepare()` puis un `tap()` par jour allumé à la cadence des ronds, `success()` à la fin, `commit()` sur le bouton, `tap()` sur la carte des réglages. Coupé si « Réduire les animations » est actif.

**Réglages** — le bloc « X jours de suite » est remplacé par une carte cliquable (`SettingsView.streakCard`) qui reprend flamme + compteur + record + le même tracker (`.compact`) + la barre de palier, et rouvre la sheet.

**Point 4 de la demande, vérifié de bout en bout** : `NotificationManager.scheduleStreakReminder` programme un rappel à 18h le lendemain du dernier `lastForegroundDate`, uniquement si `streakCount > 0`. `reschedule()` efface tout et reprogramme à chaque passage au premier plan, donc ouvrir l'app supprime mécaniquement le rappel du jour. Testé au simulateur (`xcrun simctl push` avec `"kind": "streak"`) : l'appui sur la notification ouvre bien l'app directement sur la sheet.

**Rappel de reconquête au 2e jour, ajouté à la demande** : `scheduleStreakReminder` programme désormais **deux** notifications à 18h, via un `scheduleStreakNotification` factorisé — jour+1 « Ne perds pas ta série de X jours » (la série tient encore), jour+2 « Ta série de X jours s'est arrêtée » / « rien n'est perdu, une citation aujourd'hui et une nouvelle série démarre ». Les deux portent `kind = streak`, donc l'appui ouvre la sheet dans les deux cas. Sans le second, quelqu'un qui sautait deux jours ne recevait plus jamais un mot au sujet de sa série : la date de tir du premier était passée, et `reschedule()` ne tourne qu'au premier plan. Le plafond iOS de 64 notifications reste tenu (55 max + 2).

**Autre correctif au passage** : `NSUserNotificationsUsageDescription` dans `InstantBusiness/Info.plist` annonçait encore « une citation aléatoire toutes les 6 heures », rythme qui n'existe plus depuis `NotificationFrequency`. Reformulé en « au rythme que tu choisis ».

**Analytics** : nouvel évènement `streak_sheet_shown` (`streak`, `forced`), et `notification_opened` porte désormais une propriété `kind`.

## ✅ Fait le 30 août 2026, non commité : mode nuit

Nouveau `Shared/Models/AppTheme.swift` (`system` / `light` / `dark`), stocké dans `SharedDefaults.appTheme` (défaut `.system`), exposé par `AppearanceStore.appTheme`, appliqué une seule fois par `.preferredColorScheme` à la racine de `ContentView` — les feuilles présentées plus bas en héritent.

Réglé dans **Réglages → Apparence**, au-dessus de « Thème des cartes » : un `Picker` (insigne lune indigo) avec un pied de section qui dit ce que fait le réglage choisi. `Haptics.select()` au changement, évènement `app_theme_changed`.

Deux points volontaires :
- `AppTheme` est distinct de `CardTheme` — celui-ci n'habille que le fond des cartes de citation, on peut vouloir des cartes crème sur une app en sombre.
- L'apparence n'est **pas** effacée par `resetAccountData()` : c'est un réglage de confort propre à l'appareil, pas une préférence de compte. Se déconnecter ne doit pas rallumer un écran blanc en pleine nuit.

Vérifié au simulateur : bascule immédiate de toute l'app, conservée après relance, indépendante du réglage clair/sombre d'iOS.

## ✅ Fait le 30 août 2026, non commité : gamification de la série

Cinq chantiers demandés (le widget et l'objectif hebdomadaire ont été écartés explicitement).

### Migration 0008 : appliquée en production le 30 août 2026 ✅

`supabase/migrations/0008_streak_freeze.sql` ajoute `freezes_remaining`, `freeze_period`, `freeze_granted`, `last_freeze_date` à `user_state`, **et les rejoute aux `grant insert/update` colonne par colonne** — 0004_premium_grant.sql avait retiré les droits d'écriture au niveau de la table, donc toute colonne ajoutée depuis reste en lecture seule tant qu'elle n'est pas explicitement accordée. Sans ça, l'upsert de série aurait échoué en silence (le `try?` de `reconcileStreak` avale l'erreur) et la série aurait cessé d'être sauvegardée pour tout le monde.

**L'historique de migration a été réparé au passage.** L'affirmation d'une session précédente — « 0001 à 0007 appliquées, confirmé via `supabase migration list --linked` » — était fausse : la colonne « Remote » était vide pour toutes. Ces migrations avaient bien été exécutées (les cinq tables existent, vérifié par `supabase inspect db table-stats`), mais collées à la main dans le SQL Editor, sans passer par la CLI, donc jamais inscrites dans `supabase_migrations.schema_migrations`. Un `db push` naïf aurait rejoué 0001 à 0007 et planté sur le premier `create policy`, qui n'est pas idempotent.

Procédure suivie, à reprendre telle quelle pour les prochaines :
1. `supabase migration repair --status applied 0001 … 0007` — inscrit l'historique sans rien réexécuter.
2. `supabase db push` — n'applique alors que 0008.
3. Vérifié par `supabase gen types typescript --linked` : les quatre colonnes sont bien là.

**Désormais `supabase db push` est le chemin normal** pour ce projet, l'historique local et distant étant enfin alignés (0001 → 0008 des deux côtés).

### 1. Jokers de série (`StreakFreeze`)

Un jour manqué absorbé sans repartir de zéro. **1 par mois, 3 pour les abonnés** (annoncé dans le paywall). Non cumulable d'un mois sur l'autre — un joker qui s'accumule rend la série impossible à perdre, et une série qu'on ne peut pas perdre ne veut plus rien dire.

- Couvre **exactement une** journée manquée (`daysSince == 2`). Au-delà, la série repart à 1.
- `freezeGranted` retient le quota déjà accordé pour la période : sans lui, le complément premium se rejouait à chaque passage au premier plan et rechargeait les jokers indéfiniment.
- Les jours gelés vivent dans `SharedDefaults.frozenDays`, **séparés de `openDays`** : le remplissage rétroactif de `recordVisit` les saute, sinon il prétendrait que la personne était là.
- Affichés en flocon bleu dans la semaine et le calendrier — jamais en coche : un joker ne doit pas se confondre avec une journée faite.
- Annoncés explicitement dans la sheet le lendemain (« Un joker a sauvé ta série — Samedi n'a pas compté »), sinon la série continuerait après un oubli sans que personne comprenne pourquoi.

**Règle de série unifiée** : `StreakManager.resolve(daysSince:previousStreak:today:isPremium:)` est désormais le seul endroit qui décide. Elle était écrite deux fois (hors ligne dans `StreakManager`, en ligne dans `UserSyncService.reconcileStreak`) ; avec les jokers, une divergence entre les deux deviendrait un bug invisible jusqu'en production.

**Limite assumée** : le client reste autoritaire sur `streak_count` et sur le compteur de jokers, comme il l'était déjà avant. Quelqu'un qui bidouille son téléphone peut s'offrir des jokers — il n'y a ni classement ni récompense monétaire, donc il ne trompe que lui-même. Le rendre inviolable demanderait de déplacer toute la réconciliation dans une fonction Postgres `security definer`.

### 2. Insignes de palier (`StreakBadge`)

Huit paliers (3/7/14/30/60/100/180/365), chacun avec un nom, un symbole et un dégradé. Gagnés dès que `bestStreak` franchit le seuil, donc **définitivement acquis** : c'est la seule trace qui survit à une série perdue.

### 3. Célébration de palier + carte partageable

`StreakCelebrationSheet` a maintenant deux régimes dans un seul écran : le jour ordinaire, et le jour où un palier tombe (emblème et titre repris de l'insigne, haptique plus longue, bouton « Partager ce palier »). Le record est masqué en mode palier — l'insigne est le message, et le laisser repoussait les boutons hors de l'écran.

`StreakShareCard` + `StreakShareRenderer` produisent une image 1200×1599 (même échelle que les citations partagées) : fond sombre, emblème, compteur, nom du palier, semaine figée, signature « Instant Business ». Le tracker animé de l'app n'y est pas réutilisable — il dépend d'un `GeometryReader` et d'un état d'apparition qu'`ImageRenderer` ne fait pas tourner, d'où la version figée dans la carte.

**Refêtage** : `SharedDefaults.celebratedMilestone` est remis à 0 par `StreakManager` à chaque rupture de série. Sans ça, quelqu'un qui perd une série de 30 jours ne reverrait plus de célébration avant le 60e — soit au moment précis où il en aurait le plus besoin. Un palier atteint passe aussi devant la règle du « une fois par jour ».

### 4. Notification J-1 de palier

Quand le lendemain fait justement franchir un palier, le rappel de 18h change de discours : « À un jour du palier de 7 jours / ouvre l'app aujourd'hui et le palier « Une semaine » est à toi » au lieu de la mise en garde habituelle. Le rappel du 2e jour mentionne le joker restant, s'il y en a un.

### 5. Écran « Ma progression » (`StreakDetailView`)

Poussé depuis la carte des réglages (`navigationDestination`, pas un `NavigationLink` — ce dernier ajoutait son propre chevron à côté de celui de la carte). Contient trois tuiles (série, record, jours au total), le **calendrier du mois** avec navigation bornée par le premier jour enregistré, la **grille des huit insignes**, et l'état des jokers.

La sheet reste un moment, cet écran est un dossier : tout mettre dans la sheet l'aurait allongée jusqu'à ce qu'on cesse de la lire.

**Analytics** : `streak_milestone_reached`, `streak_shared`, `streak_freeze_used`, et `streak_sheet_shown` porte désormais `milestone`.

Vérifié au simulateur : mode palier avec joker, carte partagée rendue et relue en PNG, calendrier du mois, grille d'insignes.

## ✅ Fait le 30 août 2026, non commité : contenu serveur, fiche de citation, recherche, mémoire, tests

Trois des cinq améliorations proposées ont été retenues (l'ouverture sans compte et le rééquilibrage du palier gratuit ont été écartés pour l'instant).

### Contenu servi depuis Supabase (migration 0009, appliquée en prod)

`public.quotes` — 573 lignes amorcées depuis `Shared/Content/content.json`, colonnes `context` / `source` / `year` nulles au départ. Lecture pour tout compte connecté, **écriture pour personne** : le contenu se modifie depuis le SQL Editor ou avec `service_role`. Corriger une attribution ne demande donc plus de soumission App Store.

`ContentSyncService.refreshIfNeeded()` est appelé dans `syncOnForeground()` **avant** `reschedule()` — les notifications embarquent le texte de la citation au moment où elles sont programmées, rafraîchir après reviendrait à annoncer pendant deux semaines une citation qu'on vient de corriger. Vérification au plus toutes les 6 h, et la date n'est écrite qu'après une application réussie.

`ContentStore` a changé de nature : `allQuotes` est passé de `let` à `private(set) var`, avec `apply(remoteQuotes:)` et un `rebuildIndexes()` qui reconstruit auteurs, index par auteur et clés de recherche. Deux garde-fous :
- **Plancher de confiance** (`minimumTrustedCount = 50`) : une réponse tronquée ou une table vidée par erreur ne peut pas remplacer 573 citations par trois. En dessous, rien n'est touché.
- **Cache dans le conteneur du groupe d'app**, pas dans les Documents : le widget et les notifications doivent lire exactement le même contenu, sinon la citation affichée sur l'écran d'accueil n'existerait plus dans l'app. `WidgetCenter.reloadAllTimelines()` après chaque application.

Une catégorie inconnue fait ignorer la ligne, pas tout le rafraîchissement — c'est ce qui permettra d'ajouter une catégorie sans casser les versions déjà installées.

### Fiche de citation, à l'appui sur une carte (`QuoteDetailView`)

`Quote` gagne `context`, `source`, `year`, tous optionnels, plus `hasContext` et `provenance`. **Ils sont vides partout aujourd'hui** : c'est un travail éditorial de vérification, citation par citation, qui ne se génère pas — inventer une source serait pire que ne rien afficher. À remplir dans la table `quotes` quand tu voudras.

La fiche s'ouvre en appuyant sur une carte, depuis le fil, la carte du jour, les favoris, la page auteur et la recherche. Sans contexte, elle montre la citation, la catégorie, l'auteur et un lien vers ses autres citations — pas d'espace vide qui s'excuse. Avec contexte, elle s'ouvre directement en grand (`detent` décidé dans `init`, pas dans `onAppear`, sinon la feuille s'ouvre petite puis grandit toute seule).

Deux pièges rencontrés et corrigés, à connaître pour les prochaines feuilles :
- **Sans `presentationBackground` explicite, la feuille laisse transparaître ce qu'il y a derrière** — vérifié au simulateur : fond vert sous un texte de lecture, selon la couleur de la carte restée dans le carrousel.
- L'appui sur la carte est un `onTapGesture` posé au-dessus des boutons imbriqués (cœur, partage, auteur), qui captent le geste en premier : appuyer sur le cœur n'ouvre pas la fiche par-dessus.

### Recherche plein texte (`AuthorSearchView`, renommée « Rechercher »)

Deux sections dans une même liste, auteurs d'abord. `ContentStore.quotes(matching:)` s'appuie sur un index de clés précalculé couvrant texte **et** auteur (« buffett argent » fonctionne), plafonné à 60 résultats. Replier 573 textes à chaque frappe rendait la saisie saccadée — même problème et même réponse que pour l'index des auteurs. L'évènement `quote_searched` ne transporte que le nombre de résultats, jamais la saisie.

### Mémoire des citations vues

`SharedDefaults.seenQuoteIDs`, liste ordonnée plafonnée à 600. Une carte n'est comptée que lorsqu'elle s'arrête au centre du carrousel, pas quand elle entre dans le champ : le carrousel en rend deux voisines partiellement visibles, les compter brûlerait le stock trois fois plus vite que ce qui est lu. `ContentStore.feedOrder(for:seen:)` place les non vues devant, **sans retirer les autres** — un fil qui se vide serait pire qu'un fil qui se répète.

Volontairement limité au fil : la rotation du widget et des notifications reste déterministe et partagée entre les deux, la rendre consciente des vues les désynchroniserait.

### Tests (nouvelle cible `InstantBusinessTests`)

**26 tests, tous verts** (`xcodebuild test`). Cible ajoutée dans `project.yml` et rattachée au schéma.

- `StreakLogicTests` (17) : règle de série, jokers, paliers, semaine affichée, remplissage rétroactif. Couvre notamment le cas le plus coûteux qu'on puisse écrire — un complément premium rejoué à chaque appel rechargerait les jokers indéfiniment et rendrait la série impossible à perdre.
- `ContentStoreTests` (9) : plancher de confiance, recherche accents/casse, ordre du fil, stabilité de la citation du jour.

C'est la seule partie de l'app dont un bug est invisible : elle dépend du calendrier, donc une erreur ne se manifeste ni au clic ni à la compilation, mais trois semaines plus tard chez quelqu'un qui perd une série qu'il avait tenue.

### Améliorations proposées et **non retenues pour l'instant**

1. **Rendre le compte facultatif.** `ContentView` bloque tout derrière `authManager.session == nil` : sept écrans et un compte Apple/Google avant d'avoir vu une seule citation. C'est probablement le plus gros frein à l'activation — tout fonctionne déjà en local, le serveur n'est qu'un miroir.
2. **Rééquilibrer le palier gratuit.** Répartition réelle : Mindset 307, Leadership 108, Finance 82, Vente 76. Seule Mindset est gratuite : un utilisateur non abonné voit 54 % du contenu, mais **exclusivement la catégorie la plus banale**, et jamais l'angle business qui différencie l'app. Piste la plus simple : que la citation du jour puise dans les quatre catégories quel que soit l'abonnement.

### Contexte chiffré relevé le 30 août 2026

`supabase inspect db table-stats` : **~16 comptes, 12 favoris, 1 jeton d'appareil, 170 évènements** (estimations `reltuples`). L'app est publiée mais quasiment pas utilisée — toute amélioration de rétention vaut moins qu'un canal d'acquisition tant que ce chiffre ne bouge pas.

## ✅ Fait le 30 août 2026, non commité : fluidité et UX

Passe menée après un parcours écran par écran au simulateur. Six correctifs, tous constatés sur l'app réelle plutôt que supposés.

### Fluidité — deux vrais coûts, dont un que j'avais introduit

**1. Mémoïsation dans `ContentStore`.** Chaque citation demandée refiltrait les 573 entrées puis mélangeait autant d'indices (Fisher-Yates complet). Deux endroits où ça coûtait cher :
- `NotificationManager.reschedule()` programme jusqu'à ~45 notifications d'affilée, donc ~45 filtres + ~45 mélanges de 573 éléments **à chaque passage au premier plan**.
- `CardFeedView.dailyQuote` était un stockage de propriété : SwiftUI recrée la structure de vue à chaque rendu du parent, donc un mélange de 573 indices par rendu.

Trois caches ajoutés (pools filtrés, ordres mélangés, citation du jour), protégés par un `NSLock` — le widget lit depuis son propre processus et son propre fil, et deux écritures concurrentes dans un dictionnaire Swift font tomber le processus, elles ne donnent pas seulement un résultat faux. Vidés par `rebuildIndexes()` quand le contenu distant change. `ContentStore.quote(id:)` passe aussi d'un balayage linéaire à un dictionnaire.

Le tout est déterministe, donc le cache ne change aucun comportement — quatre tests le vérifient explicitement (rotation stable pour une même graine, rotation qui avance avec le créneau, graines différentes, contrainte de longueur).

**2. `SeenQuotes`, tampon d'écriture.** La mémoire des citations vues, écrite plus tôt dans la journée, faisait à **chaque carte arrêtée au centre du carrousel** : relecture d'un tableau de 600 identifiants, recherche linéaire, réécriture dans les préférences partagées — pendant le geste de défilement, sur le fil principal. Les identifiants s'accumulent désormais en mémoire et ne descendent sur disque qu'après 2 s de calme, ou à la mise en arrière-plan (`scenePhase`). `SeenQuotes.all()` réunit disque et tampon, pour qu'un mélange déclenché juste après un défilement ne remonte pas les cartes qu'on vient de faire passer. `SharedDefaults.markQuoteSeen` est supprimée, elle n'a plus d'appelant.

### UX — quatre correctifs

**3. Réglages, ligne « Thème des cartes ».** Elle s'affichait en orange à côté de voisines noires, comme si elle était active. Cause : un bouton de formulaire teinte toute son étiquette avec la couleur d'accent, et `.primary` / `.secondary` / `.tertiary` sont des styles *hiérarchiques* — ils se résolvent contre la teinte ambiante, pas contre le noir. `.buttonStyle(.plain)` règle le cas. **Bug préexistant, sans rapport avec les changements de cette session.**

**4. Sheet de palier.** La barre de progression y repartait du palier qu'on venait d'atteindre et affichait donc une barre **vide**, au moment précis où l'écran est censé célébrer quelque chose. Masquée en mode palier. Effet secondaire bienvenu : la feuille tient maintenant sans défilement, boutons compris. La cible du bouton secondaire « Continuer » passe de 12 à 16 pt de marge verticale — c'est le dernier élément de la feuille, donc celui qu'on vise le plus mal, et un texte nu n'offre aucune cible visible.

**5. Galerie de widgets.** Trois cadenas s'affichaient avant le seul thème utilisable sans abonnement (Dégradé, troisième de `allCases`). La galerie trie maintenant les gratuits d'abord. L'ordre du modèle n'est pas touché — il sert aussi à l'intention de configuration du widget.

**6. Fil : tirer pour renouveler.** Le fil ne se renouvelait qu'en changeant de catégorie puis en revenant. `.refreshable` fait maintenant explicitement ce que ce détour faisait par accident, avec un délai de 400 ms pour que l'indicateur soit vu — sans lui, le mélange est instantané et le geste semble n'avoir rien déclenché.

**30 tests, tous verts.**

## ✅ Fait le 30 août 2026 : demande de note + diagnostic du blocage de version

### Pourquoi le forçage de mise à jour n'avait rien fait

Diagnostic complet dans `FORCER_MISE_A_JOUR.md`, réécrit. En résumé : la commande SQL était bonne et `minimum_version = '1.1'` est bien en base depuis le 21 août 12h04. Deux raisons cumulées expliquent l'absence d'effet.

1. `'1.1'` ne vise que les versions **antérieures** à 1.1 — donc personne, puisque tout le monde est en 1.1.
2. Surtout : **la 1.1 publiée ne contient pas `AppUpdateGate`**. La 1.1 (build 19) a été approuvée dans la nuit du 20 au 21 août ; le commit `508a1cf` qui ajoute le mécanisme date du 21 août à 11h56. Les téléphones en 1.1 n'ont donc aucun code qui lise `app_config`.

**Règle générale à retenir : un blocage ne peut jamais atteindre une version publiée avant lui.** Les gens restés en 1.0/1.1 ne seront jamais bloqués par ce mécanisme. La 1.2 est la première version qui l'embarque.

**Ne pas poser `'1.2'` avant que la 1.2 soit publique** : ça ne toucherait aucun utilisateur public, mais les builds TestFlight 20/21/22 portent le numéro `1.1` **et contiennent le blocage** — ils se retrouveraient verrouillés sur un écran pointant vers une version inexistante.

### Demande de note (`ReviewPrompter`)

Feuille native `AppStore.requestReview` : les cinq étoiles s'affichent **dans l'app**, la note part de là, personne n'est renvoyé vers l'App Store. C'est ce que demandait l'utilisateur, et c'est la seule forme qu'Apple autorise à déclencher soi-même.

Deux limites d'Apple qui conditionnent la conception :
- **On ne peut pas savoir si quelqu'un a déjà noté.** Le système ne le dit pas. Impossible donc de cibler « ceux qui n'ont pas noté » ; on sollicite qui remplit les conditions et iOS ignore silencieusement si c'est de trop.
- **Trois affichages par an maximum**, comptés par iOS. Une demande au mauvais moment est perdue pour l'année.

D'où les garde-fous : au moins **5 jours d'usage distincts**, **120 jours entre deux demandes**, **3 demandes maximum**. La règle est une fonction pure (`shouldRequest`) couverte par 8 tests.

**Déclencheur** : la fermeture de la célébration de série, et uniquement quand un **palier** vient d'être franchi — le seul moment de l'app où l'on vient de donner quelque chose plutôt que d'en attendre. Un délai de 700 ms laisse la feuille se refermer, sans quoi les deux présentations se croisent et la demande ne s'affiche pas.

**Ligne « Noter Instant Business »** ajoutée dans les réglages, ouvrant l'App Store directement sur le formulaire d'avis (`?action=write-review`). Indispensable en complément : la feuille native peut refuser de s'afficher sans prévenir, et quelqu'un qui veut noter doit toujours pouvoir le faire.

Évènements : `review_prompt_shown`, `review_link_opened`.

## ✅ Fait le 30 août 2026 : fiches de citation complètes

### Ce que porte chaque citation

Les 555 citations ont désormais un **principe** (le mécanisme que la formule nomme) et une **application** (une action concrète, avec un critère de décision). Longueurs calibrées sur le sujet : 21 à 45 mots pour le principe, 17 à 42 pour l'application.

La fiche affiche trois blocs dans cet ordre : **LE PRINCIPE**, **COMMENT L'APPLIQUER**, **CONTEXTE**. La provenance passe en dernier parce que c'est elle qui manque le plus souvent.

### Pourquoi 100 % d'analyse mais seulement 13 % de provenance

C'est la distinction qui structure tout ce travail. `context` est une **affirmation sur le passé** : elle se vérifie ou ne s'écrit pas. `meaning` et `application` sont des **lectures du texte lui-même** : elles s'appuient sur la citation, pas sur une archive. Une citation dont l'origine est introuvable peut donc être expliquée sans qu'une seule source soit inventée.

Le plafond de la provenance est réel, pas un travail inachevé : beaucoup de formules — notamment françaises — circulent sans origine identifiable. Une recherche sur la citation Bezos « votre marque est ce que les gens disent de vous » n'a donné **aucune source primaire**, alors que c'est une des phrases business les plus reprises au monde.

### Règles tenues sur l'ensemble

- **Aucune source non vérifiée.** C'est ce qui avait produit les 18 fausses citations retirées plus tôt.
- **Aucun conseil d'investissement personnalisé.** Sur les 79 citations de finance, les applications restent des règles de méthode : calculer son taux d'épargne, écrire ses critères à froid, vérifier d'où vient un rendement promis.
- **Aucune analyse ni application dupliquée** sur 1110 textes — vérifié automatiquement.

### Contrôles et migrations

Migrations `0011` (colonnes `meaning`/`application`), `0012` (286 premières fiches) et `0013` (les 555) appliquées en production. Chaque migration a été **réanalysée ligne par ligne et comparée champ par champ au JSON avant envoi** — le texte français est saturé d'apostrophes, une erreur d'échappement corromprait la base sans prévenir.

Un contrôle détecte les fiches à moitié remplies : il a déjà rattrapé deux Buffett passés à travers un lot.

### Contenu piloté serveur : ce que ça permet et ce que ça ne permet pas

Les corrections éditoriales ultérieures **ne demandent plus de build** — seulement du SQL. Mais le contenu serveur permet de changer ce que l'app sait déjà afficher, **pas de lui apprendre à afficher quelque chose de nouveau**. C'est exactement pourquoi les blocs principe/application n'apparaissaient pas dans le build 27 : le code qui les lit a été écrit après cet archivage.

## Infrastructure et identifiants (non sensibles, référence rapide)

- **Repo GitHub** : `https://github.com/SaintierEntreprises/Instant-Business.git` — compte isolé de l'autre projet de l'utilisateur (BetterBets). **Ne jamais mélanger les deux projets, ni Supabase ni Google Cloud ni GitHub.**
- **Supabase** : projet dédié `lexbvkrvgsaprrgijsrf` (`https://lexbvkrvgsaprrgijsrf.supabase.co`), organisation partagée avec BetterBets mais projet strictement séparé. CLI Supabase authentifiée et liée **uniquement** à ce projet (`supabase/.temp/project-ref` le confirme). Migrations `0001` à `0009` appliquées en prod **et inscrites dans l'historique distant** depuis le 30 août 2026 — `supabase db push` est donc utilisable normalement, voir la section sur la migration 0008.
- **Bundle IDs** : app `com.instantbusiness.app`, widget `com.instantbusiness.app.widget`, App Group `group.com.instantbusiness.app`.
- **Apple Team ID** : `7L2K39BW92`. Compte App Store Connect lié à l'identifiant Apple `6801872138`.
- **Éditeur légal** : Melvyn Saintier / Saintier Entreprises, SIRET 921 905 220 00023, contact `saintier.entreprises@gmail.com`.
- **Page légale publique** : `https://saintierentreprises.github.io/Instant-Business/`, servie depuis `docs/index.html` via GitHub Pages.
- **Tableau de bord analytique privé** : `docs/dashboard/index.html`, servi par GitHub Pages, protégé par un code d'accès stocké dans `secrets/dashboard_access_code.txt` (gitignoré, jamais committé). Voir section dédiée plus bas.
- **Abonnements StoreKit** : `com.instantbusiness.app.premium.monthly` (0,99 €/mois), `com.instantbusiness.app.premium.yearly` (7,99 €/an), groupe `Instant Business Premium`.
- **Secrets locaux** (dossier `secrets/`, gitignoré, vérifié via `git check-ignore -v`) : `APNs_InstantBusinessPush_CZ9BCPMS53.p8` (clé APNs), `dashboard_access_code.txt` (code d'accès dashboard). **Ne jamais committer ce dossier.**

## Grandes étapes déjà faites (dans l'ordre chronologique approximatif)

### Socle de l'app (avant la publication initiale)
1. App complète : widget multi-thèmes (Bold/Minimal/Dégradé/Sombre), fil de découverte avec carrousel, favoris, citation du jour déterministe par date, série de jours consécutifs, thèmes de fond de carte, paywall StoreKit.
2. Compte obligatoire via Sign in with Apple + Google Sign-In, sync Supabase (`favorites`, `user_state`).
3. Widget + notifications synchronisés par graine aléatoire par installation (`SharedDefaults.rotationSeed`).
4. Pages légales in-app et publiques, suppression de compte (Edge Function `delete-account`, guideline Apple 5.1.1(v)).
5. Plusieurs rounds de review Apple (refus 2.1 générique, refus 3.1.2(c) infos d'abonnement) → **acceptée et publiée dans la nuit du 20 au 21 août 2026.**
6. Contenu marketing (screenshots, carrousels réseaux sociaux, logo haute résolution).

### Profil prénom/genre + audit qualité (builds 18-19)
7. Écran de profil (genre puis prénom) après connexion, avant le quiz — accorde le nom/description du profil au féminin/masculin.
8. **Audit de code complet**, bugs réels corrigés : reset de série hors-ligne (`single()` de Supabase ne distinguait pas « pas de ligne » de « échec réseau » → corrigé avec `.limit(1)`), fuite de données entre comptes à la connexion (`SharedDefaults` pas effacé à la déconnexion → `discardDataFromAnotherAccount`), toggle notifications désynchronisé d'une révocation au niveau iOS, code mort dans `StreakManager`, bug de focus clavier à l'étape 3 du profil.
9. Ajout de la recherche par auteur, correctif de la mise à l'échelle du texte des cartes en grille (Favoris, page auteur), watermark discret sur les images partagées, consolidation des cartes paywall empilées sur la page auteur (un auteur multi-catégories affichait jusqu'à 3 cartes quasi identiques → une seule carte listant toutes les catégories verrouillées).

### Fonctionnalité premium offerte + blocage de version forcé
10. Mécanisme de don de Premium (verrouillage RLS complet) — voir `FORCER_MISE_A_JOUR.md` pour la procédure de blocage de version forcé, avec l'avertissement explicite de ne jamais fixer `minimum_version` avant que la version cible soit réellement en ligne sur l'App Store.

### Pipeline analytics + tableau de bord (le plus gros chantier de cette phase)
11. Table Supabase `events` (insertions fire-and-forget, colonne JSON `properties`, RLS insertion seule, lecture uniquement via edge function avec `service_role`).
12. Edge Function `dashboard-stats` (actuellement en v2) : agrégation complète — rétention, acquisition, contenu consulté, funnel.
13. `docs/dashboard/index.html` — PWA complète (actuellement v4), servie par GitHub Pages, avec cache-busting agressif (meta no-cache, `fetch(..., {cache: "no-store"})`, paramètre de requête horodaté, tampon de version visible à l'écran) après un bug de cache où le raccourci écran d'accueil de l'utilisateur affichait une version périmée malgré un déploiement confirmé par `curl`.
14. **Bug de notifications critique découvert via le dashboard** : les notifications tombaient à minuit et 4h du matin (rotation fixe `[4,8,12,16,20]` + citation du jour à minuit), corrélé à 5 désactivations / 0 activations dans les nouvelles analytics. Corrigé en créant `Shared/Models/NotificationFrequency.swift` (`light`/`balanced`/`frequent`, toutes les heures entre 8h et 21h), réglable au moment de l'inscription et dans Réglages, `.balanced` par défaut (3/jour) plutôt que l'ancien rythme implicite à 6/jour.
15. `NotificationManager.rollingWindowDays` rendu dynamique (`min(14, max(3, 55 / perDay))`) pour rester sous le plafond iOS de 64 notifications en attente quel que soit le rythme choisi.
16. Système de push notifications ciblées ou diffusées, envoyées depuis le tableau de bord :
    - Clé APNs `.p8` créée côté développeur Apple, JWT ES256 signé côté Edge Function.
    - Table `device_tokens` (migration `0007`), `PushRegistrar.swift` (enregistre le token, `environment` fixé par build : `#if DEBUG` → sandbox, sinon production — **TestFlight et App Store utilisent tous les deux `production`**, seul un run Xcode DEBUG est en sandbox).
    - Edge Function `send-push` déployée, sécurisée par un header `DASHBOARD_TOKEN`.
    - Composeur de push dans le tableau de bord, testé de bout en bout avec un vrai appel API Apple.

### Tri qualitatif des citations
17. Retrait de 116 citations jugées trop faibles, indéfendables ou mal attribuées après une revue manuelle complète déclenchée par un exemple de citation Ronaldo jugée médiocre par l'utilisateur — 689 → 573 citations, 258 auteurs.

### Réduction du parcours d'inscription (10 → 7 écrans)
18. Quiz réduit de 6 à 3 questions (`InstantBusiness/Models/QuizModel.swift`) : question 0 « Où en es-tu aujourd'hui ? » (porte aussi `QuizStage`), question 1 « Que veux-tu développer en priorité ? », question 2 « Ton objectif des 6 prochains mois ? » (porte aussi `QuizIntent`). Les questions retirées nuançaient sans jamais changer les catégories affichées.
19. `QuizProfile.name` renommé en `QuizProfile.key` (identifiant interne pour l'analytics, jamais affiché) — le nom de profil visible a été **entièrement retiré** de l'écran de résultat (`QuizResultView` dans `QuizView.swift`), jugé creux par l'utilisateur quel que soit le libellé essayé. C'est `profile.tagline` (la description) qui fait maintenant office de titre, promue en `.title2 rounded bold`.
20. Descriptions (`tagline`) resserrées à ≤ 72 caractères, insigne remonté verticalement (`Spacer(minLength: 0).frame(maxHeight: 76)` au lieu d'un `Spacer()` qui centrait tout le bloc trop bas).
21. `OnboardingChrome.swift` : `profileStepCount = 4`, `quizStepCount = 3`, total 7 étapes, compteur et barre de progression partagés entre les deux flux.
22. Vérification combinatoire exhaustive (script Python hors app) que les 100 combinaisons de réponses possibles couvrent bien les 6 profils et ne produisent jamais un jeu de catégories vide, avant et après la réduction du quiz.

## Préférences et règles à respecter absolument

- **Isolation stricte BetterBets / Instant Business** : jamais mélanger Supabase, Google Cloud, GitHub entre les deux projets, même si le compte utilisateur est parfois le même.
- **Ne jamais committer sans demande explicite. Ne jamais pousser (`git push`) sans confirmation explicite à chaque fois** — l'outil bloque de toute façon automatiquement ces actions.
- **Toujours bump `CURRENT_PROJECT_VERSION`** dans `project.yml` avant tout changement destiné à un nouveau build, suivi de `xcodegen generate`. Bump aussi `MARKETING_VERSION` si la version courante a déjà été approuvée/est en ligne sur l'App Store (message d'erreur type : « Invalid Pre-Release Train » / « CFBundleShortVersionString must be higher »).
- **Vérifier par la vraie compilation** (`xcodebuild ... build`) après chaque changement, jamais supposer que ça compile.
- Pour un test visuel dans le simulateur nécessitant de contourner l'écran de connexion : utiliser le marqueur `// TEMP-UI-CHECK` dans `ContentView.swift`, **toujours le retirer et vérifier par `grep -rn "TEMP-UI-CHECK"` avant de considérer la tâche terminée**.
- L'utilisateur préfère des réponses concises, orientées action, sans réexpliquer ce qui est déjà su. Il code peu lui-même et passe par Xcode/App Store Connect en suivant des instructions précises — toujours donner des étapes concrètes (quel bouton, quel champ) plutôt que des explications abstraites.
- **Secrets** (`secrets/`, `*.p8`) : jamais committés, `.gitignore` déjà en place et vérifié.
- Après un changement de code significatif, l'utilisateur demande régulièrement un nouvel archivage de build pour tester sur son iPhone via TestFlight — s'attendre à cette demande après toute session de modifications.

## Historique Apple Review — à garder en tête pour toute future soumission

L'utilisateur a un autre projet (BetterBets) qui a essuyé de nombreux refus Apple (paiements hors IAP, EULA manquant, métadonnées inexactes, captures avec prix visible, app iPad non fonctionnelle). Cette expérience a rendu la vigilance sur ces points **systématique** pour Instant Business : toujours vérifier qu'aucun prix n'apparaît dans les captures App Store, que le lien EULA est présent dans la description, que les métadonnées décrivent fidèlement ce qui existe réellement dans le build soumis, et qu'aucun contenu marketing ne décrit un écran qui n'existe pas dans l'app.
