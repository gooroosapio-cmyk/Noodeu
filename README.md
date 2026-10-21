# Noodeu

Application web installable (PWA) pour jouer à deux, même à distance : se découvrir, rire et entretenir sa complicité.

- **Interface** : React 19 + TypeScript + Vite, routeur React Router, PWA (vite-plugin-pwa).
- **Serveur** : Supabase (comptes, base PostgreSQL, règles d'accès, temps réel). Aucun serveur supplémentaire.
- **Direction visuelle** : kit « Complicité » V1 (`public/assets/noodeu/`, documentation dans `docs/kit/`).

## Lancer l'application en local

Prérequis : Node.js 22 ou plus récent.

```bash
npm install
cp .env.example .env.local      # puis renseigner l'URL et la clé « publishable » du projet Supabase
npm run dev                     # http://localhost:5173
```

Autres commandes :

| Commande | Rôle |
|---|---|
| `npm run build` | Vérifie les types puis construit l'application dans `dist/` |
| `npm run preview` | Sert la version construite (nécessaire pour tester l'installation PWA) |
| `npm test` | Tests unitaires de la logique de jeu |
| `node tests/visual/render-check.mjs` | Vérification visuelle à 320/390/430 px (avec `npm run preview` lancé) |

## Base de données

Les migrations versionnées sont dans `supabase/migrations/` et s'appliquent dans l'ordre. Elles sont déjà appliquées
au projet Supabase « Noodeu ». Pour un nouveau projet : `npx supabase link` puis `npx supabase db push`.

Tests de sécurité et de partie : `supabase/tests/slice1_security_and_game.sql`. Ils s'exécutent dans une
transaction annulée et ne laissent aucune donnée (voir `docs/TESTS.md`).

## Documentation

- `docs/DECISIONS.md` : décisions produit et techniques ;
- `docs/ARCHITECTURE.md` : données, sécurité, temps réel, moteur de jeux ;
- `docs/CONTENUS.md` : schéma des contenus et procédure d'import ;
- `docs/DEPLOIEMENT.md` : mise en ligne (Vercel + Supabase) ;
- `docs/ETAT.md` : ce qui fonctionne, ce qui a été testé, les limites restantes ;
- `docs/RESSOURCES.md` : inventaire des visuels intégrés.
