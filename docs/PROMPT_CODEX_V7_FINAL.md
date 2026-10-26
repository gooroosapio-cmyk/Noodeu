# Prompt Codex : V7 finale (comptes réels, mot de passe) — vérifications, finitions et mise en ligne

Ce prompt remplace les précédents (`PROMPT_CODEX_DEPLOIEMENT_V7.md`, `PROMPT_CODEX_MISE_A_JOUR_COMPTES.md`).

Tu reprends le projet Noodeu, une PWA en React, TypeScript et Vite, dans le dépôt `gooroosapio-cmyk/Noodeu`. Réponds en français. Travaille par étapes, et fais un audit complet avant toute action.

## 1. Situation de départ

- **Production actuelle** : `0ee5ebf`, ta livraison V7 avec ses finitions. C'est le point de retour arrière : note l'identifiant de ce déploiement Vercel avant toute chose.
- **À livrer** : la branche `v7/interface-20261026`, à son dernier commit (`d843517` au moment de la rédaction ; vérifie avec `git log`). Elle ajoute à `0ee5ebf` :
  - `734d3ce`, comptes réels :
    - inscription sans confirmation par e-mail ;
    - « mot de passe oublié » remplacé par un contact ;
    - test d'isolation `c43` ;
    - migration 1500.
  - `e28b2db` : fusion sans conflit de ton commit `0ee5ebf`.
  - `0922497` : première version de « Changer mon mot de passe ». Tu l'as auditée et refusée à juste titre.
  - `3e9beec`, correctif de ton audit :
    - fonction serveur unique `change_password`, sans reconnexion côté navigateur ;
    - feuille fermée et réponse ignorée si le compte change ;
    - panne réseau distincte d'un mauvais mot de passe ;
    - contact configurable par `VITE_SUPPORT_EMAIL` ;
    - tests `c44` (SQL) et `tests/visual/password-flows.mjs` (6 scénarios).
  - `d843517` : documentation.
- **Base de données** : tout est déjà en ligne. Claude a appliqué les migrations 1500 (index d'accès), 0100 (couverture et notes du duo) et 1600 (`change_password`) après accord écrit du propriétaire, puis les a vérifiées. **Tu n'appliques aucune migration.**
- **Documents à lire en entier avant de commencer** :
  - `docs/V7_INTERFACE_20261026.md` ;
  - `docs/AUDIT_SECURITE_COMPTES_20261026.md` ;
  - ton propre `docs/V7_AUDIT_FINITION_20261026.md`.
- **Supabase** : projet `uqyrjdaonqqkkpzyjfcg`. Ne touche jamais au projet « Limpid ».
- **Vercel** : projet `prj_pILsfC2SFwCQjQLyhPrROCKoVSrC` (noodeu.vercel.app), équipe `team_vwilsshWZZiqYc5vQLN8f3zj`.
- **Compte de test** : Kalou (`dkalou151@gmail.com`) est un joueur automatique, toujours prêt, aux réponses aléatoires.

## 2. Règles impératives

- **Secrets et privilèges**
  - Aucun secret dans le navigateur, sur GitHub ou dans les journaux.
  - Ne demande jamais de token ni de mot de passe dans le chat.
  - Les opérations privilégiées restent côté serveur.
- **Production**
  - Aucune migration, aucune modification de données de production.
  - Ne rejoue aucune purge ni aucun script de tests en production.
  - N'active aucun paiement, abonnement, fournisseur d'IA ni service payant.
  - Garde désactivées les fonctions dont le service n'est pas prêt : audio, connexion Google.
- **Données intimes**
  - Ne journalise pas les réponses intimes.
  - Ne mets aucune donnée sensible en cache hors ligne.
  - Conserve les brouillons G08 en `sessionStorage` : restaurés au rechargement, purgés sur « Passer », en fin de manche et au changement de compte.
- **Interface**
  - Garde le logo intact et ne fabrique aucun original de marque.
  - Les PNG témoins restent des références, jamais des fonds cliquables.
  - N'invente ni score, ni statut de synchronisation, ni audio.
- **Git**
  - Pas de force-push, de rebase ni de réécriture d'historique.
  - Si la branche distante a bougé, fusionne-la (commit de fusion).
- **Droits** : conserve les notices et n'invente aucune autorisation d'un éditeur tiers.
- **Preuves** : ne prétends jamais avoir testé ou consulté quelque chose sans preuve. Joins les sorties de commande et dis clairement ce qui n'a pas pu être vérifié.

## 3. Étape 1 : audit (aucune modification)

1. Lance `git fetch`, puis `git log --oneline 0ee5ebf..origin/v7/interface-20261026`, et lis tout le diff de `src/`, `supabase/`, `tests/`, `vercel.json` et `vite.config.ts`.
2. Sous `supabase/`, seuls ces fichiers sont attendus :
   - les migrations 1500 et 1600 ;
   - les tests `c43` et `c44` ;
   - la simulation `tests/local_shim.sql`.

   Ce sont des fichiers, pas des actions à exécuter.
3. Vérifie en lecture seule (base de production) :
   - `select to_regprocedure('public.change_password(text,text)'), to_regprocedure('public.get_duo_space(uuid)');` doit renvoyer deux valeurs non nulles ;
   - l'index `couple_members_user` doit exister.
4. Fais un rapport court : ce qui change, les risques, ce que tu proposes de peaufiner.

## 4. Étape 2 : vérifications locales

- `npm ci`, `npm run lint`, `npm run typecheck`, `npm test` (21 tests attendus), `npm run build`.
- Lance `npx vite preview --port 4173 --strictPort`, puis les parcours ci-dessous, sur réponses simulées uniquement :
  - `tests/visual/password-flows.mjs` (6) ;
  - `v7-flows.mjs` (9) ;
  - `lobby-ready-lifecycle.mjs` (5) ;
  - `red-games-flows.mjs` (10) ;
  - `red-keyboard-check.mjs` (6) ;
  - `session-context-flows.mjs` (9) ;
  - `catalog-cache-flows.mjs` (9) ;
  - `chat-privacy-flows.mjs` (9) ;
  - `vault-pagination-flows.mjs` ;
  - `v7-chat-layout.mjs` ;
  - `v7-reduced-motion.mjs`.

  Certains scripts attendent Chromium dans `/usr/bin/chromium` : adapte le chemin sans modifier le dépôt.
- Recette visuelle : `WIDTHS=360,390,412 HEIGHT=844 node tests/visual/render-check.mjs <dossier>`. Attendu : aucun débordement, aucun contenu masqué, aucune erreur JavaScript. Ne reconstruis pas pendant une recette en cours.
- Si PostgreSQL est disponible localement, lance `c43` et `c44` sur une base jetable, jamais sur Supabase.

## 5. Étape 3 : finitions front (petites et vérifiées)

Ne corrige que des détails visuels, de libellé ou de robustesse. Aucune nouvelle fonctionnalité, aucun changement serveur. Un commit par correction, puis relance les tests concernés.

Points à contrôler :

1. **Connexion et inscription**
   - l'inscription mène directement à l'accueil ;
   - le message « Mot de passe oublié ? Écris-nous depuis l'adresse de ton compte… » s'affiche avec le lien e-mail ;
   - aucun bouton d'envoi d'e-mail ;
   - la mention « Connexion Google bientôt disponible » reste désactivée.
2. **Réglages → Changer mon mot de passe**
   - libellés et messages d'erreur clairs ;
   - cibles tactiles d'au moins 44 px ;
   - la feuille reste lisible avec le clavier ouvert et le texte à 200 %.
3. **Espace**
   - couverture : changement de photo, et retour visuel pendant l'envoi ;
   - « Nos notes » : ajouter, cocher.

   Ces deux fonctions ne doivent plus jamais afficher « pas disponible ».
4. **Témoins V7** (accueil, espace, coffre, historique, conversation plein écran) : fidélité, bouton de conversation fixe, zones de sécurité, mouvement réduit.

## 6. Étape 4 : configuration et déploiement de test (preview)

1. **Variable Vercel.** Ajoute `VITE_SUPPORT_EMAIL=gooroosapio@gmail.com` (texte simple) pour Production et Preview, avant le build. C'est l'adresse de contact publique choisie par le propriétaire, pas un secret. Ne la mets pas dans le code.
2. **Déploie** le dernier commit de la branche en preview, pas en production.
3. **Contrôles sur la preview**
   - **Fichiers et en-têtes**
     - `/assets/noodeu-release.json` doit renvoyer le bon commit et `"databaseMigrationsAppliedByBuild": false` ;
     - `curl -I` sur `/assets/index-*.js` doit renvoyer `Cache-Control: public, max-age=31536000, immutable` ;
     - `/sw.js` doit renvoyer `no-cache` ;
     - le HTML doit contenir le `preconnect` vers `https://uqyrjdaonqqkkpzyjfcg.supabase.co`.
   - **Compte jetable**
     - crée un compte avec une adresse de test jetable : arrivée directe sur l'accueil, sans e-mail ;
     - **Réglages → Changer mon mot de passe** :
       - un mauvais mot de passe actuel affiche un message précis ;
       - en mode avion, le message est « Modification impossible… », jamais « mauvais mot de passe » ;
       - le changement avec le bon mot de passe fonctionne ;
       - après déconnexion, on se reconnecte avec le nouveau mot de passe ;
       - n'utilise jamais le mot de passe d'un compte réel ;
     - **Espace** : la note ajoutée apparaît, la couverture se change ;
     - **Supprime ce compte** (Réglages → Supprimer mon compte), ce qui vérifie aussi la suppression.
   - **Écran de connexion** : le lien `gooroosapio@gmail.com` est présent.
   - **Avec Kalou** : nouveau salon, une partie G01 et une G08 (brouillon conservé au rechargement, purgé sur « Passer »), conversation, fin de partie.
   - **Réseau** : au premier affichage, seuls `index`, `react` et `supabase` sont chargés ; `SessionScreen` se charge en temps mort ou à l'entrée en partie.

## 7. Étape 5 : production

1. Le propriétaire autorise la mise en production de ce commit précis, une fois tous les contrôles de la preview verts. Promeus la preview validée, et aucun autre commit.
2. Refais les contrôles de l'étape 4 sur noodeu.vercel.app.
3. Vérifie aussi qu'un client resté ouvert sur l'ancienne version reçoit la mise à jour :
   - hors partie, elle s'installe d'elle-même ;
   - en partie, une invitation à recharger s'affiche ;
   - aucune erreur de chargement de fichier.
4. Au moindre défaut bloquant, reviens au déploiement de `0ee5ebf` (Instant Rollback), puis signale le défaut avec ses preuves.

## 8. Rapport final attendu

- Commits livrés et identifiants des déploiements preview et production.
- Résumés PASS et FAIL de l'étape 2.
- Finitions faites, avec captures avant et après.
- Résultat de chaque contrôle en ligne.
- Ce qui n'a pas pu être vérifié, dit clairement (vrais téléphones iOS et Android, vraie partie à deux).
- Point de retour arrière : identifiant du déploiement `0ee5ebf`.
