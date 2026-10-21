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
10. Cloche : la demande de partie et les messages apparaissent ; « Tout marquer comme lu ».
11. Notre espace → Gérer le duo → Terminer ce duo : l'autre est prévenu, l'historique reste consultable ;
    inviter un troisième compte C : C ne voit rien de l'ancien duo.
12. Paramètres → Mon profil : ajouter une photo, recadrer, enregistrer ; elle apparaît chez l'autre membre.
9. Un troisième compte C qui ouvre l'adresse de la partie doit voir « partie introuvable ».
