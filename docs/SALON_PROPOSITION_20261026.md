# Noodeu — proposition de salon du 26 octobre 2026

**Proposition locale non validée. Aucun push, fusion, déploiement, accès production ou migration appliquée.**

Branche : `codex/refonte-incrementale-20261025`. Départ de ce lot : `3c2ebd95a3ee243a4f76db1ae14a7f4e5d58b596`. Le SHA complémentaire exact est inscrit dans le README et le manifeste de la nouvelle passation. Deux relectures spécialisées ont utilisé Astra 6, réflexion ultra, pour les contrats du salon et la lecture des questions. Les travaux Admin de Claude restent à réconcilier après validation ; ils ne sont pas présumés inclus.

## Audit visuel et proposition

L'ancien salon empilait des éléments de poids similaire : titre répété, grandes zones de joueurs, illustration isolée, commandes et réglage à moitié largeur. L'objectif de Pig était enfoui dans le panneau Description. Le statut « Pas encore disponible » cassait sur plusieurs lignes. Ce manque de regroupement rendait la préparation peu lisible, même lorsque les fonctions existaient.

La proposition organise trois surfaces : identité illustrée et courte description ; joueurs et disponibilité ; réglages réellement pris en charge. Le bouton principal conclut ce parcours. Description et Règles ont des dimensions égales. Les portraits sont équilibrés sans emblème central. Le partenaire prêt reçoit une bordure et un statut textuel, et le CTA devient « Lancer la partie » sans changer de RPC. Les transitions de sélection/disponibilité durent 160–180 ms ; le mouvement réduit les désactive. Les illustrations 3D originales existantes sont réutilisées : aucun nouvel asset ni aucune banque ajoutés.

« Réduire » est cerise, distinct de « Quitter ». Blanc sur `#B72132` : contraste sRGB calculé **6,41:1**. La réduction revient à l'application sans abandonner la session. Quitter conserve sa confirmation. Le chat reste flottant et disparaît derrière une vraie modal.

## Matrice exigences, modifications et vérification

| Exigence | Modification locale | Vérification |
| --- | --- | --- |
| Salon dynamique, compact | Trois groupes, illustration intégrée, titre non répété, cartes de joueurs, CTA hiérarchisé | Captures avant/après et variantes 320/360/390/430/768/1440 |
| Options réelles | Radios typées depuis `game.config.settings`, sélection confirmée par snapshot ; select conservé si plus de quatre valeurs ; anciennes Options préservées | Huit familles de salon, refus RPC, clavier, valeurs numériques et texte, invalidation des disponibilités |
| Pig et Naval | Résumé visible des règles effectives ; aucune option inventée | Pig 30, Naval 10×10 / cinq navires / un tir |
| Aléatoire | 5/10/20 sur une ligne ; +18 court inchangé ; pas de nouveau moteur | Le réglage 5 prime sur l'ancien total technique 20 du snapshot de salon |
| Réduire rouge et sûr | Garde de départ avant mutation différée | Réduire pendant préparation : zéro `set_ready` tardif ; Quitter confirmé résiste au double clic |
| Questions complètes | `ReadingRegion`, texte complet des dilemmes au lieu du prompt abrégé, zone de lecture clavier et indice hors du texte | Questions très longues, début/fin accessibles, aucun clamp/ellipsis, CTA stable |
| Réponses lisibles | 14–15 px selon format, retours à la ligne conservés, choix longs défilables ; questions 18 px, saisies ≥16 px | Texte 200 %, dernière option atteignable, réponses révélées et trois formats de saisie |
| Chat sans déplacement dû au texte invisible | Collision calculée après découpe par tous les ancêtres à débordement, cache par frame | Texte court/long : formulaire stable ; huit profils de chat et modals |

## Contrats préservés

- Tu préfères : 10/20/30 cartes. Petit bac : 3/5/7 manches et 120/180 secondes. Pendu : 4/6/10 et difficulté. Morpion : 1/2/3 victoires. PFC : deux victoires, 30 secondes pour choisir. Aucun barème changé.
- `set_ready`, `update_session_settings`, `abandon_session` et anciens réglages passent par les fonctions existantes. Les mutations ne sont pas optimistes. Hors ligne, lecture seule, siège absent ou préparation en cours verrouillent les commandes correspondantes.
- Une préparation asynchrone n'envoie plus de disponibilité après réduction ou changement de route, même avant le démontage React. Une mutation déjà reçue par le serveur avant navigation n'est pas prétendue annulable.
- Réponses privées, payloads, révélations, score, ordre, pagination, tests standardisés, Aron et P20 inchangés. Aucune modification SQL ou politique de sécurité dans ce lot.
- Home, bibliothèque, couverture, notes, banques et moteurs ne sont pas refaits. Audio reste désactivé, Google non configuré, film Runway toujours absent. Le repli du hook média est testé ; aucune lecture réelle de vidéo n'est revendiquée.

## Tests et limites

Les scripts utilisent uniquement des fixtures locales et des RPC simulés. Ils ne constituent pas un test de synchronisation de deux téléphones ni une preuve des droits sur la base réelle.

- Lint, TypeScript, build et 13 tests unitaires : réussis.
- `salon-proposal-flows.mjs` : 11 groupes / 25 contextes réussis. Huit salons, deux panneaux, valeurs typées, refus, double clic, disponibilité, reprise, offline/lecture seule/siège absent, Quitter, ancien moteur, absence de film, temporisation et départ pendant préparation.
- `question-reading-flows.mjs` : 15 scénarios. Questions et options très longues, texte 200 %, clavier, formulaire stable, réponses révélées complètes, audio inactif sans micro ni appel média.
- `session-layout-flows.mjs` : six scénarios de pack, résultats et questionnaire. `console-flows.mjs` : sept groupes de console, Action/Vérité, réduction/reprise et états de fin.
- `astra-float-flows.mjs` : huit profils × cinq positions de défilement, dont 320×560 et 390×320 à 200 %, sans recouvrement de champs/labels/boutons ; modal prioritaire.
- Géométrie : 40 vues de salons à 320/360/390/430/768/1440, hauteur normale et 320×560, puis 320/390/430 à 200 %. Pas de débordement horizontal ou erreur JavaScript ; cibles contrôlées ≥44 px. Les captures simples de livraison utilisent 390×780.
- Pixels inspectés : ancien salon et Pig, nouveaux salons questions/Petit bac/Pig/aléatoire, planche avant/après, question longue au début et à la fin, petit écran et texte 200 %. Le reste de la matrice est contrôlé automatiquement, sans revendiquer une revue humaine de chaque capture.

Défauts rencontrés puis corrigés : chat déplacé par du texte hors de sa zone visible ; disponibilité envoyée après Réduire ; zone de question augmentée trop largement qui déplaçait le formulaire du pack. La hauteur accrue est limitée aux consoles de conversation ; les packs conservent leur hauteur stable. Les attentes de tests sur les requêtes HEAD ont été corrigées pour distinguer le double effet React StrictMode d'une double mutation : `set_ready` reste limité à un appel.

Le build émet toujours l'avertissement de bundle JavaScript >500 kB (environ 1,03 Mo brut / 284 ko gzip). Aucun découpage de l'application entrepris dans cette révision ciblée. Pas de mesure de performance sur téléphone physique, de clavier iOS/Android réel, de lecteur d'écran, de synchronisation DB ou de tests SQL relancés dans ce lot. Le clavier Playwright, les petites hauteurs et le reflow sont couverts. Les questions longues nécessitent un défilement explicite ; elles ne sont pas rendues minuscules pour tout afficher simultanément. À 200 % et sur petits écrans, le salon défile également.

## Fichiers et livraison

Sources : `SessionScreen.tsx`, `ReadingRegion.tsx`, `ConversationGames.tsx`, `QuestionnaireGames.tsx`, `Chat.tsx`, `salon-proposal.css`, `question-reading.css`. Tests : nouveaux `salon-proposal-flows.mjs`, `question-reading-flows.mjs`, `salon-captures.mjs` ; sélecteurs de lecture ajustés dans `console-flows.mjs` et `session-layout-flows.mjs`.

La passation contient le bundle incrémental exact depuis `49d3c1e35052ce06fcca0a61ae465d65ae7b8b92`, les rapports, commandes d'import sans écrasement, captures JPEG et résultats. Les WebP de production restent dans l'historique Git. Aucun secret, donnée réelle, URL signée, cache, node_modules ou master PNG lourd. Les anciennes passations restent conservées. Une validation de cette proposition est requise avant toute réconciliation et publication.
