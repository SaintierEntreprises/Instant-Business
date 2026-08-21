# Instant Business — état du projet

Document de passation, écrit le 21 août 2026. Lis ce fichier en entier avant toute action — il remplace l'historique de conversation d'une session précédente qui a rempli son quota.

## Ce qu'est l'app

App iOS native (Swift/SwiftUI + WidgetKit), en français, façon Punchlines/Instant Bible mais pour l'entrepreneuriat : citations business affichées sur écran d'accueil/verrouillage, 568 citations en 4 catégories (Mindset, Vente, Leadership, Finance), compte obligatoire (Sign in with Apple/Google) pour synchroniser favoris et série, abonnement Premium via StoreKit.

**Statut : publiée et en ligne sur l'App Store** depuis la nuit du 20 au 21 août 2026, après plusieurs allers-retours de review (détaillés plus bas).

## ⚠️ Priorité n°1 pour la prochaine session : rien n'est poussé sur GitHub

```
git status --short   # liste les fichiers modifiés/nouveaux ci-dessous
git log origin/main..HEAD --oneline   # 6 commits locaux jamais poussés
```

- **6 commits locaux non poussés** (builds 13 à 17 : corrections de connexion, paywall, notifications).
- **Travail du build 18 pas encore commité du tout** : la nouvelle étape prénom/genre après connexion (détails plus bas). Fichiers modifiés/nouveaux à ce stade : `InstantBusinessApp.swift`, `QuizModel.swift`, `AuthManager.swift`, `UserSyncService.swift`, `ContentView.swift`, `CardFeedView.swift`, `QuizView.swift`, `SharedDefaults.swift`, `project.yml`, plus nouveaux fichiers `ProfileSetupView.swift`, `Gender.swift`, `supabase/migrations/0002_profile.sql`.
- `git push` a été bloqué plusieurs fois par le classificateur de sécurité automatique de l'outil — c'est normal, il faut que l'utilisateur lance `git push` lui-même dans son terminal, ou confirme explicitement avant une nouvelle tentative.
- Dossier `IB designs/` : fichiers de travail (screenshots App Store, exports Claude Design) non versionnés, laissés tels quels, ne pas les ajouter au dépôt sans demande explicite.

## Infrastructure et identifiants (non sensibles, référence rapide)

- **Repo GitHub** : `https://github.com/SaintierEntreprises/Instant-Business.git` — compte isolé de l'autre projet de l'utilisateur (BetterBets). **Ne jamais mélanger les deux projets, ni Supabase ni Google Cloud ni GitHub.**
- **Supabase** : projet dédié `lexbvkrvgsaprrgijsrf` (`https://lexbvkrvgsaprrgijsrf.supabase.co`), organisation partagée avec BetterBets mais projet strictement séparé. Clé publishable déjà dans le code (`SupabaseProvider.swift`), c'est normal qu'elle soit publique.
- **Bundle IDs** : app `com.instantbusiness.app`, widget `com.instantbusiness.app.widget`, App Group `group.com.instantbusiness.app`.
- **Apple Team ID** : `7L2K39BW92`. Compte App Store Connect lié à l'identifiant Apple `6801872138`.
- **Éditeur légal** : Melvyn Saintier / Saintier Entreprises, SIRET 921 905 220 00023, contact `saintier.entreprises@gmail.com`.
- **Page légale publique** (CGU/CGV/Confidentialité/Support, exigée par Apple) : `https://saintierentreprises.github.io/Instant-Business/`, servie depuis `docs/index.html` via GitHub Pages.
- **Abonnements StoreKit** : `com.instantbusiness.app.premium.monthly` (0,99 €/mois), `com.instantbusiness.app.premium.yearly` (7,99 €/an), groupe `Instant Business Premium`.
- **Build actuel** : `CURRENT_PROJECT_VERSION` = 18 dans `project.yml` (le build 17 est celui publié sur l'App Store ; le 18 contient le profil prénom/genre, pas encore soumis).

## Grandes étapes déjà faites (dans l'ordre)

1. **App complète construite** : widget multi-thèmes (Bold/Minimal/Dégradé/Sombre), fil de découverte avec carrousel, favoris, citation du jour (identique pour tous, déterministe par date), série de jours consécutifs, quiz d'onboarding en 6 questions (détermine un profil + catégories préférées), thèmes de fond de carte (Couleur/Crème/Blanc/Sombre/Nuit), paywall StoreKit.
2. **568 citations, 273 auteurs**, mélange français/international, dédupliquées, mélange vraiment aléatoire par utilisateur (`ContentStore.shuffledAvoidingAdjacentAuthors`) — corrigé après un bug où les citations groupées par auteur se répétaient.
3. **Compte obligatoire** via Sign in with Apple + Google Sign-In, sync Supabase (table `favorites`, table `user_state` pour le streak).
4. **Widget + notifications synchronisés** : le widget change de citation toutes les heures (timeline WidgetKit à entrées multiples), les notifications tombent toutes les 6h (00h/06h/12h/18h, ancrées sur des heures fixes — un bug initial les ancrait sur l'heure de dernière ouverture, ce qui les repoussait indéfiniment) plus la citation du jour à minuit pour tout le monde. `ContentStore.rotatingQuote(seed:unit:)` + graine aléatoire par installation (`SharedDefaults.rotationSeed`) garantissent que widget et notifications montrent la même chose au même moment.
5. **Pages légales in-app** : CGU, CGV, Politique de confidentialité, rédigées et intégrées (`LegalDocumentView`, `LegalDocument` model, fichiers `.md` dans `InstantBusiness/Resources/Legal/`), liées depuis Réglages, le paywall et l'écran de connexion.
6. **Suppression de compte** (guideline Apple 5.1.1(v)) : Edge Function Supabase `delete-account` déployée et active, bouton dans Réglages > Compte, teste et fonctionne réellement (vérifié via les logs Supabase en prod).
7. **Icône d'app** : symbole `quote.bubble.fill` blanc sur fond dégradé orange, choisi après une longue exploration de variantes.
8. **Correctifs de bugs découverts en cours de route** (tous commités) :
   - Version du widget codée en dur (`1.0`/`1`) au lieu de suivre `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`.
   - `TARGETED_DEVICE_FAMILY` : project.yml le mettait à `"1"` (iPhone seul) au niveau projet, mais XcodeGen l'écrasait à `"1,2"` (iPad inclus) au niveau des cibles — corrigé en le fixant explicitement par cible. C'était la cause probable d'un premier souci de review Apple (captures iPad demandées).
   - Statut Premium jamais revérifié après le lancement initial (`store.refresh()` ajouté au retour au premier plan).
   - Écran de connexion qui clignotait au lancement le temps que Supabase restaure la session (`isRestoringSession` + `LaunchPlaceholderView`).
   - **Bug majeur de connexion** : après une connexion réussie (Apple ou Google), l'app restait bloquée sur l'écran de connexion. Trois causes cumulées, toutes corrigées : (a) `OnboardingView` attendait la réponse à la demande d'autorisation notifications avant de marquer l'onboarding terminé — bloquant si le prompt ne s'affichait pas ; (b) la hiérarchie de vues donnait priorité au drapeau d'onboarding sur la présence d'une session ; (c) la session n'était mise à jour que via le flux `authStateChanges`, jamais directement au retour de `signInWithIdToken`.
   - Nonce de connexion Apple régénéré à chaque reconstruction du bouton par SwiftUI (causait des échecs intermittents « Nonces mismatch ») — le nonce en cours est maintenant réutilisé pendant toute la tentative. Pour Google, le SDK gère son propre nonce en interne : la vérification du nonce est désactivée côté config Supabase pour ce provider (`external_google_skip_nonce_check: true`), c'est volontaire et documenté dans le code.
9. **Review Apple, plusieurs rounds** (soumission `ef51fd41-801b-40b2-a9c7-94bef74e8c74`) :
   - Refus 2.1 (demande d'infos génériques, quasi systématique pour un premier compte) → répondu avec vidéo + réponses détaillées.
   - Refus 3.1.2(c) (infos d'abonnement manquantes dans le parcours d'achat + lien EULA manquant dans la description) → paywall enrichi (durée affichée sous le prix, liens CGU/CGV/Confidentialité), lien vers l'EULA standard Apple ajouté dans la description App Store Connect.
   - Un blocage technique côté App Store Connect (élément "Retiré" impossible à resoumettre) a nécessité de retirer/resoumettre les abonnements et le groupe d'abonnements séparément.
   - **App acceptée et publiée** dans la nuit du 20 au 21 août 2026.
10. **Contenu marketing produit** : screenshots App Store (10 images, 1284×2778, corrigées pour ne montrer aucun prix ni écran fictif inexistant dans l'app), carrousel Instagram/TikTok (6 slides, dossier `IB designs/export-hd/`), stories Instagram (3 slides racontant la genèse), post LinkedIn, bio Instagram/TikTok optimisées SEO, logo haute résolution (`Logo-InstantBusiness-5000.png`, régénéré depuis le symbole SF vectoriel, pas un agrandissement).
    - **Point de vigilance découvert** : une citation utilisée dans les visuels marketing (« L'échec n'est pas une chute, c'est un rebond » — Bernard Tapie) est **fictive**, inventée par l'outil de génération d'images, et n'existe pas dans `content.json`. Elle n'a été utilisée que dans des visuels externes (jamais dans l'app elle-même), mais à surveiller si d'autres visuels reprennent des citations non vérifiées.

## En cours / pas encore committé : profil prénom + genre

Demande explicite de l'utilisateur : après la connexion et **avant le quiz**, demander le genre puis le prénom, un écran à la fois (pas les deux sur le même écran — changement demandé en cours de route). Objectif : accorder le nom du profil du quiz au féminin/masculin et saluer par prénom.

**Fichiers créés :**
- `Shared/Models/Gender.swift` — enum `homme`/`femme`, avec `feminineSuffix`.
- `InstantBusiness/Views/Onboarding/ProfileSetupView.swift` — deux étapes (`.gender` puis `.name`), transition automatique après sélection du genre (comme le quiz), champ prénom avec clavier auto-focus, bouton retour sur l'étape 2.
- `supabase/migrations/0002_profile.sql` — colonnes `first_name` et `gender` ajoutées à `user_state` (déjà appliquées en prod via l'API Supabase, pas seulement dans le fichier de migration).

**Fichiers modifiés :**
- `ContentView.swift` — nouvelle branche `!hasCompletedProfile` entre la connexion et le quiz.
- `QuizModel.swift` — `Quiz.profile(for:gender:)` accorde maintenant le nom du profil (« La Déterminée », « La Bâtisseuse », etc.).
- `QuizView.swift` — l'écran de résultat affiche « [Prénom], ton profil » si disponible.
- `CardFeedView.swift` — l'en-tête du fil affiche « Salut [Prénom] » à la place de « Instant Business » si disponible.
- `SharedDefaults.swift` — nouvelles clés `firstName`/`gender`, effacées lors de la suppression de compte.
- `UserSyncService.swift` — `saveProfile()` envoie prénom/genre à Supabase ; **attention** : les écritures streak et profil sont volontairement séparées (`StreakUpdate` vs `ProfileUpdate`) pour qu'un upsert ne vide pas les colonnes de l'autre.
- `InstantBusinessApp.swift` — au retour au premier plan, si le profil existe côté serveur (nouvel appareil), il est restauré localement plutôt que redemandé.
- `AuthManager.swift` — `hasCompletedProfile` réinitialisé à la suppression de compte.

**Testé dans le simulateur** : les deux écrans s'affichent et s'enchaînent correctement (bascule automatique après sélection du genre, focus clavier auto sur le prénom, bouton retour fonctionnel). **Jamais testé de bout en bout avec une vraie connexion Supabase** (sauvegarde réelle en base, restauration sur un second appareil) — à vérifier avant de soumettre le build 18.

**Reste à faire sur ce chantier :**
1. Tester la sauvegarde réelle côté Supabase (vérifier que `first_name`/`gender` arrivent bien en base).
2. Tester la restauration sur un compte déjà existant (créer un profil, se déconnecter, se reconnecter — le profil doit être récupéré sans repasser par `ProfileSetupView`).
3. Committer (build 18 pas encore dans git du tout).
4. Décider si ce changement justifie une nouvelle soumission App Store immédiate ou peut attendre une prochaine mise à jour groupée.

## Préférences et règles à respecter absolument

- **Isolation stricte BetterBets / Instant Business** : jamais mélanger Supabase, Google Cloud, GitHub entre les deux projets, même si le compte utilisateur est parfois le même.
- **Ne jamais committer sans demande explicite.** Ne jamais pousser (`git push`) sans confirmation explicite à chaque fois — l'outil bloque de toute façon automatiquement ces actions, il faut que l'utilisateur les lance lui-même ou confirme juste avant.
- **Toujours bump `CURRENT_PROJECT_VERSION`** dans `project.yml` avant tout changement destiné à un nouveau build, suivi de `xcodegen generate`.
- **Vérifier par la vraie compilation** (`xcodebuild ... build`) après chaque changement, jamais supposer que ça compile.
- Pour un test visuel dans le simulateur nécessitant de contourner l'écran de connexion : utiliser le marqueur `// TEMP-UI-CHECK`, **toujours le retirer et vérifier par `grep -rn "TEMP-UI-CHECK"` avant de considérer la tâche terminée**.
- L'utilisateur préfère des réponses concises, orientées action, sans réexpliquer ce qui est déjà su.
- Ton habituel des échanges : français, direct, l'utilisateur code peu lui-même et passe par Xcode/App Store Connect en suivant des instructions précises — toujours donner des étapes concrètes (quel bouton, quel champ) plutôt que des explications abstraites.

## Historique Apple Review — à garder en tête pour toute future soumission

L'utilisateur a un autre projet (BetterBets) qui a essuyé de nombreux refus Apple (paiements hors IAP, EULA manquant, métadonnées inexactes, captures avec prix visible, app iPad non fonctionnelle). Cette expérience a rendu la vigilance sur ces points **systématique** pour Instant Business : toujours vérifier qu'aucun prix n'apparaît dans les captures App Store, que le lien EULA est présent dans la description, que les métadonnées décrivent fidèlement ce qui existe réellement dans le build soumis, et qu'aucun contenu marketing ne décrit un écran qui n'existe pas dans l'app.
