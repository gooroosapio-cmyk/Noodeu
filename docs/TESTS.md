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
(première page, page de l'item Rice 69, résultat partagé, fin) et le salon « À huis clos ». Écrans `60-*`.

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
