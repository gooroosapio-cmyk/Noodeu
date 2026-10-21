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

1. Dans Google Cloud Console, créer un identifiant « OAuth client ID » de type application web.
2. Ajouter l'adresse de rappel indiquée par Supabase (Authentication → Providers → Google).
3. Coller l'identifiant et le secret **dans Supabase uniquement** (jamais dans le dépôt).
4. Passer `VITE_AUTH_GOOGLE=true` dans les variables d'environnement du site.

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
