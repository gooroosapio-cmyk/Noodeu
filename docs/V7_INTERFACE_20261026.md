# Noodeu V7 — intégration locale (26/10/2026)

Branche locale `v7/interface-20261026`, partie de `70fb169` (production actuelle). **Travail local uniquement** :
aucun déploiement, aucune migration, aucune modification de données, aucun push distant (consigne du kit V7).

Source : `Noodeu_Interface_V7_Kit_Complet_1.zip` (pièce jointe) et `PROMPT_CLAUDE_V7.txt`, lus en entier :
`REGLES_INTERFACE_V7.md`, `MANIFEST_RESSOURCES_V7.json`, `screen-layouts.json`, `RENDER_NOTES.md`, 18 PNG témoins.
Consigne supplémentaire du propriétaire : **l'icône flottante de conversation reste fixe**.

## Audit de départ

- Thème : les sept valeurs cerise du kit étaient déjà les tokens actifs (`--c-accent #B72132`, `--c-bg #F7F1F1`, …) ;
  Nunito Sans 700/800 et DM Sans 400–700 déjà chargées via `@fontsource`. Inchangés.
- Logo : `Ressources/noodeu-logo-couleur.svg` est identique (au retour à la ligne près) au fichier du dépôt ; conservé tel quel.
- Bouton conversation : il se **déplaçait** (recalcul de position à chaque défilement pour éviter le contenu).
- « Courte / Approfondie » : affichage local seulement (question du jour, cartes de packs), sans effet serveur.
- Temps réel : instantané autoritaire relu par RPC, canal privé par séance avec présence, garde de version,
  relecture à la reprise, coups dédupliqués côté serveur par `action_id` (`private.board_moves`) et revalidés
  (tour, phase). Écarts : relectures concurrentes non regroupées ; relecture toutes les 4 s sans backoff en panne.

## Modifications

| Sujet | Fichiers |
|---|---|
| Bouton conversation fixe (52 px, 16 px du bord, 12 px au-dessus de la navigation), bande basse réservée : la zone défilante s'arrête au-dessus | `src/duo/Chat.tsx`, `src/styles/v7.css` |
| Fond décoratif animé (SVG du kit, ±3/±4 px, 24 s), suspendu si document masqué ou couche hors champ, fixe en mouvement réduit ou avec « Réduire les animations » (réglage existant du profil) | `src/components/Ambient.tsx`, `src/App.tsx`, `src/i18n/fr.ts` |
| Accueil : accroche réelle du catalogue (`hook`, sinon `promise`) au lieu de « À deux », durée séparée ; Question du moment sur fond statique du kit | `src/screens/Home.tsx` |
| Suppression de « Courte / Approfondie » (sans rangée vide ; la relance « approfondie » n'est plus affichée) ; une seule progression dans les packs | `src/parcours/DailyCard.tsx`, `src/parcours/meta.tsx`, `src/game/board/QuestionnaireGames.tsx` |
| Bibliothèque : cartes compactes (image 80×72 au-dessus du titre), une colonne d'elle-même à texte agrandi | `src/styles/v7.css` |
| Notre espace : couverture 128 px, identité en ligne sans symbole ; aperçu limité à 3 parties + « Tout voir » | `src/screens/OurSpace.tsx`, `src/duo/DuoDashboard.tsx` |
| Historique dédié paginé par 5, pagination serveur (`range`) et total exact | `src/screens/History.tsx`, route `/espace/historique` |
| Chat : bulles groupées (4 px / 14 px), heure en fin de groupe, largeur 78 %, position de lecture préservée | `src/duo/Chat.tsx` |
| Jeu : saisie réelle en pied (remplace la navigation), focus → conversation intégrée à 58 % avec « Retour au jeu », brouillon partagé avec le chat (stockage d'onglet existant), état de jeu conservé ; le pied ne recouvre pas les actions | `src/game/red/GameComposer.tsx`, `src/game/SessionScreen.tsx`, `src/components/ui.tsx` |
| Clavier : compensation `visualViewport` seulement si la page n'est pas déjà réduite (pas de double décalage) | `src/lib/useKeyboardInset.ts` |
| Temps réel : relectures regroupées (une seule en vol), backoff borné avec jitter (4 → 30 s) en panne | `src/game/useSession.ts` |

Brouillons G08 en `sessionStorage` : inchangés (restauration au rechargement, purge à la fin de manche ou Passer,
effacement à la déconnexion).

## Vérifications exécutées (émulation Chromium, pas d'appareil réel)

- `npm run lint`, `npm run typecheck`, `npm test` (13), `npm run build` : OK.
- `tests/visual/v7-flows.mjs` (8 scénarios, 360/390/412) : bouton fixe ne bougeant pas au défilement, 12 px au-dessus
  de la navigation et 16 px du bord, zone défilante arrêtée au-dessus ; en jeu pas de navigation, actions ≥ 16 px
  au-dessus du pied, focus → chat intégré, « Retour au jeu » conserve le jeu et le brouillon ; question sans
  « Courte / Approfondie » et une seule barre de progression ; aperçu de l'espace ≤ 3 parties avec « Tout voir ».
- Parcours existants rejoués : salon (5), G01/G08 (10), clavier ouvert (6) : OK.
- Recette visuelle `render-check.mjs` à 390 px sur tous les écrans, et texte à 200 % / 412 px sur les écrans principaux.
- Lecture d'état en base de production (lecture seule, 30 appels) : p50 1,2 ms, p95 2,6 ms, 4,9 ko.

## Non fait ou non mesurable ici

- Mesures réseau à deux clients (p95 action → confirmation, confirmation → autre client, reprise) : le conteneur ne
  peut pas joindre Supabase ni l'application en ligne ; seule la durée en base a été mesurée. À mesurer sur appareil.
- Identifiant d'intention stable entre tentatives : il n'y a pas de nouvelle tentative automatique ; le serveur
  déduplique par `action_id` et refuse un second coup hors phase. Un retry automatique devrait réutiliser l'identifiant.
- Coffre et notes : modules existants conservés tels quels ; pas de nouveau service.

## Passe de fidélité aux témoins (accueil 01, espace 04/05/06, conversation 07/08)

Demande du propriétaire : rester entièrement fidèle aux témoins pour l'accueil, la conversation et l'espace.

| Témoin | Réalisation | Fichiers |
|---|---|---|
| 01 Accueil | Carte duo (avatars superposés, « Votre duo », bouton d'échange 44 px), filtres, carrousel, tuiles « Question du moment » et « À reprendre » (progression réelle « Question/Manche x sur y »), « Récemment joués » + « Tout voir » ; section masquée à 360 px comme le témoin | `src/screens/Home.tsx`, `src/screens/v7parts.tsx`, `src/duo/DuoSwitcher.tsx` |
| 04 Espace | « Espace avec X » + menu (duos, épisodes, gestion, invitation), couverture 128 px avec crayon, « Seulement toi et X », accès Coffre / Nos notes, 3 parties récentes (durée réelle début → fin) + « Tout voir » | `src/screens/OurSpace.tsx`, `src/duo/DuoDashboard.tsx` |
| 05 Coffre | Page dédiée avec retour : onglets Souvenirs / Nos notes, cartes « Gardé par vous deux · date » des parties gardées par les deux | `src/screens/Vault.tsx`, `src/components/AppShell.tsx` |
| 06 Historique | « Vos parties », filtres Toutes / Terminées / À reprendre, 5 par page, total exact côté serveur | `src/screens/History.tsx` |
| 07/08 Conversation | Plein écran sans navigation ni bouton flottant : retour, avatar, nom, « Votre conversation » ; séparateur de jour ; bulles blanches / roses (rayon 18, 78 %) ; heure sous chaque fin de groupe ; saisie fixe 52 px, bordure cerise au focus, envoi rouge 52 px ; pas de clavier ouvert d'office (sauf depuis la saisie en jeu) | `src/duo/Chat.tsx`, `src/styles/v7.css` |

Écarts assumés :
- Pas de bouton « … » dans les en-têtes (coffre, historique, conversation) : il n'aurait aucune action réelle.
- Pas de citation dans les cartes du coffre : aucune réponse n'est stockée pour être affichée, et les réponses intimes ne sont pas exposées.
- Les flèches de pagination gardent une cible de 44 px (règle d'accessibilité du kit).
- Le contenu (titres, dates, durées, notes) est celui du compte ; les témoins montrent des données fictives.

Vérifications de cette passe : lint, typecheck, tests unitaires, build ; `v7-flows.mjs` (9 scénarios, dont la conversation
plein écran et l'aperçu de l'espace), salon (5), G01/G08 (10), clavier (6) ; `render-check.mjs` à 360/390/412 et texte
à 200 % sur accueil, espace, coffre, historique et conversation. Comparaisons côte à côte dans `docs/captures/v7-20261026/fidelite-*.jpg`.

## Optimisations avant mise en ligne (fluidité, rapidité)

Mesures sur le build local (Chromium émulé, réponses Supabase simulées).

| Mesure | Avant | Après | Changement |
|---|---|---|---|
| JavaScript au premier affichage (gzip) | 297 ko, 1 fichier | 217 ko : appli 60 + React 99 + Supabase 55 | Écran de jeu et administration chargés à la demande ; jeu préchargé en temps mort après connexion |
| Ce qu'un déploiement fait retélécharger | 297 ko | ≈ 60 ko (+ écran de jeu modifié) | Bibliothèques (React, routeur, Supabase) dans des fichiers stables |
| Requêtes Supabase à l'ouverture de l'Espace | 20 | 16 | Catalogue partagé en mémoire, requêtes simultanées fusionnées, réutilisé 30 s entre écrans |
| Retour sur un écran déjà vu | catalogue rechargé, chargement visible | affichage immédiat, relecture en arrière-plan | idem |
| Préchargement hors ligne | polices cyrillique et vietnamienne incluses | exclues (servies si jamais nécessaires) | `vite.config.ts` |
| Connexion à Supabase | ouverte après le chargement du code | ouverte dès le HTML (`preconnect`, URL publique) | `vite.config.ts` |
| Fichiers compilés (nom haché) | revalidés à chaque ouverture | cache permanent (`immutable`) | `vercel.json` (à contrôler en ligne) |

Sécurité du découpage : si un ancien fichier a disparu après un déploiement, la page se recharge une seule fois
(garde en `sessionStorage`) au lieu d'afficher une erreur. Le catalogue en mémoire est propre au compte ; rien
n'est écrit sur disque, aucune réponse de jeu ou message n'est mis en cache.
