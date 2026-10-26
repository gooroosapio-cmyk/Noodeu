# Prompt pour Codex : vérifications finales, finitions front et mise en ligne de la V7

Tu reprends le projet Noodeu (PWA React + TypeScript + Vite) dans le dépôt `gooroosapio-cmyk/Noodeu`.
Réponds en français. Travaille par étapes et fais un audit complet avant toute action.

## Contexte

- La production sert actuellement le commit `70fb169` (branche `refonte/rouge-20261026`). C'est le point de retour arrière.
- La branche à livrer est `v7/interface-20261026`, partie de `70fb169`. Elle contient trois commits :
  1. l'interface V7 ;
  2. la fidélité aux témoins pour l'accueil, l'espace, le coffre, l'historique et la conversation ;
  3. les optimisations de fluidité et de rapidité.
- Le compte rendu complet se trouve dans `docs/V7_INTERFACE_20261026.md`. Lis-le en entier avant de commencer.
- Les autres références sont dans `docs/captures/v7-20261026/` : captures, et comparaisons `fidelite-*.jpg` avec les témoins.
- Supabase : projet `uqyrjdaonqqkkpzyjfcg`. Ne touche jamais au projet « Limpid ».
- Vercel : projet `prj_pILsfC2SFwCQjQLyhPrROCKoVSrC` (noodeu.vercel.app), équipe `team_vwilsshWZZiqYc5vQLN8f3zj`.
- **Cette livraison ne comporte aucune migration.** `git diff 70fb169..v7/interface-20261026 -- supabase` doit être vide. Vérifie-le. S'il ne l'est pas, arrête-toi et signale-le.

## Règles impératives

- Ne place jamais de secret dans le navigateur, GitHub ou les journaux. Ne demande jamais de token ni de mot de passe.
- Les opérations privilégiées restent côté serveur.
- Aucune migration, aucune modification de données de production.
- Ne rejoue aucune purge ni aucun script de tests en production.
- Aucun paiement, abonnement, appel à un fournisseur d'IA ou service payant ne doit être activé.
- Garde désactivées les fonctions dont les services ne sont pas prêts. Ne présente jamais une fonctionnalité simulée comme terminée.
- Interface :
  - Pas de score, statut de synchronisation, audio ou backend inventé.
  - Ne fabrique pas d'original de marque, et garde le logo intact.
  - Les PNG témoins sont des références de composition. Ils ne servent jamais de fond cliquable.
- Données sensibles :
  - Ne journalise pas les réponses intimes.
  - Ne mets aucune donnée sensible en cache hors ligne.
  - Conserve les brouillons G08 en `sessionStorage` : restaurés au rechargement, purgés sur « Passer », en fin de manche et au changement de compte.
- Droits : conserve les notices et n'invente aucune autorisation accordée par un éditeur tiers.
- Git : aucun remplacement global, aucun force-push, aucune réécriture d'historique.
- Ne prétends jamais avoir exécuté un test ou consulté un fichier sans preuve. Joins les sorties de commande.

## Étape 1 : audit (aucune modification)

1. `git fetch`, puis `git checkout v7/interface-20261026`, puis `git log --oneline 70fb169..HEAD`.
2. Lis `git diff --stat 70fb169..HEAD` et lis le diff des fichiers `src/` modifiés.
3. Vérifie le point de retour arrière : dans Vercel, repère le déploiement de production actuel (`70fb169`) et note son identifiant.
4. Fais un rapport court : ce qui change, les risques que tu vois, ce que tu proposes de peaufiner. Attends d'avoir fini l'étape 2 avant de corriger quoi que ce soit.

## Étape 2 : vérifications locales

Chromium et Playwright sont nécessaires. Lance d'abord `npm ci`, puis `npm run build`, puis `npx vite preview --port 4173 --strictPort`.

- `npm run lint`, `npm run typecheck`, `npm test` (13 tests attendus), `npm run build`.
- Parcours visuels, avec le serveur de prévisualisation lancé. Ils n'utilisent que des réponses simulées, aucun appel réel :
  - `node tests/visual/v7-flows.mjs` (9 scénarios) ;
  - `node tests/visual/lobby-ready-lifecycle.mjs` (5) ;
  - `node tests/visual/red-games-flows.mjs` (10) ;
  - `node tests/visual/red-keyboard-check.mjs` (6).
- Recette visuelle : `WIDTHS=360,390,412 HEIGHT=844 node tests/visual/render-check.mjs <dossier>`. Attendu : aucun débordement, aucun contenu masqué sous la navigation, aucune erreur JavaScript.
- Texte agrandi : `ZOOM=2 WIDTHS=412 HEIGHT=915 SCREENS='^(06d|21a|21e|21g|30-chat)'`.
- Ne lance pas de nouveau build pendant une recette en cours : le dossier `dist` est remplacé.

## Étape 3 : finitions front (petites, ciblées, vérifiées)

Compare l'application aux témoins V7 et aux captures `fidelite-*.jpg`. Ne corrige que des détails visuels ou de libellé, sans nouvelle fonctionnalité ni changement serveur. Relance les tests concernés après chaque correction.

À contrôler en particulier :

1. **Conversation plein écran** (témoins 07/08) :
   - aucune navigation ni bouton flottant ;
   - le champ de saisie de 52 px reste visible au-dessus du clavier (iOS Safari et Android Chrome : `visualViewport`, `--kb-inset`) ;
   - la bordure devient cerise au focus ;
   - le clavier ne s'ouvre pas tout seul à l'ouverture de la conversation ;
   - le retour ferme la conversation.
2. **Bouton de conversation flottant** : il reste fixe au défilement, à 12 px au-dessus de la navigation et 16 px du bord, et ne masque aucun contenu.
3. **Accueil** (témoin 01) :
   - à 360 px, « Récemment joués » est masqué ;
   - la tuile « À reprendre » affiche la vraie progression ;
   - aucun mot ne se coupe dans les filtres à 200 %.
4. **Espace, coffre, historique** (témoins 04/05/06) :
   - pas plus de 3 parties récentes, avec « Tout voir » ;
   - les retours ramènent au bon duo ;
   - la pagination affiche « Page X sur N » avec le vrai total ;
   - les cibles tactiles font au moins 44 px.
5. **Zones de sécurité (safe areas)** : sur iPhone avec encoche et sur PWA installée, vérifie l'en-tête, la navigation et le champ de saisie.
6. **« Réduire les animations »** (réglage du profil et `prefers-reduced-motion`) : le fond doit rester immobile.

Livre chaque finition dans un commit séparé sur la branche `v7/interface-20261026`, avec un message clair. Pas de force-push.

## Étape 4 : déploiement

1. **Prévisualisation d'abord.** Déploie la branche `v7/interface-20261026` en *preview* Vercel (pas en production).
2. **Contrôles sur la preview :**
   - `GET /assets/noodeu-release.json` doit renvoyer le bon commit et `"databaseMigrationsAppliedByBuild": false`.
   - `curl -I` sur un fichier `/assets/index-*.js` doit renvoyer `Cache-Control: public, max-age=31536000, immutable`. Si l'en-tête n'est pas appliqué, corrige le motif dans `vercel.json`.
   - `curl -I /sw.js` doit renvoyer `no-cache`, et `noodeu-release.json` doit renvoyer `no-store`.
   - Le HTML doit contenir `<link rel="preconnect" href="https://uqyrjdaonqqkkpzyjfcg.supabase.co" crossorigin>`.
   - Parcours manuel avec le compte de test Kalou (`dkalou151@gmail.com`, joueur automatique toujours prêt) :
     - connexion ;
     - accueil, espace, coffre, historique ;
     - conversation (envoi d'un message) ;
     - nouveau salon, puis une partie G01 et une partie G08 (brouillon conservé au rechargement, purgé sur « Passer ») ;
     - fin de partie et retour à l'accueil.
   - Onglet Réseau : au premier affichage, seuls les fichiers `index`, `react` et `supabase` sont chargés. `SessionScreen` doit se charger en temps mort, ou à l'entrée en partie.
   - Hors ligne, puis reconnexion : l'interface se recharge proprement, et aucune donnée privée n'est servie depuis le cache.
   - Si possible, Lighthouse mobile sur `/` et `/accueil` : note LCP, TBT et CLS.
3. **Production.** Le propriétaire autorise la mise en production de ce commit précis, une fois que tous les contrôles de la preview sont verts. Promeus la preview validée (ou déploie le même commit) en production. Aucun autre commit.
4. **Après la mise en production :** relance les contrôles de l'étape 4.2 sur noodeu.vercel.app. Vérifie aussi qu'un client resté ouvert sur l'ancienne version reçoit la mise à jour : hors partie, elle s'installe d'elle-même ; en partie, une invitation à recharger s'affiche ; aucune erreur de chargement de fichier.
5. **Retour arrière.** Au moindre défaut bloquant, reviens immédiatement au déploiement de `70fb169` (Instant Rollback Vercel), puis signale le défaut avec ses preuves.

## Rapport final attendu

- Commits livrés (hachés), identifiants de déploiement preview et production.
- Sorties des commandes de l'étape 2 (résumés avec les comptes PASS et FAIL).
- Liste des finitions faites, avec captures avant et après.
- Résultats des contrôles en ligne : en-têtes, release.json, parcours Kalou, réseau, Lighthouse si fait.
- Ce qui n'a pas pu être vérifié (par exemple un appareil réel indisponible), dit clairement.
- Point de retour arrière : l'identifiant du déploiement `70fb169`.
