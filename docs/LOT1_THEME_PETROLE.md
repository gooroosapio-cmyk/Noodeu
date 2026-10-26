# Lot 1 — ivoire, pétrole, abricot

## Changements demandés
Accueil : deux avatars réels/initiales centrés, suppression de l'image décorative, deux boutons alignés de mêmes dimensions. Espace : couverture avec avatars superposés, retrait des commandes jeu/discussion redondantes ; discussion flottante conservée. Invitation : fenêtre centrée au premier plan, Accepter/Refuser égaux, focus contenu, Échap/retour, aucune navigation avant acceptation.

Système : ivoire #FAF7F0, texte #233B40, action #17656B, pressé #104E54, sélection #D7ECE9, accents abricot. Contrastes détaillés dans CONTRASTES_PETROLE.md. Initiales et icônes de boutons pleins blanches. CTA de jeu cohérents. 84 SVG du kit existant recolorés sans changement de forme ; provenance tierce inchangée, aucune nouvelle licence supposée.

Bibliothèque : 45 activités actives inventoriées (16 jeux, 7 tests, 20 packs, 2 modes aléatoires), un dessin SVG original distinct chacune ; 3 catégories, plus le portrait historique G06. Les 49 dessins sont reproductibles par scripts/create_library_art.py. Aucun manque d'asset dans cet inventaire. Deux grandes catégories puis grille à deux colonnes conservées. Logo existant recoloré, pas une nouvelle marque originale.

Quitter : commande en haut des salons et parties ; confirmation adaptée au salon ou à la partie active, annulation sans mutation, erreur visible dans le dialogue, confirmation bloquée hors ligne, verrou double clic. Fin/archives : retour sans abandon des résultats. Appels serveur inchangés.

## Seconde passe par états
Revue des routes listées dans INVENTAIRE_VISUEL_PETROLE.md et inspection de planches de 49 états (45 actuels + 4 historiques). Vérification des états salon, saisie, attente, révélation, pause, fin ; aucune modification des règles. Les grands décors restent retirés ; les surfaces de saisie sont unies. Entrées/révélations existantes conservées et nouvel effet d'apparition de l'invitation, feedback pressé des cartes ; reduced-motion système et application respectés.

Les plateaux denses commencent en mode tactile >=44 px avec défilement interne ; vue compacte non interactive. Les petites cibles historiques hors catalogue courant restent un point de vigilance, pas une certification universelle. Le perfectionnement approfondi mini-jeux et salon/vidéo fait l'objet des lots suivants.

## Validation réelle
- Lint, types, build, 13 tests Node réussis.
- 337 scénarios à 320 et 390 px : 674 rendus sans débordement horizontal, erreur JS ou contenu sous navigation. Balayage réalisé avant les dernières retouches d'assets/zoom ; celles-ci revérifiées par captures ciblées finales.
- 32 rendus ciblés à 360/430/768/1440 ; 20 rendus à texte200% 320/390 ; 4 supplémentaires sur plateaux denses à texte200% : réussis.
- 14 parcours existants + 5 nouveaux : home géométrie/avatars, espace sans CTA redondants, invitation centrée/focus/retour/reduced-motion, quitter salon/jeu/pause avec annulation, hors ligne, erreur et double clic.
- 13 captures finales 390×844 ; pixels inspectés sur accueil/bibliothèque/espace/invitation/jeux. Trois fixtures Pureté historiques incohérentes ont été régénérées depuis le vrai serveur PostgreSQL local (72 items, résultat69/100 pour50 Non), transaction annulée.
- Les tests backend déjà exécutés au lot précédent restent valables : aucune migration de ce lot. Pas de nouveau test réseau Supabase réel, mobile physique, clavier virtuel réel ni lecteur d'écran.

Les bannières Reconnexion des captures proviennent des fixtures sans Realtime ; la nouvelle demande spécifique chargement/reconnexion est réservée au lot3. Les nouvelles captures ne sont pas une copie du fichier Library dont le parent a reçu un refus de scope.

## Suite autorisée
Lot2 : revue et perfectionnement des mini-jeux, captures dédiées. Lot3 : salon compact avec configurations réellement supportées, avatars/statuts, vraie vidéo<=3s avant confirmation prêt, pas de chrono consommé, chargements/reconnexion sobres. Aucun push, merge, production ni activation audio. Distant observé48ec7b4, réconciliation toujours en attente de fin du travail Claude.
