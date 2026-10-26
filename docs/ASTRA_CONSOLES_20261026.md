# Noodeu — consoles et arbitrage, passe Astra 6 Ultra

Travail local commencé le 25 octobre et achevé le 26 octobre 2026 UTC, à partir
de `7d8a591a23f4b273e7e15936edf2041ddb781b1c`, sur
`codex/refonte-incrementale-20261025`. Les sous-agents de console, plateaux,
arbitrage et revue ont été créés avec `gpt-6-astra`, réflexion `ultra` ; ce réglage
a été accepté. Le dépôt existant, les commits précédents et les ressources ont
été conservés. Aucun push, merge distant, déploiement ou accès production.

Les visuels de cette passe doivent être validés par le propriétaire avant toute
publication. Les changements Admin de Claude restent à réconcilier avec le
dernier distant après cette validation. Ils ne sont pas présumés inclus ici.

## Exigences, constat et modifications

| Exigence | Existant constaté | Modification de cette passe | Vérification |
| --- | --- | --- | --- |
| Console de jeu, commandes stables | Enveloppe de page générale, cartes et commandes de hauteurs variables | Enveloppe de partie dédiée, titre/progression, régions de question et réponse, boutons Règles/Pause/Quitter, repli défilable | 18 familles, 4 largeurs ; question longue/clavier/200 % |
| Plein écran et Réduire | Retour à l'application déjà possible, session persistante | Chrome général absent pendant le jeu ; Réduire explicite et Reprendre sur Home | Aucun RPC de pause/abandon lors de Réduire ; même session à la reprise |
| Salon compact | Options issues du moteur, guides et avertissement +18 déjà présents | Espacement/typo, deux guides égaux, vraie commande Quitter ; description conservée avant réglages | Salon, guides, clavier et confirmation de sortie |
| Action ou Vérité distinct | Moteur à phases déjà présent | Deux choix illustrés, attente spécifique, carte Action/Vérité, réponse ou validation de l'action, passage | 7 groupes console : choix, action, vérité, attente, révélation, passage et états transversaux |
| Pièces 3D vives | Art de bibliothèque et gestes PFC déjà 3D ; plateaux disparates | 14 WebP originaux, plateaux clairs propres aux jeux ; aucune copie WePlay | Alpha et valeurs des six dés inspectés ; captures locales |
| Pendu, une chute par erreur | Compteur/lettres/fin déjà serveur | Six pétales séparés ; transition de révision confirmée seulement | Erreur, lettre refusée, rechargement, rattrapage, reduced-motion ; clip local |
| Morpion, PFC, dé, naval | Moteurs autoritaires et secrets filtrés | Ligne gagnante contrôlée, révélation commune PFC, face exacte du dé, impacts/coulés issus des tirs reçus | 13 groupes de transitions ; C14/C21/C29 SQL jetables |
| Petit bac rapide et explicable | Index de 866 entrées, inconnus à arbitrer, barème 5/10/15 | Nouvelle banque versionnée, normalisation Unicode et index GIN, raisons lisibles ; 8 champs en 2 colonnes | 941 alias ; parcours de gel/contestation/idempotence ; C28 et mesure locale |
| Réseau et expiration | Snapshot protégé contre certaines versions anciennes ; expiration tentée une fois | Époque de reprise transport, réponses anciennes écartées, retry borné puis manuel | API en panne alors que navigateur online, reprise, budget épuisé, aucun appel après succès |
| Discussion toujours accessible | Bulle sans dock, recherche parmi quatre positions | Recherche des espaces libres, protection champs/labels/textes/images ; place réservée dans le bord du toolbar si nécessaire | 8 tailles/zooms × 5 positions, clavier et priorité des modals |
| Fond léger animé | Bitmap original discret déjà présent | Déplacement lent de 3/2 px sur 24 s ; contenu immobile | CSS reduced-motion statique ; observation du rendu |
| Home et invariants antérieurs | Carrousel 3 s, question horaire serveur, partage final explicite | Conservés ; tests Home rendus portables par BASE | 14 contrôles autoplay, 11 contrôles heure/repli ; aucune migration Home modifiée |

Le plein écran est celui de l'application, pas une activation automatique du
plein écran Android/iOS. Réduire ne suspend ni les délais ni le tour serveur.
Quitter reste distinct et demande confirmation lorsqu'une session est active.

## Couverture par mécanique

`Rendu` signifie un état réel de composant alimenté par une fixture, pas une
partie jouée sur un compte réel. La matrice commune est : 320/360/390/430 × 780,
puis texte 200 % à 320/390. Le petit écran 390 × 560 a été contrôlé pour huit
familles représentatives. Les 18 lignes ci-dessous ne prétendent pas couvrir
chaque texte de chaque banque ni l'ensemble des anciennes activités retirées du
catalogue courant.

| Mécanique / exemple | États inspectés ou exercés dans cette passe | Niveau de contrôle et limite |
| --- | --- | --- |
| `pack_conversation` — Nos petits rituels | Question, attente, révélation, résultat | Rendu + régression résultats ; pas chaque pack |
| `test_form` — Cinq grands traits / Pureté | Réponse, fin et résultat Pureté | Rendu ; ordre/scoring et clic de partage conservés, pas nouveau test scientifique |
| `tic_tac_toe` — Morpion | Jeu, victoire, ligne invalide | Rendu + transitions + C14 |
| `dots_boxes` — Points et carrés | Plateau et jetons | Rendu + contrôles serveur C14 ; pas tous les plateaux possibles |
| `rps` — Pierre, feuille, ciseaux | Choix verrouillé, révélation, expiration, reprise | Rendu + transitions + retries + neuf combinaisons SQL |
| `nd_pig` — Dé chanceux | Face, total, conservation, répétition de même face, résultat | Rendu + transitions/rattrapage + 100 charges falsifiées SQL |
| `battleship` — Bataille navale | Placement, tirs, touché/coulé, victoire | Rendu + transitions + payloads invalides/confidentialité C29 |
| `nd_never` — Je n'ai jamais | Attente et révélation | Rendu de console ; parcours complet deux appareils non rejoué |
| `nd_dilemma` — Tu préfères | Salon, question, choix | Rendu, texte long et navigation ; pas toutes les cartes |
| `nd_duo_target` — Qui de nous deux ? | Révélation et actions | Rendu de console ; moteur conservé |
| `nd_predict` — Devine ma réponse | Verdict | Rendu de console ; moteur conservé |
| `nd_sentence` — Complète la phrase | Saisie | Rendu de console ; confidentialité conservée |
| `nd_opinion` — D'accord ou pas d'accord ? | Échelle/réponse | Rendu de console ; échelle conservée |
| `nd_truth_dare` — Action ou Vérité | Choix, attente, action, vérité, passage, révélation | Parcours simulé, nofuite DOM, double clic, offline, réduction/reprise |
| `nd_two_truths` — Deux vérités et un mensonge | Saisie simultanée | Rendu ; protocole simultané existant non réécrit, anciens tests restent distincts |
| `nd_hangman` — Pendu | Donneur/devineur, erreurs, fin, rattrapage | Rendu + transitions + bloc SQL Pendu |
| `nd_categories_stop` — Petit bac | Saisie, arrêt, arbitrage, résultat, erreur/réessai | Rendu + C28/C21 ; huit rubriques, inconnus non déclarés faux |
| `nd_name_three_call` — Cite trois | Appel et saisie | Rendu ; arbitrage existant conservé |

Portrait en cinq mots, quiz N2-005 et les anciennes mécaniques de mémoire
N2-052/N2-053 ont aussi été rejoués pour la navigation, la sortie, les erreurs,
le double clic et l'arrêt des sons. Ils ne sont pas présentés comme une refonte
complète de tous les anciens moteurs. Le chargement partagé et les états
pause/fin/abandon sont testés par la console ; une matrice exhaustive
« chaque activité × chaque erreur réseau × chaque appareil » n'a pas été exécutée.

## Défauts trouvés pendant la revue et corrigés

- Pétales invisibles à cause de `max-width:100%` dans un conteneur de largeur
  nulle : dimensions explicites, quatre pétales réellement visibles à deux erreurs.
- Révélation PFC rejouée au retour sur la partie : transition consommée une
  seule fois, montage et réduction/reprise sans animation de résultat ancien.
- Rattrapage API animé malgré le navigateur resté online : génération de
  transport et contexte de reprise ; ancienne réponse HTTP ignorée après coupure.
- Expiration PFC/Petit bac bloquée après échec : reprises à 1,5/3/6/12/20 s,
  au plus cinq reprises automatiques par cycle, espacées d'au moins 1 s,
  puis bouton manuel. Départ annulable en StrictMode et aucun appel après succès.
- Bouton Pause trop étroit à 320/360 : commandes d'au moins 44 × 44 px.
- Bulle de discussion sur un champ Petit bac : recherche élargie et rects
  coupés à la zone visible. Si aucune place libre ne reste, la barre de commandes
  réserve 84 px sur son bord droit. La bulle reste flottante, sans dock ni fond
  supplémentaire. Cette place est maintenue jusqu'au démontage pour éviter les
  déplacements pendant la saisie. Les éléments de la partie défilent normalement.
- Résultat final comprimé dans la grille de page : la surface a désormais sa
  hauteur de contenu, afin de rendre le score, les détails et Rejouer accessibles.
- Pack de questions : région de hauteur stable, défilable au clavier. Les
  commandes de questionnaire suivent les cinq items de leur page ; aucune
  réponse n'est masquée par une barre collante. Le titre de la console se
  réorganise à texte agrandi au lieu d'être réduit à une colonne trop étroite.
- Naval : orientation absente acceptée, tir sans coordonnées consommant un tour.
  La migration 008 refuse ces charges sans mutation. Elle ne répare pas
  automatiquement d'anciennes flottes malformées.

Les échecs initiaux sont consignés ici ; ils ne sont pas comptés comme des tests
réussis. La nouvelle exécution après chaque correction a été contrôlée.

## Validation et preuves

- `npm run lint`, `npm run typecheck`, `npm run build`, `npm test` : réussis,
  13 tests unitaires. La compilation conserve son avertissement de taille de
  chunk ; aucun découpage d'architecture n'a été entrepris dans ce lot.
- 72 rendus principaux, 36 rendus texte 200 %, 8 rendus de petite hauteur :
  pas de débordement horizontal, petite cible détectée ou erreur JavaScript.
  Les contrôles automatiques ne remplacent pas une certification d'accessibilité.
- 36 rendus supplémentaires à 768 et 1440 px : contrôles de débordement,
  cibles et erreurs JavaScript réussis.
- `console-flows.mjs` : 7 groupes réussis ; question longue défilable au clavier,
  position des réponses stable, passage, pause/fin/abandon, réduction/reprise.
- `session-layout-flows.mjs` : 6 scénarios supplémentaires (390/100 % et
  320/200 %) : résultat complet et Rejouer, pack long et payload privé,
  cinq items accessibles et pagination du questionnaire conservée.
- `astra-board-flows.mjs` : 13 groupes réussis ; états secrets et animations.
- `transport-recovery-flows.mjs` : 3 familles réussies (dé, naval, pendu).
- `astra-expiry-flows.mjs` : 4 scénarios réussis sur compilation : RPC en panne
  online=true, reprise au focus, budget épuisé, reprise manuelle et arrêt après succès.
- `astra-float-flows.mjs` : 40 positions contrôlées, dont 320 × 560 à 200 % et
  390 × 320 à 200 %. Contrôles/labels visibles dégagés et modals au premier plan.
  La revue indépendante couvre aussi 21 positions pour chacun de ces deux cas.
- Home : 14 contrôles autoplay, 11 contrôles heure/compteur et 15 positions de
  bulle avec 3 ouvertures de modal. Les fixtures ne prouvent pas un déploiement DB.
- SQL sur Docker PostgreSQL 16 uniquement : C28, C29, C14 mini-jeux et C21
  réussis sur deux bases locales, ainsi que le bloc Pendu du C14 lot4. Les scripts
  utilisent des transactions annulées. Voir les deux rapports d'arbitrage.
- Le benchmark Petit bac mesure uniquement PostgreSQL local : gel de seize
  réponses de 2,50 à 1,06 ms en moyenne ; ce n'est pas une latence de production.
- Bulle avec CPU Chromium simulé 6 fois plus lent : après réservation, recalcul
  moyen 0,96 ms, maximum 1,8 ms. La recherche/recomposition initiale atteint
  ponctuellement 65–78 ms ; ce coût initial reste une limite mesurée.
- Les planches et le clip sont des captures de l'application compilée, avec
  identités et réponses fictives. Les chiffres et statuts visibles sont des fixtures.

Les délais relatifs des fixtures sont recalés avant chaque capture : une longue
campagne de rendu ne doit pas transformer toutes les dernières vues en chronos
expirés. Les tests de réseau continuent à provoquer les vraies branches d'erreur
du client, par RPC simulée ou navigateur hors ligne.
La vieille fixture d'arbitrage Petit bac avait recopié « Canada/Chili » dans les
nouvelles rubriques. Ses seize exemples ont été reclassés par `pb_classify` dans
la base Docker : la capture ne présente plus un pays comme un métier valide.
L'objet « Clavier magique » illustre un mot inconnu à vérifier, sans faux rejet.

## Ressources et provenance

`public/assets/original/boards3d/PROVENANCE.json` décrit les 14 nouveaux WebP :
croix bleue, anneau orange réellement transparent, fleur sans pétales, pétale,
navire, éclair Action, cœur Vérité, jeton et les six faces de dé. Total :
217 036 octets. Ils proviennent de générations originales dans cet exécuteur,
avec recadrage et optimisation WebP ; pas d'actif de WePlay ni d'achat.
Les gestes PFC et l'art de bibliothèque déjà présents sont réutilisés, pas
déclarés comme de nouvelles créations de ce lot.

Les grilles, le trait de victoire, les surfaces, les ombres et les animations
sont du CSS/SVG. Ce ne sont pas des vidéos ni des objets 3D calculés en temps réel.
Les sources PNG originales restent dans le workspace et ne sont pas ajoutées
au petit ZIP de reprise ; le manifeste conserve leurs empreintes. Aucune
exclusivité juridique n'est affirmée pour les générations.

Le MP4 `noodeu-astra-fleur-demo.mp4` montre deux réponses simulées à travers le
vrai composant Pendu. Il est distinct de la vidéo de lancement Runway, toujours
absente. Il n'est pas chargé par l'application. Aucun crédit Runway consommé.

## Dépendances et limites de livraison

- Les migrations `20261030000700_petit_bac_normalization.sql` et
  `20261030000800_naval_payload_validation.sql` sont préparées et testées
  localement seulement. 007 dépend de l'état migré jusqu'à 006 ; 008 du moteur
  mini-jeux existant. Ne pas rejouer aveuglément l'historique SQL en production.
- Le frontend garde le repli sur les anciens verdicts Petit bac sans `reason`
  ou `index_version`. Sans 007, la nouvelle normalisation/index ne sont pas actifs.
- Les migrations notes/couverture, audio, tirage et question horaire des lots
  précédents restent non appliquées à distance par nous. Les modifications de
  RLS/Storage/cron et les dépendances Edge/worker exigent une revue spécifique.
- Audio : `answerAudio:false` conservé ; pas d'enregistrement opérationnel
  promis, pas de nettoyage 24 h en production revendiqué. Google non configuré.
- Tests standardisés, Aron (3 × 12), P20, scores et mentions de droits conservés.
  Aucun mot externe ajouté à l'index Petit bac. Les droits par entrée et les
  droits commerciaux C1/C2 demeurent à confirmer selon le registre existant.
- Non testé : vrais appareils Android/iOS, clavier système et lecteur d'écran
  matériels, synchronisation multi-appareils réelle, charge de production,
  déploiement réel, dernier onglet Admin de Claude, vidéo de lancement, audio réel.
- Le test complet C14 lot4 écrit pour quatre rubriques n'est pas déclaré passé
  sur le catalogue huit rubriques. Le bloc Pendu seul est indiqué comme exécuté.

Les sources principales sont `SessionScreen.tsx`, `ConversationGames.tsx`,
`MiniGames.tsx`, `WordGames.tsx`, `BoardPieces.tsx`, `useSession.ts`, `Chat.tsx`,
`astra-console.css`, `astra-boards.css` et le fond de `app.css`. Le manifeste
de passation fournit la liste exacte du diff et le SHA final du commit local.
