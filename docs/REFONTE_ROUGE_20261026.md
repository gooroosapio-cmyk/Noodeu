# Refonte rouge du salon et des jeux — 26/10/2026

Branche : `refonte/rouge-20261026`, partie de `28ac1bb` (version Codex en production). Rien n'est déployé ni appliqué
en ligne : la migration `20261030001200` et le front attendent l'autorisation du propriétaire.

Source : `Noodeu_Rouge_Kit_Complet.zip` (dossier Drive du propriétaire), lu en entier pour `LIRE_D_ABORD.txt`,
`05_integration/*` (règles, prompt, manifest, zones) ; les 28 écrans de `01_maquettes` ont servi de référence visuelle.

## Inventaire et correspondance jeux ↔ kit

| Code | Mécanique | Fond | Illustration | Disposition |
|---|---|---|---|---|
| Salon | `lobby` | fond_salon | illustration du jeu | settings / ready |
| G01 Action ou vérité | `nd_truth_dare` | fond_papeterie | cartes_action_verite | card, **sans saisie** |
| G02 Je n'ai jamais | `nd_never` | fond_jetons | coeurs_duo + jeton_deja / jeton_jamais | binary |
| G03 Tu préfères | `nd_dilemma` | fond_jetons | portes_dilemme | binary |
| G04 Qui de nous deux | `nd_duo_target` | fond_jetons | cadres_duo (avatars réels) | binary |
| G05 Devine ma réponse | `nd_predict` | fond_papeterie | enveloppe_verrouillee | textarea |
| G07 Cite trois | `nd_name_three_call` | fond_papeterie | sablier | oral |
| G08 Deux vérités | `nd_two_truths` | fond_papeterie | masque_trois_cartes | three_inputs, **tour par tour** |
| G09 Complète la phrase | `nd_sentence` | fond_carnet | carnet_phrase | textarea |
| G10 D'accord ou pas | `nd_opinion` | fond_jetons | balance_avis | binary |
| M01 Morpion | `tic_tac_toe` | fond_pierre | pion_x / pion_o | board |
| M04 Points et carrés | `dots_boxes` | fond_pierre | tuiles_petit_bac | board |
| M07 Bataille navale | `battleship` | fond_pierre | navire_* | board |
| M09 Pendu | `nd_hangman` | fond_carnet | ballon_pendu | keyboard |
| M11 PFC | `rps` | fond_pierre | geste_* | three_choices |
| M12 Dé chanceux | `nd_pig` | fond_pierre | piste_de + de_face_1…6 | dice |
| M16 Petit bac | `nd_categories_stop` | fond_carnet | tuiles_petit_bac | eight_inputs |
| Packs / questionnaires | `pack_conversation` / `test_form` | papeterie / carnet | enveloppe / cartes_questionnaire | textarea / radio |
| Pause, fin | — | fond_pierre / fond_jetons | pause_reconnexion, trophee_victoire, trophees_egalite, coeur_reessayer | — |

Mapping typé : `src/game/red/kit.ts` (`RED_KITS`, `redKitOf`, `RED_PIECES`). Ressources : `public/assets/noodeu/red-v1`
(70 WebP vérifiés par SHA-256 contre le manifest du kit, 22 SVG relus : ni script ni lien externe).

## Fichiers

- `src/game/red/ui.tsx` : GameShell, GameHeader, DuoStrip, RoundProgress, GameHero, QuestionCard, ChoiceCard,
  GameTextarea, GameActions, ReadyStatus, GameSettingsRow, ResultPanel, ReconnectBanner. La feuille de conversation
  existante (`ChatPanel`) sert de ConversationSheet ; elle s'ouvre depuis l'en-tête, plus de bulle flottante en partie.
- `src/game/red/Lobby.tsx` : préparer → validation des deux → tout est prêt → lancement par l'hôte.
- `src/game/red/ConversationRed.tsx` : G01 oral, G08 tour par tour, barre « Continuer ».
- `src/styles/red-kit.css` : tokens du kit rapprochés des tokens réels (accent Noodeu conservé), cadre 480 px, en-tête 48,
  bandeau 52, avancement 24, illustration 120–176 (110 si écran bas, 72 quand un champ a le focus), actions collantes
  dans le flux, `prefers-reduced-motion`. Neutralise les hauteurs fixes de l'ancienne console (`contain: size`, cartes à
  hauteur imposée) : un seul défilement, cartes ajustées au texte.
- `SessionScreen.tsx` : nouvel en-tête (chevron Réduire, titre unique, conversation, menu « … » : règles, options,
  pause, quitter), bandeau des joueurs, avancement « Manche i/N » seulement quand N est le vrai nombre de manches
  (pas pour les jeux à objectif : dé 30, Cite trois 30, morpion, PFC, navale, points et carrés).
- `BoardPieces.tsx` : faces exactes du dé et pions du kit, ancienne image puis SVG en secours.

## Serveur — `supabase/migrations/20261030001200_salon_revision_g01_oral_g08_tours.sql` (non destructive)

1. **Révision de configuration** : `game_sessions.settings_rev`, `session_players.ready_rev`. Déclencheurs : tout
   changement effectif des réglages (quelle que soit la fonction) ou des préférences de séance crée une révision et retire
   les validations. `set_ready_rev(session, ready, rev)` valide une révision précise, ne lance jamais.
   `launch_session(session, rev)` : réservé à l'hôte (créateur de la séance, sinon siège 1), deux joueurs ayant accepté
   la révision courante ; verrou de ligne, second appel → `ok, already` (double clic sans seconde partie).
   `get_session_state` est enrichi (`settings_rev`, `host_seat`, `ready_rev`) ; l'ancienne fonction est conservée sous
   `private.get_session_state_base`.
2. **G01** : coup `mark_done` (Vérité → `answered`, Action → `done`, sans texte même si un texte est envoyé). Nouvelle
   version de règles (`answer: oral`). `submit_text` / `submit_action` restent acceptés : historique et clients ouverts
   intacts. Le moteur existant est conservé sous `private.board_apply7_before_oral`.
3. **G08** : nouvelle version sans `mode` → moteur tour par tour (déjà présent), 3 / 5 / 7 tours (5 par défaut). Les
   séances simultanées déjà créées gardent leur version.

Compatibilité : le nouveau front fonctionne avec l'ancien serveur (sans `settings_rev`, il revient à `set_ready` ; G01
non oral garde l'ancien écran ; G08 simultané garde son théâtre). L'ancien front fonctionne avec le nouveau serveur
(`set_ready` inchangé). Ordre conseillé : appliquer la migration, puis promouvoir le front.

Écart à signaler : la présence « connecté » est une information temps réel côté client ; le serveur exige deux joueurs
inscrits et d'accord, le bouton « Lancer » de l'hôte n'est actif que si l'autre est présent dans le salon.

## Vérifications exécutées (émulation Chromium, pas d'appareil réel)

- `npm run lint`, `npm run typecheck`, `npm test` (13), `npm run build` : OK.
- SQL sur PostgreSQL local jetable : toute la suite (`scripts/run_sql_tests.sh`, étapes c18–c40 avant la migration, puis
  `c41_salon_revision_g01_g08.sql`) : OK. c41 couvre : pas de lancement à une validation, pas de démarrage silencieux,
  seul l'hôte lance, révision invalidée par réglage et préférences, révision périmée refusée sans effet, lancement
  idempotent (une manche), G08 sans écriture simultanée et sans fuite du mensonge, G01 sans texte conservé.
- Parcours : `tests/visual/lobby-ready-lifecycle.mjs` (4 scénarios) et `tests/visual/red-games-flows.mjs` (7 scénarios,
  320 / 390 / 412 px) : OK.
- Recette visuelle `tests/visual/render-check.mjs` : états réels générés par `tests/visual/make_fixtures_rouge.py`.
- Captures avant / après : `docs/captures/rouge-20261026/`.

## Restes

- L'accueil « Notre salon » de la maquette (code d'invitation, liste de jeux) correspond à l'accueil de l'application :
  non modifié dans ce lot.
- Les plateaux des mini-jeux gardent leur dessin actuel (déjà en code) ; seuls le cadre, les pièces du kit (dé, pions),
  les illustrations et les écrans de fin changent. Les tailles réelles restent celles du dépôt (flotte 5/4/3/3/2,
  dé 30, petit bac 8 rubriques en 2×4, Cite trois 10 s / +3 / 30).
- La présence de deux sessions réelles n'a pas pu être testée de bout en bout ici (temps réel Supabase inaccessible
  depuis le conteneur) : les règles serveur sont testées en SQL, l'interface avec des réponses simulées.
