# Déploiement

## 1. Supabase (déjà fait pour le projet « Noodeu »)

Les migrations de `supabase/migrations/` sont appliquées au projet `uqyrjdaonqqkkpzyjfcg` (région eu-west-1).

Réglages à faire dans le tableau de bord Supabase (**Authentication → URL Configuration**) une fois l'adresse du site connue :

- **Site URL** : l'adresse de production (par exemple `https://noodeu.vercel.app`) ;
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

## 2. Vercel

- Framework : Vite. Commande de build : `npm run build`. Dossier publié : `dist`.
- Variables d'environnement : `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`, `VITE_AUTH_GOOGLE`.
- Toutes les routes doivent renvoyer `index.html` (application à page unique) : voir `vercel.json`.

## 3. Après la mise en ligne

- Ouvrir le site sur deux téléphones avec deux comptes et dérouler le parcours de `docs/TESTS.md` (section « recette manuelle »).
- Installer l'application depuis le navigateur (« Ajouter à l'écran d'accueil »).
