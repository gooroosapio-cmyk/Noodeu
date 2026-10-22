# Déploiement

## 1. Supabase (déjà fait pour le projet « Noodeu »)

Les migrations de `supabase/migrations/` sont appliquées au projet `uqyrjdaonqqkkpzyjfcg` (région eu-west-1).

Réglages à faire dans le tableau de bord Supabase (**Authentication → URL Configuration**) une fois l'adresse du site connue :

- **Site URL** : `https://noodeu.vercel.app` ;
- **Redirect URLs** : la même adresse suivie de `/**`, plus `http://localhost:5173/**` pour le développement.

Sans ce réglage, les liens de confirmation d'e-mail renvoient vers une adresse par défaut.

### Envoi des e-mails

Le service d'e-mails intégré à Supabase est limité à quelques envois par heure et sert aux essais.
Avant d'ouvrir l'application au public, il faut brancher un fournisseur d'e-mails (SMTP), qui peut être payant :
à décider ensemble.

### Connexion Google (décision 2C)

Le code est prêt ; le bouton apparaît **automatiquement** dès que le fournisseur est activé dans Supabase.

1. Google Cloud Console → « APIs et services » → « Écran de consentement OAuth » : type Externe, nom « Noodeu »,
   adresse de contact, domaine autorisé `supabase.co` (et ton futur domaine).
2. « Identifiants » → « Créer des identifiants » → « ID client OAuth » → Application Web.
   - Origines JavaScript autorisées : `https://noodeu.vercel.app`
   - URI de redirection autorisés : `https://uqyrjdaonqqkkpzyjfcg.supabase.co/auth/v1/callback`
3. Supabase → Authentication → Sign In / Providers → Google : activer, coller l'ID client et le code secret
   (**uniquement là**, jamais dans le dépôt ni dans Vercel).
4. Vérifier que `https://noodeu.vercel.app/**` figure dans les Redirect URLs (section 1).
5. Tester : connexion réussie, annulation sur l'écran Google, puis lien d'invitation ouvert avant la connexion
   (la page « Rejoindre » doit se rouvrir après le retour, sans accepter automatiquement le duo).

### Sécurité des mots de passe

Supabase recommande d'activer **Authentication → Passwords → Leaked password protection** (refus des mots de
passe connus pour avoir fuité). Réglage à faire dans le tableau de bord.

### Fonction serveur

`supabase/functions/delete-account` est déployée (suppression de compte). Elle utilise les clés serveur fournies
automatiquement par Supabase ; aucune clé secrète n'est à configurer.

## 2. Vercel (en place depuis le 21 octobre 2026)

- Adresse : **https://noodeu.vercel.app** (projet Vercel « noodeu », relié au dépôt GitHub).
- Chaque envoi sur la branche de travail `ccr-7a7de876-azitw6` crée une **prévisualisation** (accès réservé au compte Vercel).
  La version publique `noodeu.vercel.app` n'est mise à jour que par une mise en production explicite.
  Plus tard, fusionner le travail dans une branche `main` permettra une mise en production automatique.
- Les adresses de prévisualisation générées par Vercel demandent une connexion à Vercel ; `noodeu.vercel.app` est public.
- Un second projet « noodeu-wup1 », relié au même dépôt, existe aussi : il semble être un doublon et peut être supprimé
  depuis le tableau de bord Vercel.

- Framework : Vite. Commande de build : `npm run build`. Dossier publié : `dist`.
- Variables d'environnement : `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`, `VITE_AUTH_GOOGLE`.
- Toutes les routes doivent renvoyer `index.html` (application à page unique) : voir `vercel.json`.

## 3. Après la mise en ligne

- Ouvrir le site sur deux téléphones avec deux comptes et dérouler le parcours de `docs/TESTS.md` (section « recette manuelle »).
- Installer l'application depuis le navigateur (« Ajouter à l'écran d'accueil »).

## 4. Comptes administrateurs

Un compte devient administrateur quand son identifiant figure dans la table `public.app_admins`
(ajout depuis l'éditeur SQL de Supabase). Premier administrateur ajouté le 21 octobre 2026 : le compte de la
porteuse ou du porteur du projet. Aucun mot de passe n'est conservé dans le dépôt.
Le rôle donne aujourd'hui accès en lecture aux contenus non publiés ; l'interface d'administration arrive à l'étape 7.

## Migration en attente d'accord : `20261022000150_catalogue_144_engine_privacy.sql`

L'outil de migration Supabase demande une confirmation explicite pour les instructions `delete` et `revoke`.
Cette migration n'a donc pas été appliquée en ligne. Elle :
- ferme la lecture directe des tables de manches et de réponses (tout passe par `get_session_state`) ;
- ajoute les options privées +18 / thèmes à éviter (`set_session_prefs`) et la sortie commune (`finish_session`) ;
- ajoute l'effacement des réponses 24 h après la fin (`purge_expired_sessions`), à planifier avec pg_cron.

Pour l'appliquer : l'éditeur SQL du tableau de bord Supabase (coller le fichier), ou approuver la demande de l'outil.
Tant qu'elle manque : les options +18 et « Arrêter ici ensemble » répondent par une erreur, et une réponse révélée
reste lisible en direct par l'autre membre du duo (sauf la capsule, protégée par la migration 140).

État au 22 octobre 2026 (soir) : nouvelle tentative, de nouveau bloquée en attente de confirmation. Toujours à appliquer.

## Partenaire automatique de test (temporaire) — `20261022000300_test_autoplayer.sql`

Pour tester seul, un compte inscrit dans `private.test_autoplayers` est toujours prêt dans le salon et répond tout
seul à ses étapes (réponses de test valides, mêmes fonctions et validations que l'application), et reprend les
préférences de partie (+18, thèmes à éviter) de l'autre joueur. Inscrit en ligne : le compte de démonstration
« Kalou » (inscription faite à la main sur la base ; l'adresse n'est pas écrite dans le dépôt).

## Audit final — à faire avant l'ouverture

- [ ] Vider `private.test_autoplayers` (le partenaire automatique ne fait alors plus rien), puis retirer le mécanisme
      (`bump_session` d'origine) par une migration.
- [ ] Supprimer le compte de démonstration « Kalou » (et son duo) depuis Supabase → Authentication.
- [ ] Vérifier que la migration de confidentialité 150 est appliquée et planifier `purge_expired_sessions` (pg_cron).

## Famille 2 (22 octobre 2026)

Migrations appliquées en ligne : `board_engine_core`, `board_family2_rules`, `board_family2_bot`, `famille2_contenus`
(fichiers `20261022000400`, `…410`, `…420`, `20261022020030`). Contrôle : empreintes des fonctions, des versions de
règles et des niveaux identiques entre la base en ligne et la base de test locale.
Les coups des jeux de mots (indices, propositions) sont conservés avec la partie ; leur effacement automatique sera
ajouté avec la tâche d'effacement à 24 h (migration 150, toujours en attente d'accord).

## Famille 4 (22 octobre 2026)

Migrations : `board_family4_rules` (tirage, règles, robot de test et aiguillage, fichier `20261022040010`) et
`famille4_contenus` (`…040030`). Ce qu'il faut mémoriser n'est envoyé qu'à l'écran concerné et retiré au coup
« seen » ; les réponses sont notées sur le serveur et restent cachées jusqu'aux deux réponses.
Limites assumées : pour les jeux purement visuels (différences, chasse au détail, silhouette, superpositions,
aperçu zoomé), l'image à observer est forcément transmise à l'écran ; un joueur qui inspecte le code de la page
peut en déduire la réponse. Recharger la page pendant une observation relance son compte à rebours.
Aucun temps de réaction n'est comparé entre deux appareils.

## Famille 3 (22 octobre 2026)

Migrations appliquées en ligne : `board_family3_rules`, `board_family3_bot`, `board_dispatch`, `famille3_contenus`
(fichiers `20261022030010`, `…030020`, `…030000`, `…030030`). Empreintes identiques à la base de test locale.
Écart assumé avec la fiche du tangram : rotation par quarts de tour sur grille (au lieu de 45°), pour garder un
contrôle exact par surfaces ; le carré du kit reste réalisable. Les créations s'enregistrent en PNG dans le
navigateur (rien n'est envoyé ailleurs) et se gardent dans l'Espace si les deux joueurs sont d'accord.
