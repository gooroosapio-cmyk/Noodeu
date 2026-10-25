# Tests

## 1. Tests de la base (sécurité, partie complète, doublons)

Fichier : `supabase/tests/slice1_security_and_game.sql`. Il crée quatre comptes fictifs (A et B en couple, C extérieur,
D pour les tentatives), joue deux parties complètes puis **annule tout** (transaction `rollback`).

Ce qui est vérifié :

- invitation : code répété identique, code invalide, propre invitation, invitation déjà prise, expirée,
  blocage après essais répétés, double confirmation, acceptation répétée sans doublon ;
- un compte extérieur ne voit ni le couple, ni les profils, ni les invitations, ni la partie, ni le salon,
  ne peut pas agir sur la partie ni écouter ses canaux temps réel ;
- double lancement = une seule partie ; confirmation de disponibilité répétée = une seule manche ;
- réponses : ordre des étapes, nombre de mots exact, envoi répété idempotent, pas de seconde réponse ;
- **confidentialité avant révélation** : le partenaire ne lit aucune réponse, ni par la table, ni par l'API,
  ni par les signaux temps réel ; il sait seulement que l'autre a répondu ;
- pause (réponses refusées), passer une étape, révélation, fin ;
- salon : message répété enregistré une fois, effacé à la clôture ;
- souvenir gardé seulement avec l'accord des deux ; séparation : historique en lecture seule, plus de nouvelle partie.

Exécution locale (PostgreSQL 16+) :

```bash
createdb noodeu_test
psql -d noodeu_test -f supabase/tests/local_shim.sql   # imite auth / realtime de Supabase
for f in supabase/migrations/*.sql; do psql -d noodeu_test -v ON_ERROR_STOP=1 -f "$f"; done
psql -d noodeu_test -v ON_ERROR_STOP=1 -f supabase/tests/slice1_security_and_game.sql
```

Sur le projet Supabase : coller le fichier dans l'éditeur SQL. Le résultat attendu est « TOUS LES TESTS SONT PASSÉS ».

## 2. Tests unitaires

`npm test` : accord des mots, sélection limitée, mots retrouvés, étape passée, étape suivante.

## 3. Vérification visuelle

`npm run build && npx vite preview --port 4173` puis `node tests/visual/render-check.mjs`.
23 écrans (sans duo, invitation en attente, demande reçue, duo actif, archive, zéro résultat, filtres, chat,
notifications, jeu…) à 320, 360, 390, 430, 768, 1440 px et 390×560 ; `ZOOM=2` pour le texte à 200 %.
Contrôles : défilement horizontal, contenu masqué sous la navigation, erreurs JavaScript, cibles tactiles < 44 px.
⚠️ Ce script simule les réponses du serveur pour afficher les écrans : il ne teste **pas** la synchronisation.

Catalogue actuel (catégories 1 à 4) : `tests/visual/fixtures/catalogue.json` est extrait de la base locale, et
`python3 tests/visual/make_fixtures_c14.py` produit des états **réels** (fonctions de la base, transaction annulée)
pour les packs (vrai/faux, attente, révélation avec partage et réponse gardée, fin de séance), les questionnaires
(première page, page de l'item Rice 69, résultat partagé, fin), le salon « À huis clos » et les mini-jeux du lot 2
(morpion en cours et fini, points et carrés, pierre-feuille-ciseaux verrouillé puis révélé, dé, placement et tirs
de bataille navale). Écrans `60-*`.

Tests SQL du lot 2 : `supabase/tests/c14_minijeux.sql` (cas d'acceptation du kit : victoires et nulles, neuvième case,
case occupée, double capture, matrice des neuf gestes, échéance sans divulgation, dé à 1, victoire à 98 + 5,
chevauchement, contact autorisé, tir répété, aucune coordonnée adverse transmise, idempotence, robot jusqu'au bout).

## 4. Recette manuelle à deux téléphones (à faire après mise en ligne)

1. Créer deux comptes (A et B), confirmer les e-mails.
2. A : Accueil → « Inviter » → partager le code. B : « J'ai un code » → vérifier → rejoindre. A : « Confirmer mon duo ».
3. A : Bibliothèques → Portrait en cinq mots → « Préparer la partie ». B : l'accueil affiche « Rejoindre le salon ».
4. Les deux : « Je suis disponible » → la partie démarre chez les deux.
5. A choisit ses 5 mots puis imagine ceux de B. **Vérifier que B ne voit rien des choix de A.**
6. B ferme l'application en plein milieu, la rouvre : sa sélection en cours et l'état de la partie sont retrouvés.
7. B termine : la découverte s'affiche chez les deux.
8. Ouvrir la discussion (bulle) depuis les deux téléphones, écrire, réduire, rouvrir (le brouillon est conservé),
   couper le réseau d'un téléphone, envoyer (« Non envoyé »), le rétablir, « Réessayer » (pas de doublon).
9. Un troisième compte C qui ouvre l'adresse de la partie doit voir « partie introuvable ».
10. Cloche : la demande de partie et les messages apparaissent ; « Tout marquer comme lu ».
11. Espace → Gérer le duo → Terminer ce duo : l'autre est prévenu, l'historique reste consultable ;
    inviter un troisième compte C : C ne voit rien de l'ancien duo.
12. Réglages → Mon profil : ajouter une photo, recadrer, enregistrer ; elle apparaît chez l'autre membre.

## Édition 2.1.0 — famille 1 (22 octobre 2026)

- `supabase/tests/slice2_family1_engines.sql` : catalogue (144 activités, 18 jouables, 8 familles), activité « Bientôt »
  non lançable, tables de cartes et banques illisibles en direct, préférences privées (+18 refusé sans l'accord des
  Réglages, thèmes exclus réunis et jamais tirés, préférences de l'autre illisibles), réponses cachées avant révélation,
  réponse renvoyée sans effet, réponse modifiée refusée, double clic sur « carte suivante », pas de carte répétée, sortie
  commune sans dévoiler la carte en cours, retrait immédiat d'une carte +18 non révélée, rôles alternés et score sur
  cartes ordinaires, relance unique, ordre et visibilité immédiate (écoute), capsule (date, champ non partagé jamais
  montré), budget et révision unique, moitié de scène, dessin hors cadre refusé, compte extérieur, effacement à 24 h.
- `tests/visual/make_fixtures.py` : joue les 18 activités sur la base locale avec les vraies fonctions (tirage,
  validation, révélation) pour deux comptes fictifs, et enregistre les états obtenus.
- `tests/visual/render-check.mjs` : bibliothèque 144, fiches (jouable et « Bientôt »), salon avec options, et pour
  chaque activité l'écran de jeu et la révélation, de 320 à 1440 px, écran bas et texte à 200 %. L'écran d'erreur du
  routeur est détecté comme une erreur.
- `src/game/rounds/logic.test.ts` : tour de chacun, attente, révision, libellés accordés, budget.

Non testé à ce stade : partie réelle entre deux appareils distincts en ligne, réseau lent, lecteur d'écran réel.

## Partenaire automatique de test (22 octobre 2026)

- `supabase/tests/slice3_test_autoplayer.sql` : sans inscription rien ne se passe ; avec inscription, le partenaire est
  prêt dès la création, l'identité du joueur est rendue après chaque action du robot, et les 18 activités se jouent
  jusqu'à la fin (révélation, étapes après révélation, capsule fermée) avec un seul joueur humain.

## Famille 2 — Mots et répartie (22 octobre 2026)

- `supabase/tests/slice4_family2_board.sql` : moteur plateau. Le mot à deviner n'apparaît jamais dans l'état public ;
  l'autre joueur ne voit ni la part privée ni la solution avant la fin de la manche ; lecture directe des secrets
  refusée ; coup hors tour refusé ; mot interdit (même au pluriel) et mot cible refusés dans un indice ; un coup
  refusé ne change rien ; même coup envoyé deux fois = un seul effet ; manche périmée et manche finie refusées ;
  rôles inversés ; anagrammes (lettres et longueur contrôlées) ; lettre déjà essayée sans erreur ; indice tiré du
  plateau refusé ; grille du bac invisible pour l'autre avant confirmation ; puis les 18 activités jouées jusqu'au
  bout (un joueur + le partenaire automatique), avec résultat et toutes les manches terminées.
- `tests/visual/make_fixtures_board.py` + `render-check.mjs` (écrans 53-) : pour chaque activité, début de manche,
  après un coup, manche finie et partie finie, à partir d'états réels, de 320 à 1440 px.

## Famille 4 — Mémoire et observation (22 octobre 2026)

- `supabase/tests/slice6_family4_memory.sql` : faces des paires inconnues avant retournement, paire ratée visible
  1,2 s (champ « miss ») sans troisième retournement ; objets à mémoriser absents de l'état public, visibles du seul
  joueur pendant l'observation puis retirés ; réponse impossible avant la fin de l'observation ; nombre d'objets
  imposé ; réponse de l'un cachée à l'autre ; score calculé sur le serveur ; chaque joueur ne voit que sa moitié du
  plateau (deux mémoires) ; une seule aide ; suite lumineuse arrêtée après deux erreurs ; curseur hors de 0..100
  refusé ; puis les 18 activités jouées jusqu'au bout avec le partenaire de test.
- `tests/visual/make_fixtures_board.py 4` + `render-check.mjs` (écrans 53-) aux largeurs 320 et 390 px.
- Correctifs trouvés par ces captures : numéros des disques superposés tracés au-dessus de tout, du côté visible ;
  comparaison des motifs du « pixel retenu » en grille adaptable (débordement à 390 px).

## Famille 3 — Dessin et création (22 octobre 2026)

- `supabase/tests/slice5_family3_creation.sql` : objet à dessiner invisible pour l'autre et absent de l'état public ;
  pas de proposition sans dessin ; trait hors cadre refusé ; budget de dix traits (la gomme coûte un trait) ;
  miroir limité à la moitié gauche ; maison sans chemin et tuile isolée refusées ; tangram contrôlé par surfaces
  (carré reformé = réussite, pièce déplacée = plus résolu), retournement réservé au parallélogramme, sortie du
  plateau refusée ; portrait en gommettes et bande du personnage plié invisibles pour l'autre avant la fin ;
  modèle du dessin dicté réservé au guide ; puis les 18 activités jouées jusqu'au bout avec le partenaire de test.
- `tests/visual/make_fixtures_board.py 3` + `render-check.mjs` (écrans 53-) : début, après un coup, manche finie,
  partie finie pour les 18 activités ; écran 54- : l'export « Enregistrer en image » produit un vrai fichier PNG.
- Correctif trouvé par ces captures : Chrome n'affichait pas les images d'éléments placées dans un dessin dont
  l'unité est minuscule ; elles sont désormais tracées dans un repère de 100 unités mis à l'échelle.
- Limite connue : sur un écran de 320 px, les cases de la mosaïque 8 × 8 font environ 34 px (au-dessus du minimum
  WCAG de 24 px, sous la cible confortable de 44 px).

Tests SQL du lot 3 : `supabase/tests/c14_conversation.sql` (sans remise, aucune carte +18 sans les deux accords,
réponse scellée invisible pour l'autre, passage sans divulgation, Continuer des deux, retrait +18 avec purge,
cible limitée au duo, verdict du sujet et correction par différence, Action ou Vérité, Deux vérités et un mensonge,
partenaire automatique jusqu'à la fin de chaque jeu). Écrans `60-conv-*` pour la recette visuelle.

Tests SQL du lot 4 : `supabase/tests/c14_lot4.sql` (Pendu : rôles, accents « école », lettre répétée, six erreurs, mot banni ;
Petit bac : lettre retenue, révisions, Stop après 10 s et quatre cases, index par catégorie, arbitrage privé, barème 5/10/15,
échéances 120 s et 60 s ; Cite trois : deux chargements, appel confirmé, consigne retenue, accusés à 750 ms, juge seul,
correction à deux accords appliquée une fois, passage, fin à 30 confirmée par les deux, retrait +18 ; partenaire automatique).
Écrans `60-mot-*` pour la recette visuelle (échéances recalées à l'heure du rendu).

Tests SQL des parcours : `supabase/tests/c15_parcours.sql` (classement des 1001 questions ; majorité obligatoire pour le +18 ;
plafond commun appliqué au tirage et à la création de partie ; retrait du +18 ; pause à double reprise et décalage des
échéances ; Arrêter ; Plus tard, favoris et avis invisibles du partenaire et sans notification ; question du jour partagée,
fuseau, thème, sans répétition, solo ; progression : passée différente de répondue, aucune réponse renvoyée ; défi léger ;
rappels sans contenu, plafond et espacement ; réglages personnels illisibles et non modifiables par le partenaire).
Recette visuelle : écrans `07c-filtres`, `20-pause-reprise`, `22c-majorite-18`, `22d-rappels`, question du jour sur
`06*-accueil`, progression et « Mes questions » sur `21a-espace-duo`.

Catalogue final : `supabase/tests/c16_catalogue_final.sql` (anciennes questions absentes, 805 + 120 entrées, rubriques,
chaque activité a sa banque, aucun classement orphelin ; cartes +18 d'un pack sautées sans accord et ordre conservé ;
questionnaire aléatoire : nombre choisi, rubrique, +18 et plafond respectés, même liste d'une carte à l'autre, aucune
progression, « Plus tard » ; idées de Deux vérités jamais +18 sans accord). Tests c14 et c15 mis à jour (effectifs du
catalogue final, test de pureté sans score). Recette visuelle : `08a-packs-c01` (rubrique fusionnée et questionnaire
aléatoire), `07-bibliotheques` (À huis clos en deuxième), `32-fermer-partie-ouverte`.

Duos multiples : `supabase/tests/c17_multi_duos.sql` (deux duos actifs pour A, B non prévenu ; pas de doublon de paire ;
une partie ouverte dans chaque duo, bascule sans perte ; non-lus des autres duos ; B ne voit ni le duo, ni les parties,
ni les membres, ni le profil de C (tables et fonctions), C non plus pour A-B ; C ne peut pas terminer A-B ; fin de duo sans
notification, retour automatique sur l'autre duo, historique en lecture seule). Recette visuelle : `06f`, `06g`, `21d`.

Questions +18 sans permission : `supabase/tests/c18_sans_permission_adulte.sql` (nouveau profil +18 actif sans plafond ;
avec d'anciens réglages restrictifs, pack avec cartes +18 complet, activité À huis clos et activité « hot » lancées sans
accord ; cartes +18 tirées dans un jeu de conversation ; plus aucune règle sur l'activation du +18 ; filtres sans plafond).
`scripts/run_sql_tests.sh` lance c14 à c17 avant cette migration, puis c18. Recette visuelle : `11-salon`,
`60-salon-huis-clos` (message dans le salon), `22-parametres` (plus d'interrupteur +18 ni d'intensité).

Jeux premium : `c19_g08_simultane.sql` (écriture et devinette simultanées, aucun texte ni mensonge de l'autre avant
l'heure, reprise des affirmations, relance avec ses limites, plus de notification de message), `c20_purete.sql` (indice
sur 100, « Non » sur 72, réponses partagées par défaut et retrait possible), `c21_de30_petitbac8.sql` (victoire à 30 par
conservation, 8 rubriques classées, minuterie 120/180 s, lettres couvertes par l'index). Recette visuelle :
`60-conv-dvm2-*`, `60-test-rice2-*`, `60-mini-*`, `60-mot-*`, `60-conv-*` (scènes J4). `c22_jamais_libelles.sql` : libellés exacts de Je n'ai jamais. `FULL=1` capture la page entière.
