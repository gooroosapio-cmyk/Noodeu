# Contenus : schéma et procédure d'import

## Principes

- Identifiants **stables** en texte : `portrait-en-cinq-mots`, `portrait.curieux`, `N-ST-001`…
- Statuts : `draft` (brouillon) → `published` (publié) → `archived` (archivé).
- `is_demo = true` marque tout contenu provisoire. Il est signalé dans l'interface par le badge « Contenu de démonstration ».
- Une version de jeu publiée ne peut plus être modifiée. Pour changer des règles, créer la version suivante puis
  mettre à jour `games.current_version`. Les parties déjà commencées gardent leur copie.
- Les contenus factuels (anecdotes, éclairages) portent leur source. Un proverbe n'est jamais attribué à une culture sans attestation.

## Jeu

```jsonc
// games
{ "id": "portrait-en-cinq-mots", "category_id": "se-decouvrir", "mechanic": "portrait_words",
  "title": "Portrait en cinq mots", "promise": "Se découvrir autrement, en quelques mots.",
  "style": "echange", "duration_min": 4, "duration_max": 6, "content_level": "standard" }

// game_versions.rules (textes affichés)
{ "objective": "…", "how_to": ["…", "…"], "details": ["…"], "privacy": "…",
  "step_texts": { "self":  { "title": "Mon portrait", "prompt": "…", "hint": "…", "confirm": "…" },
                  "guess": { "title": "Son portrait", "prompt": "Et {partner}, en cinq mots ?", "hint": "…", "confirm": "…" } } }

// game_versions.config (moteur)
{ "mechanic": "portrait_words", "rounds": 1, "pick": 5,
  "steps": [ { "key": "self", "kind": "pick_words", "about": "self" },
             { "key": "guess", "kind": "pick_words", "about": "partner" } ],
  "reveal": "all_players_all_steps", "skip": "allowed_without_penalty", "score": "none",
  "settings": { "deck_size": { "label": "Mots proposés", "options": [12, 16], "default": 12 } } }
```

Cartes de mots : `game_cards` avec `kind = "word"` et `content = { "f": "Curieuse", "m": "Curieux" }`.

## Astuces (à venir, étape 6)

Format prévu pour les 500 stories du PDF « 500 Stories — Vie à deux » :

```jsonc
{ "id": "N-ST-001", "kind": "conseil|eclairage|anecdote|proverbe|pensee|clin-d-oeil",
  "title": "Le montant relatif", "body": "…", "category": "Argent sans tabou",
  "source_ref": "S15", "status": "draft" }
```

## Procédure d'import (prévue avec l'administration, étape 7)

1. Préparer un fichier JSON ou CSV au format ci-dessus.
2. Le déposer dans l'administration : vérification automatique (champs obligatoires, identifiants en double,
   longueur des textes, sources manquantes pour les faits) **avant** toute écriture.
3. Relire l'aperçu, corriger, puis importer en **brouillon**.
4. Publier par lots après validation.

En attendant l'administration, un import se fait par migration SQL relue (comme `…500_demo_content_portrait.sql`).
