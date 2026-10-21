# Architecture

## Vue d'ensemble

```
Navigateur (PWA React)
  ├─ lit : tables autorisées par les règles d'accès (RLS) + fonctions get_*
  ├─ agit : uniquement via des fonctions (RPC) qui vérifient chaque règle
  └─ écoute : canaux temps réel privés (signaux sans contenu) → relit l'état
Supabase
  ├─ Auth (comptes)
  ├─ PostgreSQL (données, règles d'accès, fonctions, migrations versionnées)
  └─ Realtime (diffusion depuis la base, présence indicative)
```

## Données

| Domaine | Tables | Visibilité |
|---|---|---|
| Identité | `profiles` | soi + partenaire actuel ou passé |
| Couple | `couples`, `couple_members` | membres actuels ou passés (lecture seule après séparation) |
| Invitations | `invitations`, `private.invitation_attempts` | la personne qui invite et la personne invitée |
| Catalogue | `game_categories`, `games`, `game_versions` | comptes connectés (contenus publiés) |
| Cartes | `game_cards` | administration uniquement (tirées côté serveur) |
| Favoris | `game_favorites` | strictement personnel |
| Parties | `game_sessions`, `session_players`, `session_rounds` | membres du couple |
| Réponses | `session_answers` | soi ; partenaire **après révélation seulement** |
| Salon | `session_messages` | membres actifs ; effacé à la clôture |
| Administration | `app_admins` | soi |

Les fonctions utilitaires sont dans le schéma `private`, qui n'est pas exposé par l'API.

## Moteur de jeux

Une version de jeu (`game_versions.config`) décrit :

- `mechanic` : la mécanique réutilisable (aujourd'hui `portrait_words`) ;
- `rounds` : le nombre de manches ;
- `steps` : les étapes privées de chaque joueur, dans l'ordre ;
- `reveal` : la condition de révélation (toutes les étapes des deux joueurs) ;
- `skip` : la possibilité de passer une étape sans pénalité ;
- `score` : `none` quand un score n'apporte rien ;
- `settings` : les réglages proposés dans le salon, avec leurs valeurs autorisées.

`game_versions.rules` contient les textes affichés : objectif, déroulé, règles détaillées, consignes de chaque étape
(« ta réponse » / « ce que tu penses que ton ou ta partenaire a choisi »).

Cycle d'une partie : `lobby` (salon, réglages, « Je suis disponible ») → `playing` ⇄ `paused` → `ended`
(résultats, salon encore ouvert, vote « garder ce souvenir ») → `closed` (salon effacé ; réponses effacées sauf accord des deux).
`abandoned` : partie quittée avant la fin, rien n'est conservé.

Ajouter une mécanique : (1) l'ajouter à la contrainte `games.mechanic`, (2) écrire son tirage dans `private.draw_round_card`
et sa validation dans `private.validate_payload`, (3) écrire son écran dans `src/game/`.

## Temps réel

| Canal | Contenu | Qui peut l'écouter |
|---|---|---|
| `user:<id>` | invitation reçue, réponse, séparation | la personne elle-même |
| `couple:<id>` | partie ouverte modifiée ; présence | membres actifs |
| `session:<id>` | « état modifié (version N) », messages du salon ; présence | membres actifs |

Les navigateurs ne peuvent pas diffuser sur ces canaux, seulement y publier leur présence. La présence n'est qu'une
indication : elle ne prouve jamais qu'une action a eu lieu.

## Sécurité

- Règles d'accès sur chaque table ; droits d'API retirés puis rouverts au strict nécessaire.
- Fonctions `security definer` avec `search_path` vide ; chaque fonction vérifie l'appartenance au couple.
- Aucune clé secrète dans le navigateur ni dans le dépôt (`.env.local` est ignoré par git).
- Les réponses et messages ne sont jamais journalisés par l'application.
- Le conseiller Supabase signale que les fonctions du jeu sont appelables par les comptes connectés : c'est voulu,
  ce sont les actions de l'application ; chacune contrôle les droits de l'appelant.
