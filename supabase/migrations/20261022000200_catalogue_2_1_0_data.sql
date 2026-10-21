-- Import généré par scripts/import_catalogue.py — édition 2.1.0 (2026-10-21).
-- Idempotent : relancer ne crée ni doublon ni nouvelle version si rien n'a changé. Les parties existantes
-- gardent leur copie de cartes et leur version de règles. Ne pas modifier à la main.

create temporary table import_log (kind text, id text, action text);

insert into public.game_categories (id, title, promise, sort, status, is_demo, family_no)
values ($n$complicite-confidences$n$, $n$Complicité et confidences$n$, $n$Des échanges qui partent du quotidien, des choix qui font sourire et des confidences que chacun choisit de partager.$n$, 1, 'published', false, 1)
on conflict (id) do update set title = excluded.title, promise = excluded.promise, sort = excluded.sort,
  status = excluded.status, family_no = excluded.family_no
  where (game_categories.title, game_categories.promise, game_categories.sort, game_categories.status, game_categories.family_no)
    is distinct from (excluded.title, excluded.promise, excluded.sort, excluded.status, excluded.family_no);

insert into public.game_categories (id, title, promise, sort, status, is_demo, family_no)
values ($n$mots-repartie$n$, $n$Mots et répartie$n$, $n$Des lettres à manipuler, des indices à inventer et le plaisir de comprendre comment l’autre pense.$n$, 2, 'published', false, 2)
on conflict (id) do update set title = excluded.title, promise = excluded.promise, sort = excluded.sort,
  status = excluded.status, family_no = excluded.family_no
  where (game_categories.title, game_categories.promise, game_categories.sort, game_categories.status, game_categories.family_no)
    is distinct from (excluded.title, excluded.promise, excluded.sort, excluded.status, excluded.family_no);

insert into public.game_categories (id, title, promise, sort, status, is_demo, family_no)
values ($n$dessin-creation$n$, $n$Dessin et création$n$, $n$Des ateliers tactiles où un trait maladroit devient une idée commune. Aucun niveau de dessin attendu.$n$, 3, 'published', false, 3)
on conflict (id) do update set title = excluded.title, promise = excluded.promise, sort = excluded.sort,
  status = excluded.status, family_no = excluded.family_no
  where (game_categories.title, game_categories.promise, game_categories.sort, game_categories.status, game_categories.family_no)
    is distinct from (excluded.title, excluded.promise, excluded.sort, excluded.status, excluded.family_no);

insert into public.game_categories (id, title, promise, sort, status, is_demo, family_no)
values ($n$memoire-observation$n$, $n$Mémoire et observation$n$, $n$Un cabinet de curiosités : repérer, retenir, comparer et reconstruire des scènes claires sur petit écran.$n$, 4, 'published', false, 4)
on conflict (id) do update set title = excluded.title, promise = excluded.promise, sort = excluded.sort,
  status = excluded.status, family_no = excluded.family_no
  where (game_categories.title, game_categories.promise, game_categories.sort, game_categories.status, game_categories.family_no)
    is distinct from (excluded.title, excluded.promise, excluded.sort, excluded.status, excluded.family_no);

insert into public.game_categories (id, title, promise, sort, status, is_demo, family_no)
values ($n$logique-codes$n$, $n$Logique et codes$n$, $n$Un atelier de casse-tête : des règles vérifiables, des indices justes et des solutions conservées côté serveur.$n$, 5, 'published', false, 5)
on conflict (id) do update set title = excluded.title, promise = excluded.promise, sort = excluded.sort,
  status = excluded.status, family_no = excluded.family_no
  where (game_categories.title, game_categories.promise, game_categories.sort, game_categories.status, game_categories.family_no)
    is distinct from (excluded.title, excluded.promise, excluded.sort, excluded.status, excluded.family_no);

insert into public.game_categories (id, title, promise, sort, status, is_demo, family_no)
values ($n$plateaux-strategie$n$, $n$Plateaux et stratégie$n$, $n$Un salon de jeux de poche : vrais choix tactiques, pièces lisibles et manches avec une fin définie.$n$, 6, 'published', false, 6)
on conflict (id) do update set title = excluded.title, promise = excluded.promise, sort = excluded.sort,
  status = excluded.status, family_no = excluded.family_no
  where (game_categories.title, game_categories.promise, game_categories.sort, game_categories.status, game_categories.family_no)
    is distinct from (excluded.title, excluded.promise, excluded.sort, excluded.status, excluded.family_no);

insert into public.game_categories (id, title, promise, sort, status, is_demo, family_no)
values ($n$cooperation-missions$n$, $n$Coopération et missions$n$, $n$Deux écrans, des informations complémentaires et des actions qui ont besoin l’une de l’autre.$n$, 7, 'published', false, 7)
on conflict (id) do update set title = excluded.title, promise = excluded.promise, sort = excluded.sort,
  status = excluded.status, family_no = excluded.family_no
  where (game_categories.title, game_categories.promise, game_categories.sort, game_categories.status, game_categories.family_no)
    is distinct from (excluded.title, excluded.promise, excluded.sort, excluded.status, excluded.family_no);

insert into public.game_categories (id, title, promise, sort, status, is_demo, family_no)
values ($n$histoires-improvisation$n$, $n$Histoires et improvisation$n$, $n$Un petit studio à deux : écrire, jouer des personnages, composer des scènes et conserver vos créations.$n$, 8, 'published', false, 8)
on conflict (id) do update set title = excluded.title, promise = excluded.promise, sort = excluded.sort,
  status = excluded.status, family_no = excluded.family_no
  where (game_categories.title, game_categories.promise, game_categories.sort, game_categories.status, game_categories.family_no)
    is distinct from (excluded.title, excluded.promise, excluded.sort, excluded.status, excluded.family_no);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-001$n$, $n$complicite-confidences$n$, $n$conversation$n$, $n$On se raconte$n$, $n$Les petites histoires disent souvent plus que les grandes déclarations.$n$, $n$Les petites histoires disent souvent plus que les grandes déclarations.$n$, $n$echange$n$, 3, 10, 'standard', 1, 'published', false,
    $n$playable$n$, true, true, array[]::text[], $n$/assets/jeux/vignettes/N2-001.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "DECK", "content_count": 80, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "choix privés puis révélation", "level_count": 0, "summary": {"end": "Fin après 8 cartes ou sortie commune. Aucun score ni mesure de sincérité.", "setup": "Chacun choisit privé ou partage immédiat ; tirer 8 cartes dans les thèmes communs.", "turn": "Lire la carte. Chacun rédige jusqu’à 600 caractères et peut passer. Quand les deux ont confirmé, révéler les réponses ; un espace de réaction libre suit."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-001$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-001$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-001$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-001$n$), 0) + 1, $n${"details": ["Fin après le nombre de cartes choisi, ou plus tôt si vous arrêtez ensemble.", "Une carte passée s'affiche « Carte passée », sans justification à donner.", "Aucun score, aucune mesure de sincérité."], "how_to": ["Lisez la carte.", "Chacun écrit sa réponse en privé (600 caractères au plus) ou passe.", "Quand vous avez confirmé tous les deux, les réponses apparaissent ensemble.", "Un espace de réaction libre suit chaque carte."], "objective": "Échanger de petites histoires à partir de cartes, à votre rythme.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"answer": {"confirm": "Confirmer ma réponse", "hint": "600 caractères au plus.", "prompt": "Raconte en quelques lignes.", "title": "Ta réponse"}, "reaction": {"confirm": "Envoyer", "hint": "Facultatif.", "prompt": "Un mot sur ce que vous venez de lire ?", "title": "Réagir"}}}$n$::jsonb, $n${"after": [{"key": "reaction", "kind": "reaction", "params": {"max": 300}}], "draw": {"deck": true}, "engine": "rounds", "mechanic": "conversation", "rounds_setting": "cartes", "settings": {"cartes": {"default": 8, "label": "Nombre de cartes", "options": [4, 8, 12]}}, "steps": [{"key": "answer", "kind": "text", "params": {"max": 600}, "skippable": true}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["Fin après le nombre de cartes choisi, ou plus tôt si vous arrêtez ensemble.", "Une carte passée s'affiche « Carte passée », sans justification à donner.", "Aucun score, aucune mesure de sincérité."], "how_to": ["Lisez la carte.", "Chacun écrit sa réponse en privé (600 caractères au plus) ou passe.", "Quand vous avez confirmé tous les deux, les réponses apparaissent ensemble.", "Un espace de réaction libre suit chaque carte."], "objective": "Échanger de petites histoires à partir de cartes, à votre rythme.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"answer": {"confirm": "Confirmer ma réponse", "hint": "600 caractères au plus.", "prompt": "Raconte en quelques lignes.", "title": "Ta réponse"}, "reaction": {"confirm": "Envoyer", "hint": "Facultatif.", "prompt": "Un mot sur ce que vous venez de lire ?", "title": "Réagir"}}}$n$::jsonb and cur.config = $n${"after": [{"key": "reaction", "kind": "reaction", "params": {"max": 300}}], "draw": {"deck": true}, "engine": "rounds", "mechanic": "conversation", "rounds_setting": "cartes", "settings": {"cartes": {"default": 8, "label": "Nombre de cartes", "options": [4, 8, 12]}}, "steps": [{"key": "answer", "kind": "text", "params": {"max": 600}, "skippable": true}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-001$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-002$n$, $n$complicite-confidences$n$, $n$dilemma$n$, $n$Deux options, ton choix$n$, $n$Choisir entre deux choses plausibles, puis découvrir pourquoi l’autre hésite.$n$, $n$Choisir entre deux choses plausibles, puis découvrir pourquoi l’autre hésite.$n$, $n$echange$n$, 3, 10, 'standard', 2, 'published', false,
    $n$playable$n$, true, true, array[]::text[], $n$/assets/jeux/vignettes/N2-002.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "DECK", "content_count": 80, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "choix privés puis révélation", "level_count": 0, "summary": {"end": "Pas de classement de compatibilité ; récapitulatif uniquement des cartes volontairement partagées.", "setup": "8 dilemmes, deux choix visibles et un bouton « Ça dépend ».", "turn": "Choisir en secret ; les deux choix apparaissent ensemble. Ajouter une phrase facultative pour expliquer ; « aucun des deux » reste possible."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-002$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-002$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-002$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-002$n$), 0) + 1, $n${"details": ["Une préférence n'est pas un engagement.", "Pas de classement de compatibilité.", "Un choix non confirmé n'est jamais affiché."], "how_to": ["Choisis en secret une option, « Ça dépend » ou « Aucun des deux ».", "Ajoute une phrase pour expliquer si tu veux.", "Les deux choix apparaissent ensemble."], "objective": "Deux options, ton choix : comparez vos préférences, sans bonne réponse.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"choice": {"confirm": "Confirmer mon choix", "hint": "Une phrase d'explication est facultative.", "prompt": "Que choisirais-tu ?", "title": "Ton choix"}}}$n$::jsonb, $n${"after": [], "draw": {"deck": true}, "engine": "rounds", "mechanic": "dilemma", "rounds_setting": "cartes", "settings": {"cartes": {"default": 8, "label": "Nombre de cartes", "options": [4, 8, 12]}}, "steps": [{"key": "choice", "kind": "choice", "params": {"comment_max": 200, "extras": ["depends", "neither"]}, "skippable": true}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["Une préférence n'est pas un engagement.", "Pas de classement de compatibilité.", "Un choix non confirmé n'est jamais affiché."], "how_to": ["Choisis en secret une option, « Ça dépend » ou « Aucun des deux ».", "Ajoute une phrase pour expliquer si tu veux.", "Les deux choix apparaissent ensemble."], "objective": "Deux options, ton choix : comparez vos préférences, sans bonne réponse.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"choice": {"confirm": "Confirmer mon choix", "hint": "Une phrase d'explication est facultative.", "prompt": "Que choisirais-tu ?", "title": "Ton choix"}}}$n$::jsonb and cur.config = $n${"after": [], "draw": {"deck": true}, "engine": "rounds", "mechanic": "dilemma", "rounds_setting": "cartes", "settings": {"cartes": {"default": 8, "label": "Nombre de cartes", "options": [4, 8, 12]}}, "steps": [{"key": "choice", "kind": "choice", "params": {"comment_max": 200, "extras": ["depends", "neither"]}, "skippable": true}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-002$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-003$n$, $n$complicite-confidences$n$, $n$experience$n$, $n$Déjà vécu ?$n$, $n$Un clin d’œil au test de pureté, débarrassé du classement moral.$n$, $n$Un clin d’œil au test de pureté, débarrassé du classement moral.$n$, $n$echange$n$, 3, 10, 'standard', 3, 'published', false,
    $n$playable$n$, true, true, array[]::text[], $n$/assets/jeux/vignettes/N2-003.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "DECK", "content_count": 80, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "choix privés puis révélation", "level_count": 0, "summary": {"end": "Fin du lot. Afficher le nombre de cartes échangées, jamais un pourcentage de pureté ou un classement sexuel.", "setup": "8 à 12 situations parmi 80 ; options « Oui », « Non », « Je passe ».", "turn": "Répondre sans raconter de détail obligatoire. Après révélation, chacun peut ajouter une anecdote. Toutes les expériences évoquées concernent des adultes."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-003$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-003$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-003$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-003$n$), 0) + 1, $n${"details": ["« Je passe » n'est jamais compté comme un non.", "À la fin : le nombre de cartes échangées, jamais de pourcentage ni de classement.", "Les situations évoquées concernent des adultes."], "how_to": ["Lis la situation.", "Réponds Oui, Non ou Je passe, sans détail obligatoire.", "Après la révélation, chacun peut ajouter une anecdote."], "objective": "Déjà vécu ? Répondez oui, non ou « Je passe », puis racontez si vous en avez envie.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"anecdote": {"confirm": "Partager", "hint": "Facultatif, 300 caractères.", "prompt": "Raconte si tu en as envie.", "title": "Une anecdote ?"}, "answer": {"confirm": "Confirmer", "hint": "Tu peux passer.", "prompt": "As-tu déjà vécu cette situation ?", "title": "Ta réponse"}}}$n$::jsonb, $n${"after": [{"key": "anecdote", "kind": "reaction", "params": {"max": 300}}], "draw": {"deck": true}, "engine": "rounds", "mechanic": "experience", "rounds_setting": "cartes", "settings": {"cartes": {"default": 8, "label": "Nombre de cartes", "options": [8, 12]}}, "steps": [{"key": "answer", "kind": "yes_no", "skippable": true}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["« Je passe » n'est jamais compté comme un non.", "À la fin : le nombre de cartes échangées, jamais de pourcentage ni de classement.", "Les situations évoquées concernent des adultes."], "how_to": ["Lis la situation.", "Réponds Oui, Non ou Je passe, sans détail obligatoire.", "Après la révélation, chacun peut ajouter une anecdote."], "objective": "Déjà vécu ? Répondez oui, non ou « Je passe », puis racontez si vous en avez envie.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"anecdote": {"confirm": "Partager", "hint": "Facultatif, 300 caractères.", "prompt": "Raconte si tu en as envie.", "title": "Une anecdote ?"}, "answer": {"confirm": "Confirmer", "hint": "Tu peux passer.", "prompt": "As-tu déjà vécu cette situation ?", "title": "Ta réponse"}}}$n$::jsonb and cur.config = $n${"after": [{"key": "anecdote", "kind": "reaction", "params": {"max": 300}}], "draw": {"deck": true}, "engine": "rounds", "mechanic": "experience", "rounds_setting": "cartes", "settings": {"cartes": {"default": 8, "label": "Nombre de cartes", "options": [8, 12]}}, "steps": [{"key": "answer", "kind": "yes_no", "skippable": true}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-003$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-004$n$, $n$complicite-confidences$n$, $n$prediction$n$, $n$Je mise sur ton choix$n$, $n$Tu crois connaître son choix ? Vérifie, sans faire de la différence un problème.$n$, $n$Tu crois connaître son choix ? Vérifie, sans faire de la différence un problème.$n$, $n$echange$n$, 3, 10, 'standard', 4, 'published', false,
    $n$playable$n$, true, true, array[]::text[], $n$/assets/jeux/vignettes/N2-004.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "DECK", "content_count": 80, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "choix privés puis révélation", "level_count": 0, "summary": {"end": "Pour les cartes ordinaires, 1 point par choix deviné ; sur les cartes +18, aucun score. Ne pas agréger les deux catégories.", "setup": "Tirer 8 cartes à trois propositions. Un joueur est la cible et l’autre prédit ; inverser au tour suivant.", "turn": "La cible choisit en privé, l’autre prédit. Révélation lorsque les deux confirment ; option « autre » accessible à la cible."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-004$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-004$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-004$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-004$n$), 0) + 1, $n${"details": ["1 point par choix deviné sur les cartes ordinaires ; aucun point sur les cartes +18.", "Une réponse « autre » annule le point de la carte.", "8 cartes."], "how_to": ["La personne ciblée choisit en privé (ou « autre »).", "L'autre prédit son choix.", "Révélation quand vous avez confirmé tous les deux."], "objective": "Je mise sur ton choix : l'un choisit, l'autre devine. Les rôles s'inversent à chaque carte.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"choice": {"confirm": "Confirmer mon choix", "hint": "« Autre » reste possible.", "prompt": "Que choisis-tu, toi ?", "title": "Ton choix"}, "guess": {"confirm": "Confirmer ma prédiction", "hint": "Un seul choix.", "prompt": "Que va choisir {name} ?", "title": "Ta prédiction"}}}$n$::jsonb, $n${"after": [], "draw": {"deck": true}, "engine": "rounds", "mechanic": "prediction", "roles": "alternate", "rounds": 8, "score": "prediction", "steps": [{"key": "choice", "kind": "choice", "params": {"extras": ["other"]}, "who": "a"}, {"key": "guess", "kind": "choice", "who": "b"}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["1 point par choix deviné sur les cartes ordinaires ; aucun point sur les cartes +18.", "Une réponse « autre » annule le point de la carte.", "8 cartes."], "how_to": ["La personne ciblée choisit en privé (ou « autre »).", "L'autre prédit son choix.", "Révélation quand vous avez confirmé tous les deux."], "objective": "Je mise sur ton choix : l'un choisit, l'autre devine. Les rôles s'inversent à chaque carte.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"choice": {"confirm": "Confirmer mon choix", "hint": "« Autre » reste possible.", "prompt": "Que choisis-tu, toi ?", "title": "Ton choix"}, "guess": {"confirm": "Confirmer ma prédiction", "hint": "Un seul choix.", "prompt": "Que va choisir {name} ?", "title": "Ta prédiction"}}}$n$::jsonb and cur.config = $n${"after": [], "draw": {"deck": true}, "engine": "rounds", "mechanic": "prediction", "roles": "alternate", "rounds": 8, "score": "prediction", "steps": [{"key": "choice", "kind": "choice", "params": {"extras": ["other"]}, "who": "a"}, {"key": "guess", "kind": "choice", "who": "b"}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-004$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-005$n$, $n$complicite-confidences$n$, $n$select_words$n$, $n$Cinq mots, vraiment toi$n$, $n$Un portrait en cinq vrais mots, sans adjectifs creux imposés.$n$, $n$Un portrait en cinq vrais mots, sans adjectifs creux imposés.$n$, $n$echange$n$, 3, 10, 'standard', 5, 'published', false,
    $n$playable$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-005.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 80, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "choix privés puis révélation", "level_count": 0, "summary": {"end": "Deux portraits sauvegardables séparément ; pas de bonne réponse.", "setup": "Afficher 20 mots issus du lexique Portrait ; chacun en choisit exactement 5 pour lui-même.", "turn": "Glisser les mots dans cinq emplacements ; possibilité d’écrire un mot personnel. Révéler puis entourer un mot qui surprend."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-005$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-005$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-005$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-005$n$), 0) + 1, $n${"details": ["Une seule relance de la liste, avant que quiconque ait répondu.", "Pas de bonne réponse, aucun diagnostic de personnalité."], "how_to": ["Vingt mots s'affichent ; choisis-en exactement cinq pour toi.", "Tu peux remplacer l'un d'eux par un mot à toi.", "Révélez, puis entoure un mot de l'autre qui te surprend."], "objective": "Choisis cinq mots qui te ressemblent vraiment, puis découvrez vos deux portraits.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"pick": {"confirm": "Valider mon portrait", "hint": "Un mot personnel possible (24 caractères).", "prompt": "Choisis 5 mots qui te ressemblent.", "title": "Ton portrait"}, "surprise": {"confirm": "Entourer ce mot", "hint": "Facultatif.", "prompt": "Touche un mot du portrait de {name}.", "title": "Un mot qui te surprend"}}}$n$::jsonb, $n${"after": [{"key": "surprise", "kind": "surprise", "params": {"from": "pick"}}], "draw": {"lists": [{"bank": "portrait", "count": 20, "key": "words"}]}, "engine": "rounds", "mechanic": "select_words", "rerolls": 1, "rounds": 1, "steps": [{"key": "pick", "kind": "pick", "params": {"custom_len": 24, "custom_max": 1, "list": "words", "max": 5, "min": 5}}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["Une seule relance de la liste, avant que quiconque ait répondu.", "Pas de bonne réponse, aucun diagnostic de personnalité."], "how_to": ["Vingt mots s'affichent ; choisis-en exactement cinq pour toi.", "Tu peux remplacer l'un d'eux par un mot à toi.", "Révélez, puis entoure un mot de l'autre qui te surprend."], "objective": "Choisis cinq mots qui te ressemblent vraiment, puis découvrez vos deux portraits.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"pick": {"confirm": "Valider mon portrait", "hint": "Un mot personnel possible (24 caractères).", "prompt": "Choisis 5 mots qui te ressemblent.", "title": "Ton portrait"}, "surprise": {"confirm": "Entourer ce mot", "hint": "Facultatif.", "prompt": "Touche un mot du portrait de {name}.", "title": "Un mot qui te surprend"}}}$n$::jsonb and cur.config = $n${"after": [{"key": "surprise", "kind": "surprise", "params": {"from": "pick"}}], "draw": {"lists": [{"bank": "portrait", "count": 20, "key": "words"}]}, "engine": "rounds", "mechanic": "select_words", "rerolls": 1, "rounds": 1, "steps": [{"key": "pick", "kind": "pick", "params": {"custom_len": 24, "custom_max": 1, "list": "words", "max": 5, "min": 5}}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-005$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-006$n$, $n$complicite-confidences$n$, $n$object_portrait$n$, $n$Le portrait en objets$n$, $n$Dire quelque chose de soi en choisissant des objets.$n$, $n$Dire quelque chose de soi en choisissant des objets.$n$, $n$echange$n$, 3, 10, 'standard', 6, 'published', false,
    $n$playable$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-006.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "choix privés puis révélation", "level_count": 0, "summary": {"end": "Les deux plateaux sont réunis dans une galerie ; 1 tour chacun.", "setup": "Présenter 16 illustrations du jeu d’objets ; chaque joueur prépare un plateau de 3 objets.", "turn": "Associer une courte légende à chaque objet ; l’autre lit le portrait après validation."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-006$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-006$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-006$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-006$n$), 0) + 1, $n${"details": ["Aucune signification psychologique n'est attribuée aux objets."], "how_to": ["Choisis trois objets parmi seize.", "Ajoute une légende à chacun (120 caractères) et une couleur de fond.", "Les deux plateaux s'affichent ensemble."], "objective": "Fais ton portrait en trois objets, chacun avec une courte légende.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"board": {"confirm": "Valider mon plateau", "hint": "Une légende courte pour chacun.", "prompt": "Trois objets qui parlent de toi.", "title": "Ton plateau"}}}$n$::jsonb, $n${"after": [], "draw": {"fixed": {"backgrounds": [{"hex": "#FFF5E8", "name": "crème"}, {"hex": "#A9D9C2", "name": "menthe"}, {"hex": "#F4D57A", "name": "jaune doux"}, {"hex": "#91BDD4", "name": "bleu"}, {"hex": "#C7B5E5", "name": "lilas"}, {"hex": "#F6C5A6", "name": "pêche"}]}, "lists": [{"bank": "objects", "count": 16, "key": "objects"}]}, "engine": "rounds", "mechanic": "object_portrait", "rounds": 1, "steps": [{"key": "board", "kind": "objects", "params": {"backgrounds": 6, "caption_max": 120, "count": 3}}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["Aucune signification psychologique n'est attribuée aux objets."], "how_to": ["Choisis trois objets parmi seize.", "Ajoute une légende à chacun (120 caractères) et une couleur de fond.", "Les deux plateaux s'affichent ensemble."], "objective": "Fais ton portrait en trois objets, chacun avec une courte légende.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"board": {"confirm": "Valider mon plateau", "hint": "Une légende courte pour chacun.", "prompt": "Trois objets qui parlent de toi.", "title": "Ton plateau"}}}$n$::jsonb and cur.config = $n${"after": [], "draw": {"fixed": {"backgrounds": [{"hex": "#FFF5E8", "name": "crème"}, {"hex": "#A9D9C2", "name": "menthe"}, {"hex": "#F4D57A", "name": "jaune doux"}, {"hex": "#91BDD4", "name": "bleu"}, {"hex": "#C7B5E5", "name": "lilas"}, {"hex": "#F6C5A6", "name": "pêche"}]}, "lists": [{"bank": "objects", "count": 16, "key": "objects"}]}, "engine": "rounds", "mechanic": "object_portrait", "rounds": 1, "steps": [{"key": "board", "kind": "objects", "params": {"backgrounds": 6, "caption_max": 120, "count": 3}}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-006$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-007$n$, $n$complicite-confidences$n$, $n$mood$n$, $n$La météo intérieure$n$, $n$Une petite scène pour montrer son état du jour sans faire un long discours.$n$, $n$Une petite scène pour montrer son état du jour sans faire un long discours.$n$, $n$echange$n$, 3, 10, 'standard', 7, 'published', false,
    $n$playable$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-007.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 14, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "choix privés puis révélation", "level_count": 0, "summary": {"end": "Un tableau du moment, sans historique automatique des humeurs.", "setup": "Chacun reçoit un ciel vierge, six symboles météo et huit mots d’énergie.", "turn": "Placer jusqu’à 3 symboles et un mot ; ajouter une note facultative. Révéler ensemble, puis envoyer une réaction choisie."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-007$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-007$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-007$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-007$n$), 0) + 1, $n${"details": ["Un tableau du moment, sans historique automatique.", "Les réactions ne corrigent pas le ressenti."], "how_to": ["Place jusqu'à trois symboles météo dans ton ciel.", "Choisis un mot d'énergie, ajoute une note facultative.", "Révélez ensemble, puis envoyez-vous une réaction."], "objective": "Montre ta météo du moment : quelques symboles, un mot d'énergie, une note si tu veux.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"reaction": {"confirm": "Envoyer", "hint": "Facultatif.", "prompt": "Envoie une réaction à {name}.", "title": "Réagir"}, "sky": {"confirm": "Valider ma météo", "hint": "1 à 3 symboles, 1 mot d'énergie.", "prompt": "Comment te sens-tu en ce moment ?", "title": "Ton ciel"}}}$n$::jsonb, $n${"after": [{"key": "reaction", "kind": "reaction", "params": {"max": 120, "options": ["Merci de me le dire", "Je suis là", "Courage pour la suite", "Ça me fait plaisir pour toi", "On en reparle quand tu veux", "Prends soin de toi"]}}], "draw": {"fixed": {"energies": ["posé", "dispersé", "curieux", "fatigué", "motivé", "tendu", "léger", "saturé"], "symbols": ["soleil", "nuage", "pluie", "éclair", "brume", "arc-en-ciel"]}}, "engine": "rounds", "mechanic": "mood", "rounds": 1, "steps": [{"key": "sky", "kind": "sky"}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["Un tableau du moment, sans historique automatique.", "Les réactions ne corrigent pas le ressenti."], "how_to": ["Place jusqu'à trois symboles météo dans ton ciel.", "Choisis un mot d'énergie, ajoute une note facultative.", "Révélez ensemble, puis envoyez-vous une réaction."], "objective": "Montre ta météo du moment : quelques symboles, un mot d'énergie, une note si tu veux.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"reaction": {"confirm": "Envoyer", "hint": "Facultatif.", "prompt": "Envoie une réaction à {name}.", "title": "Réagir"}, "sky": {"confirm": "Valider ma météo", "hint": "1 à 3 symboles, 1 mot d'énergie.", "prompt": "Comment te sens-tu en ce moment ?", "title": "Ton ciel"}}}$n$::jsonb and cur.config = $n${"after": [{"key": "reaction", "kind": "reaction", "params": {"max": 120, "options": ["Merci de me le dire", "Je suis là", "Courage pour la suite", "Ça me fait plaisir pour toi", "On en reparle quand tu veux", "Prends soin de toi"]}}], "draw": {"fixed": {"energies": ["posé", "dispersé", "curieux", "fatigué", "motivé", "tendu", "léger", "saturé"], "symbols": ["soleil", "nuage", "pluie", "éclair", "brume", "arc-en-ciel"]}}, "engine": "rounds", "mechanic": "mood", "rounds": 1, "steps": [{"key": "sky", "kind": "sky"}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-007$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-008$n$, $n$complicite-confidences$n$, $n$rank$n$, $n$Tes cinq priorités du moment$n$, $n$Mettre de l’ordre dans ce qui compte aujourd’hui, sans comparer des vies.$n$, $n$Mettre de l’ordre dans ce qui compte aujourd’hui, sans comparer des vies.$n$, $n$echange$n$, 3, 10, 'standard', 8, 'published', false,
    $n$playable$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-008.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "choix privés puis révélation", "level_count": 0, "summary": {"end": "Une photo du moment, sans score ; les priorités peuvent changer à chaque partie.", "setup": "Tirer 10 cartes Valeurs ; chacun choisit 5 cartes et les classe.", "turn": "Valider l’ordre en privé ; révéler les deux colonnes. Chacun peut annoter son premier choix."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-008$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-008$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-008$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-008$n$), 0) + 1, $n${"details": ["Une photo du moment, sans score : les priorités changent.", "Une différence ne dit rien de votre compatibilité."], "how_to": ["Dix valeurs s'affichent ; choisis-en cinq et classe-les.", "Annote ton premier choix si tu veux.", "Les deux colonnes s'affichent ensemble."], "objective": "Tes cinq priorités du moment, classées de 1 à 5.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"rank": {"confirm": "Valider mon classement", "hint": "La première est la plus importante en ce moment.", "prompt": "Choisis 5 valeurs dans l'ordre.", "title": "Tes priorités"}}}$n$::jsonb, $n${"after": [], "draw": {"lists": [{"bank": "values", "count": 10, "key": "values"}]}, "engine": "rounds", "mechanic": "rank", "rounds": 1, "steps": [{"key": "rank", "kind": "pick", "params": {"list": "values", "max": 5, "min": 5, "note_max": 120, "ordered": true}}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["Une photo du moment, sans score : les priorités changent.", "Une différence ne dit rien de votre compatibilité."], "how_to": ["Dix valeurs s'affichent ; choisis-en cinq et classe-les.", "Annote ton premier choix si tu veux.", "Les deux colonnes s'affichent ensemble."], "objective": "Tes cinq priorités du moment, classées de 1 à 5.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"rank": {"confirm": "Valider mon classement", "hint": "La première est la plus importante en ce moment.", "prompt": "Choisis 5 valeurs dans l'ordre.", "title": "Tes priorités"}}}$n$::jsonb and cur.config = $n${"after": [], "draw": {"lists": [{"bank": "values", "count": 10, "key": "values"}]}, "engine": "rounds", "mechanic": "rank", "rounds": 1, "steps": [{"key": "rank", "kind": "pick", "params": {"list": "values", "max": 5, "min": 5, "note_max": 120, "ordered": true}}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-008$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-009$n$, $n$complicite-confidences$n$, $n$appreciation$n$, $n$Le compliment précis$n$, $n$Remplacer le compliment automatique par un détail que tu as vraiment remarqué.$n$, $n$Remplacer le compliment automatique par un détail que tu as vraiment remarqué.$n$, $n$echange$n$, 3, 10, 'standard', 9, 'published', false,
    $n$playable$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-009.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Un échange de deux cartes ; export seulement de sa propre carte ou avec accord.", "setup": "Choisir une amorce parmi 24 ; écrire pour l’autre à partir d’un fait observé.", "turn": "Compléter une phrase avec un exemple concret ; l’autre reçoit une carte et peut simplement répondre « Reçu »."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-009$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-009$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-009$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-009$n$), 0) + 1, $n${"details": ["Si vous vous connaissez peu, appuyez-vous sur un détail de cette partie : rien d'inventé.", "Export de sa propre carte uniquement, ou avec l'accord des deux."], "how_to": ["Choisis une amorce.", "Complète-la avec un exemple concret (280 caractères).", "Vous recevez vos cartes en même temps ; « Reçu » suffit comme réponse."], "objective": "Un compliment précis, fondé sur un fait observé.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"received": {"confirm": "Envoyer", "hint": "« Reçu » suffit.", "prompt": "Un mot pour {name} ?", "title": "Répondre"}, "write": {"confirm": "Envoyer ma carte", "hint": "280 caractères au plus.", "prompt": "Pour {name}, à partir d'un fait observé.", "title": "Ton compliment"}}}$n$::jsonb, $n${"after": [{"key": "received", "kind": "reaction", "params": {"max": 120, "options": ["Reçu", "Merci", "Ça me touche"]}}], "draw": {"lists": [{"bank": "appreciation", "count": 6, "key": "prompts"}]}, "engine": "rounds", "mechanic": "appreciation", "rounds_setting": "cartes", "settings": {"cartes": {"default": 1, "label": "Nombre de cartes", "options": [1, 3]}}, "steps": [{"key": "write", "kind": "share", "params": {"list": "prompts", "max": 280}}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["Si vous vous connaissez peu, appuyez-vous sur un détail de cette partie : rien d'inventé.", "Export de sa propre carte uniquement, ou avec l'accord des deux."], "how_to": ["Choisis une amorce.", "Complète-la avec un exemple concret (280 caractères).", "Vous recevez vos cartes en même temps ; « Reçu » suffit comme réponse."], "objective": "Un compliment précis, fondé sur un fait observé.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"received": {"confirm": "Envoyer", "hint": "« Reçu » suffit.", "prompt": "Un mot pour {name} ?", "title": "Répondre"}, "write": {"confirm": "Envoyer ma carte", "hint": "280 caractères au plus.", "prompt": "Pour {name}, à partir d'un fait observé.", "title": "Ton compliment"}}}$n$::jsonb and cur.config = $n${"after": [{"key": "received", "kind": "reaction", "params": {"max": 120, "options": ["Reçu", "Merci", "Ça me touche"]}}], "draw": {"lists": [{"bank": "appreciation", "count": 6, "key": "prompts"}]}, "engine": "rounds", "mechanic": "appreciation", "rounds_setting": "cartes", "settings": {"cartes": {"default": 1, "label": "Nombre de cartes", "options": [1, 3]}}, "steps": [{"key": "write", "kind": "share", "params": {"list": "prompts", "max": 280}}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-009$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-010$n$, $n$complicite-confidences$n$, $n$listening$n$, $n$Je t’ai bien compris$n$, $n$Un court exercice de reformulation avec le droit de corriger.$n$, $n$Un court exercice de reformulation avec le droit de corriger.$n$, $n$echange$n$, 3, 10, 'standard', 10, 'published', false,
    $n$playable$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-010.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Terminer après un passage chacun ; aucune note de qualité de l’écoute.", "setup": "La personne qui commence choisit un thème léger et écrit jusqu’à 500 caractères.", "turn": "L’autre reformule en 250 caractères sans conseil. L’auteur clique « Oui, c’est ça » ou modifie une nuance ; inverser les rôles."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-010$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-010$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-010$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-010$n$), 0) + 1, $n${"details": ["Un passage chacun ; aucune note sur la qualité de l'écoute.", "Les sujets graves n'ont pas leur place ici ; « Quitter » reste toujours visible."], "how_to": ["La personne qui commence choisit un thème léger et écrit (500 caractères).", "L'autre reformule en 250 caractères, sans conseil.", "L'auteur répond « Oui, c'est ça » ou précise une nuance.", "Puis les rôles s'inversent."], "objective": "Je t'ai bien compris : l'un raconte, l'autre reformule sans conseiller.", "privacy": "Le récit et la reformulation s'affichent dès qu'ils sont envoyés : c'est le principe du jeu.", "step_texts": {"confirm": {"confirm": "Répondre", "hint": "Tu peux préciser une nuance.", "prompt": "{name} a-t-il ou a-t-elle bien compris ?", "title": "C'est bien ça ?"}, "reformulate": {"confirm": "Envoyer ma reformulation", "hint": "Sans conseil, 250 caractères.", "prompt": "Redis avec tes mots ce que {name} a raconté.", "title": "Reformule"}, "share": {"confirm": "Envoyer", "hint": "500 caractères au plus.", "prompt": "Choisis un thème et raconte.", "title": "Raconte"}}}$n$::jsonb, $n${"after": [], "draw": {"lists": [{"bank": "small_topics", "count": 4, "key": "topics"}]}, "engine": "rounds", "mechanic": "listening", "roles": "alternate", "rounds": 2, "steps": [{"key": "share", "kind": "share", "params": {"list": "topics", "max": 500}, "visible": "immediate", "who": "a"}, {"after": "share", "key": "reformulate", "kind": "text", "params": {"max": 250}, "visible": "immediate", "who": "b"}, {"after": "reformulate", "key": "confirm", "kind": "confirm", "visible": "immediate", "who": "a"}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["Un passage chacun ; aucune note sur la qualité de l'écoute.", "Les sujets graves n'ont pas leur place ici ; « Quitter » reste toujours visible."], "how_to": ["La personne qui commence choisit un thème léger et écrit (500 caractères).", "L'autre reformule en 250 caractères, sans conseil.", "L'auteur répond « Oui, c'est ça » ou précise une nuance.", "Puis les rôles s'inversent."], "objective": "Je t'ai bien compris : l'un raconte, l'autre reformule sans conseiller.", "privacy": "Le récit et la reformulation s'affichent dès qu'ils sont envoyés : c'est le principe du jeu.", "step_texts": {"confirm": {"confirm": "Répondre", "hint": "Tu peux préciser une nuance.", "prompt": "{name} a-t-il ou a-t-elle bien compris ?", "title": "C'est bien ça ?"}, "reformulate": {"confirm": "Envoyer ma reformulation", "hint": "Sans conseil, 250 caractères.", "prompt": "Redis avec tes mots ce que {name} a raconté.", "title": "Reformule"}, "share": {"confirm": "Envoyer", "hint": "500 caractères au plus.", "prompt": "Choisis un thème et raconte.", "title": "Raconte"}}}$n$::jsonb and cur.config = $n${"after": [], "draw": {"lists": [{"bank": "small_topics", "count": 4, "key": "topics"}]}, "engine": "rounds", "mechanic": "listening", "roles": "alternate", "rounds": 2, "steps": [{"key": "share", "kind": "share", "params": {"list": "topics", "max": 500}, "visible": "immediate", "who": "a"}, {"after": "share", "key": "reformulate", "kind": "text", "params": {"max": 250}, "visible": "immediate", "who": "b"}, {"after": "reformulate", "key": "confirm", "kind": "confirm", "visible": "immediate", "who": "a"}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-010$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-011$n$, $n$complicite-confidences$n$, $n$timeline_personal$n$, $n$La frise de tes moments$n$, $n$Assembler trois souvenirs personnels dans un ordre choisi.$n$, $n$Assembler trois souvenirs personnels dans un ordre choisi.$n$, $n$echange$n$, 3, 10, 'standard', 11, 'published', false,
    $n$playable$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-011.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Deux frises personnelles, puis une carte libre ajoutée ensemble.", "setup": "Trois cartes vides : un moment drôle, un tournant, une petite victoire.", "turn": "Écrire un titre et une phrase ; placer les cartes dans l’ordre chronologique ou émotionnel annoncé. Révéler sa frise."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-011$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-011$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-011$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-011$n$), 0) + 1, $n${"details": ["Aucun passé commun n'est présumé.", "Dates facultatives."], "how_to": ["Écris un titre et une phrase pour chacune des trois cartes.", "Range-les dans l'ordre chronologique ou émotionnel.", "Révélez vos frises, puis ajoutez ensemble une carte libre."], "objective": "La frise de tes moments : trois cartes, un titre et une phrase chacune.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"frise": {"confirm": "Valider ma frise", "hint": "Titre de 40 caractères, phrase de 160.", "prompt": "Trois moments à toi.", "title": "Ta frise"}, "shared": {"confirm": "Ajouter", "hint": "160 caractères.", "prompt": "Ajoute ta ligne à la carte commune.", "title": "La carte commune"}}}$n$::jsonb, $n${"after": [{"key": "shared", "kind": "reaction", "params": {"max": 160}}], "draw": {"lists": [{"bank": "memory_prompts", "count": 3, "key": "prompts"}]}, "engine": "rounds", "mechanic": "timeline_personal", "rounds": 1, "steps": [{"key": "frise", "kind": "frise"}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["Aucun passé commun n'est présumé.", "Dates facultatives."], "how_to": ["Écris un titre et une phrase pour chacune des trois cartes.", "Range-les dans l'ordre chronologique ou émotionnel.", "Révélez vos frises, puis ajoutez ensemble une carte libre."], "objective": "La frise de tes moments : trois cartes, un titre et une phrase chacune.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"frise": {"confirm": "Valider ma frise", "hint": "Titre de 40 caractères, phrase de 160.", "prompt": "Trois moments à toi.", "title": "Ta frise"}, "shared": {"confirm": "Ajouter", "hint": "160 caractères.", "prompt": "Ajoute ta ligne à la carte commune.", "title": "La carte commune"}}}$n$::jsonb and cur.config = $n${"after": [{"key": "shared", "kind": "reaction", "params": {"max": 160}}], "draw": {"lists": [{"bank": "memory_prompts", "count": 3, "key": "prompts"}]}, "engine": "rounds", "mechanic": "timeline_personal", "rounds": 1, "steps": [{"key": "frise", "kind": "frise"}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-011$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-012$n$, $n$complicite-confidences$n$, $n$capsule$n$, $n$La capsule à rouvrir$n$, $n$Garder une envie et une prédiction pour les relire plus tard.$n$, $n$Garder une envie et une prédiction pour les relire plus tard.$n$, $n$echange$n$, 3, 10, 'standard', 12, 'published', false,
    $n$playable$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-012.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "La capsule devient consultable dans Notre espace à la date choisie ; notification seulement si activée.", "setup": "Chacun remplit trois champs : envie, petite action, prédiction légère.", "turn": "Choisir une date de réouverture à 7, 30 ou 90 jours ; valider le partage de chaque champ."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-012$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-012$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-012$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-012$n$), 0) + 1, $n${"details": ["Un champ gardé pour toi n'est jamais montré à l'autre.", "La capsule reste conservée jusqu'à sa réouverture ; elle disparaît si le duo la supprime."], "how_to": ["Remplis les trois champs (180 caractères chacun).", "Choisis pour chaque champ s'il sera partagé.", "La capsule s'ouvre dans l'Espace à la date choisie (7, 30 ou 90 jours)."], "objective": "Une capsule à rouvrir plus tard : une envie, une petite action, une prédiction légère.", "privacy": "Rien n'est visible avant la date de réouverture ; les champs non partagés restent à toi.", "step_texts": {"capsule": {"confirm": "Fermer la capsule", "hint": "Coche « partager » pour chaque champ à montrer.", "prompt": "À rouvrir plus tard.", "title": "Ta capsule"}}}$n$::jsonb, $n${"after": [], "draw": {"fixed": {"fields": ["Une envie", "Une petite action", "Une prédiction légère"]}, "lists": [{"bank": "capsule", "count": 3, "key": "ideas"}]}, "engine": "rounds", "mechanic": "capsule", "reveal": "capsule", "rounds": 1, "settings": {"delai": {"default": 30, "label": "Réouverture dans (jours)", "options": [7, 30, 90]}}, "steps": [{"key": "capsule", "kind": "fields", "params": {"count": 3, "max": 180}}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["Un champ gardé pour toi n'est jamais montré à l'autre.", "La capsule reste conservée jusqu'à sa réouverture ; elle disparaît si le duo la supprime."], "how_to": ["Remplis les trois champs (180 caractères chacun).", "Choisis pour chaque champ s'il sera partagé.", "La capsule s'ouvre dans l'Espace à la date choisie (7, 30 ou 90 jours)."], "objective": "Une capsule à rouvrir plus tard : une envie, une petite action, une prédiction légère.", "privacy": "Rien n'est visible avant la date de réouverture ; les champs non partagés restent à toi.", "step_texts": {"capsule": {"confirm": "Fermer la capsule", "hint": "Coche « partager » pour chaque champ à montrer.", "prompt": "À rouvrir plus tard.", "title": "Ta capsule"}}}$n$::jsonb and cur.config = $n${"after": [], "draw": {"fixed": {"fields": ["Une envie", "Une petite action", "Une prédiction légère"]}, "lists": [{"bank": "capsule", "count": 3, "key": "ideas"}]}, "engine": "rounds", "mechanic": "capsule", "reveal": "capsule", "rounds": 1, "settings": {"delai": {"default": 30, "label": "Réouverture dans (jours)", "options": [7, 30, 90]}}, "steps": [{"key": "capsule", "kind": "fields", "params": {"count": 3, "max": 180}}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-012$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-013$n$, $n$complicite-confidences$n$, $n$budget$n$, $n$Douze jetons d’envie$n$, $n$Composer une prochaine soirée virtuelle avec un vrai petit arbitrage.$n$, $n$Composer une prochaine soirée virtuelle avec un vrai petit arbitrage.$n$, $n$echange$n$, 3, 10, 'standard', 13, 'published', false,
    $n$playable$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-013.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Une proposition commune ; cela ne réserve ni ne paie rien.", "setup": "12 jetons fictifs chacun ; 12 activités ont un coût de 1 à 4.", "turn": "Acheter jusqu’à 4 cartes sans dépasser 12 ; révéler puis retenir une combinaison commune de 12 maximum."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-013$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-013$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-013$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-013$n$), 0) + 1, $n${"details": ["Les jetons sont des unités de jeu : ni monnaie, ni achat, ni réservation.", "Une révision par personne."], "how_to": ["Chacun dispose de 12 jetons fictifs.", "Achète jusqu'à 4 activités sans dépasser 12.", "Révélez, puis proposez chacun une combinaison commune (12 jetons au plus).", "Quand vos deux propositions sont identiques, l'accord est trouvé."], "objective": "Douze jetons d'envie : composez une proposition commune.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"buy": {"confirm": "Valider mes choix", "hint": "4 activités au plus.", "prompt": "Dépense jusqu'à 12 jetons.", "title": "Tes envies"}, "common": {"confirm": "Proposer", "hint": "12 jetons au plus ; une révision chacun.", "prompt": "Parmi vos choix, composez ensemble.", "title": "Proposition commune"}}}$n$::jsonb, $n${"after": [{"key": "common", "kind": "common", "params": {"budget": 12, "from": "buy"}, "revisions": 1}], "draw": {"fixed": {"budget": 12}, "lists": [{"bank": "date_menu", "count": null, "key": "activities"}]}, "engine": "rounds", "mechanic": "budget", "rounds": 1, "steps": [{"key": "buy", "kind": "buy", "params": {"budget": 12, "max_items": 4}}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["Les jetons sont des unités de jeu : ni monnaie, ni achat, ni réservation.", "Une révision par personne."], "how_to": ["Chacun dispose de 12 jetons fictifs.", "Achète jusqu'à 4 activités sans dépasser 12.", "Révélez, puis proposez chacun une combinaison commune (12 jetons au plus).", "Quand vos deux propositions sont identiques, l'accord est trouvé."], "objective": "Douze jetons d'envie : composez une proposition commune.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"buy": {"confirm": "Valider mes choix", "hint": "4 activités au plus.", "prompt": "Dépense jusqu'à 12 jetons.", "title": "Tes envies"}, "common": {"confirm": "Proposer", "hint": "12 jetons au plus ; une révision chacun.", "prompt": "Parmi vos choix, composez ensemble.", "title": "Proposition commune"}}}$n$::jsonb and cur.config = $n${"after": [{"key": "common", "kind": "common", "params": {"budget": 12, "from": "buy"}, "revisions": 1}], "draw": {"fixed": {"budget": 12}, "lists": [{"bank": "date_menu", "count": null, "key": "activities"}]}, "engine": "rounds", "mechanic": "budget", "rounds": 1, "steps": [{"key": "buy", "kind": "buy", "params": {"budget": 12, "max_items": 4}}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-013$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-014$n$, $n$complicite-confidences$n$, $n$scene_builder$n$, $n$Votre coin tranquille$n$, $n$Composer un décor qui donne envie de rester discuter.$n$, $n$Composer un décor qui donne envie de rester discuter.$n$, $n$echange$n$, 3, 10, 'standard', 14, 'published', false,
    $n$playable$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-014.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 20, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Une scène commune exportable ; pas de gagnant.", "setup": "Une scène vide et 20 objets de décor, cinq éclairages et six ambiances nommées.", "turn": "Chacun place 3 objets sur sa moitié puis propose un éclairage commun ; déplacer par toucher puis case."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-014$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-014$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-014$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-014$n$), 0) + 1, $n${"details": ["Une scène de jeu, pas un projet de vie commune.", "Pas de gagnant."], "how_to": ["Chacun place trois objets sur sa moitié de la scène (toucher l'objet, puis la case).", "Chacun propose un éclairage et une ambiance.", "Révélez la scène, puis choisissez ensemble l'une des deux propositions."], "objective": "Votre coin tranquille : un petit décor composé à deux.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"agree": {"confirm": "Choisir", "hint": "Choisissez la même pour vous accorder.", "prompt": "Quelle proposition gardez-vous ?", "title": "L'ambiance commune"}, "light": {"confirm": "Proposer", "hint": "", "prompt": "Propose un éclairage et une ambiance.", "title": "L'ambiance"}, "place": {"confirm": "Valider mes objets", "hint": "Touche un objet, puis une case de ta moitié.", "prompt": "Place trois objets.", "title": "Ta moitié"}}}$n$::jsonb, $n${"after": [{"key": "agree", "kind": "agree", "revisions": 2}], "draw": {"fixed": {"ambiances": ["calme", "lecture", "musique douce", "fête légère", "rêverie", "matin tranquille"], "grid": {"cols": 6, "rows": 4}, "lights": ["lumière du jour", "lampe douce", "guirlande", "bougies virtuelles", "pénombre"]}, "lists": [{"bank": "decor", "count": null, "key": "objects"}]}, "engine": "rounds", "mechanic": "scene_builder", "rounds": 1, "steps": [{"key": "place", "kind": "place", "params": {"count": 3}}, {"key": "light", "kind": "light"}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["Une scène de jeu, pas un projet de vie commune.", "Pas de gagnant."], "how_to": ["Chacun place trois objets sur sa moitié de la scène (toucher l'objet, puis la case).", "Chacun propose un éclairage et une ambiance.", "Révélez la scène, puis choisissez ensemble l'une des deux propositions."], "objective": "Votre coin tranquille : un petit décor composé à deux.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"agree": {"confirm": "Choisir", "hint": "Choisissez la même pour vous accorder.", "prompt": "Quelle proposition gardez-vous ?", "title": "L'ambiance commune"}, "light": {"confirm": "Proposer", "hint": "", "prompt": "Propose un éclairage et une ambiance.", "title": "L'ambiance"}, "place": {"confirm": "Valider mes objets", "hint": "Touche un objet, puis une case de ta moitié.", "prompt": "Place trois objets.", "title": "Ta moitié"}}}$n$::jsonb and cur.config = $n${"after": [{"key": "agree", "kind": "agree", "revisions": 2}], "draw": {"fixed": {"ambiances": ["calme", "lecture", "musique douce", "fête légère", "rêverie", "matin tranquille"], "grid": {"cols": 6, "rows": 4}, "lights": ["lumière du jour", "lampe douce", "guirlande", "bougies virtuelles", "pénombre"]}, "lists": [{"bank": "decor", "count": null, "key": "objects"}]}, "engine": "rounds", "mechanic": "scene_builder", "rounds": 1, "steps": [{"key": "place", "kind": "place", "params": {"count": 3}}, {"key": "light", "kind": "light"}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-014$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-015$n$, $n$complicite-confidences$n$, $n$attention$n$, $n$La roue des petits gestes$n$, $n$Envoyer une petite attention réalisable dans la session.$n$, $n$Envoyer une petite attention réalisable dans la session.$n$, $n$echange$n$, 3, 10, 'standard', 15, 'published', false,
    $n$playable$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-015.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Une carte par personne, jamais de dette ni de gage en retour.", "setup": "La roue tire une action parmi 24 ; bouton changer illimité.", "turn": "Réaliser par texte, dessin ou réaction dans l’app ; l’autre reçoit et peut rendre une attention différente."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-015$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-015$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-015$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-015$n$), 0) + 1, $n${"details": ["Une carte chacun, jamais de dette ni de gage.", "Aucune action ne demande contact physique, dépense ni média intime."], "how_to": ["Fais tourner la roue ; change d'action autant que tu veux.", "Réalise-la par un texte ou un dessin.", "L'autre la reçoit et peut rendre une attention différente."], "objective": "La roue des petits gestes : une attention à réaliser dans l'app.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"gesture": {"confirm": "Envoyer mon attention", "hint": "Texte (280 caractères) ou dessin.", "prompt": "Réalise l'action tirée.", "title": "Ton attention"}, "return": {"confirm": "Envoyer", "hint": "Facultatif.", "prompt": "Un mot en retour ?", "title": "Rendre une attention"}}}$n$::jsonb, $n${"after": [{"key": "return", "kind": "reaction", "params": {"max": 200}}], "draw": {"lists": [{"bank": "attentions", "count": null, "key": "actions"}]}, "engine": "rounds", "mechanic": "attention", "rounds": 1, "steps": [{"key": "gesture", "kind": "gesture"}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["Une carte chacun, jamais de dette ni de gage.", "Aucune action ne demande contact physique, dépense ni média intime."], "how_to": ["Fais tourner la roue ; change d'action autant que tu veux.", "Réalise-la par un texte ou un dessin.", "L'autre la reçoit et peut rendre une attention différente."], "objective": "La roue des petits gestes : une attention à réaliser dans l'app.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"gesture": {"confirm": "Envoyer mon attention", "hint": "Texte (280 caractères) ou dessin.", "prompt": "Réalise l'action tirée.", "title": "Ton attention"}, "return": {"confirm": "Envoyer", "hint": "Facultatif.", "prompt": "Un mot en retour ?", "title": "Rendre une attention"}}}$n$::jsonb and cur.config = $n${"after": [{"key": "return", "kind": "reaction", "params": {"max": 200}}], "draw": {"lists": [{"bank": "attentions", "count": null, "key": "actions"}]}, "engine": "rounds", "mechanic": "attention", "rounds": 1, "steps": [{"key": "gesture", "kind": "gesture"}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-015$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-016$n$, $n$mots-repartie$n$, $n$taboo$n$, $n$Le mot interdit$n$, $n$Faire deviner « valise » sans prononcer « voyage », « bagage » ni « roulettes ».$n$, $n$Faire deviner « valise » sans prononcer « voyage », « bagage » ni « roulettes ».$n$, $n$cooperation$n$, 3, 10, 'standard', 16, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-016.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "1 point commun si trouvé ; 6 cibles en alternant les rôles.", "setup": "Tirer une cible et trois mots interdits ; seul l’émetteur les voit.", "turn": "Écrire jusqu’à trois indices ; l’autre propose au plus 3 réponses. Valider par lexique normalisé."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-016$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-017$n$, $n$mots-repartie$n$, $n$anagram$n$, $n$L’anagramme partagée$n$, $n$Les bonnes lettres, dans le mauvais ordre.$n$, $n$Les bonnes lettres, dans le mauvais ordre.$n$, $n$cooperation$n$, 3, 10, 'standard', 17, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-017.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 100, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Réussite au premier mot valide de même longueur ; 5 manches, temps seulement informatif.", "setup": "Même paquet de lettres pour les deux, mot de 4 à 8 lettres issu du lexique fourni.", "turn": "Déplacer les lettres ; chacun peut proposer un mot. Le serveur compare au groupe d’anagrammes accepté."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-017$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-018$n$, $n$mots-repartie$n$, $n$categories$n$, $n$La lettre et la case$n$, $n$Un petit bac à deux avec des catégories concrètes.$n$, $n$Un petit bac à deux avec des catégories concrètes.$n$, $n$duel$n$, 3, 10, 'standard', 18, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-018.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "1 point par mot accepté ; même réponse des deux : 1 point chacun, sans pénalité.", "setup": "Une lettre parmi C, P, S, T et quatre catégories du lot.", "turn": "Rédiger un mot par case ; valider ensemble. Lexique embarqué pour les exemples, arbitrage mutuel pour un mot hors liste."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-018$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-019$n$, $n$mots-repartie$n$, $n$word_chain$n$, $n$La chaîne des dernières lettres$n$, $n$La fin de ton mot devient le début du mien.$n$, $n$La fin de ton mot devient le début du mien.$n$, $n$cooperation$n$, 3, 10, 'standard', 19, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-019.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 39, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "12 mots partagés ou deux passes successives ; score commun = mots valides.", "setup": "Un mot de départ et une réserve fermée de mots disponibles.", "turn": "Écrire un mot commençant par la dernière lettre du précédent ; aucun doublon dans la manche."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-019$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-020$n$, $n$mots-repartie$n$, $n$convergence$n$, $n$Le mot en commun$n$, $n$Deux mots différents au départ, une association commune à trouver.$n$, $n$Deux mots différents au départ, une association commune à trouver.$n$, $n$cooperation$n$, 3, 10, 'standard', 20, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-020.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "choix privés puis révélation", "level_count": 0, "summary": {"end": "Réussite si les deux mots normalisés coïncident ; aucun chronomètre.", "setup": "Tirer une paire ; chacun écrit secrètement un mot qui relie les deux.", "turn": "Révéler. Si différents, ils remplacent la paire précédente ; recommencer au plus 5 fois."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-020$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-021$n$, $n$mots-repartie$n$, $n$word_ladder$n$, $n$L’échelle de mots$n$, $n$Changer une lettre à la fois pour atteindre un autre mot.$n$, $n$Changer une lettre à la fois pour atteindre un autre mot.$n$, $n$cooperation$n$, 3, 10, 'standard', 21, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-021.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 6, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Atteindre la cible ; afficher nombre de pas et plus court chemin après la fin.", "setup": "Afficher deux mots reliés par un chemin du lexique contrôlé.", "turn": "Remplacer exactement une lettre ; chaque intermédiaire doit être dans le graphe fourni."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-021$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-022$n$, $n$mots-repartie$n$, $n$word_search$n$, $n$Les mots cachés$n$, $n$Retrouver des mots dans une petite grille tactile.$n$, $n$Retrouver des mots dans une petite grille tactile.$n$, $n$cooperation$n$, 3, 10, 'standard', 22, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-022.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 100, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Tous les mots trouvés ; score commun en nombre de sélections exactes.", "setup": "Grille 6x6 avec 5 mots de 3 à 6 lettres, liste visible.", "turn": "Toucher première puis dernière lettre sur une ligne droite. Directions horizontale et verticale, inversées admises."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-022$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-023$n$, $n$mots-repartie$n$, $n$masked_word$n$, $n$Le mot masqué$n$, $n$Trouver le mot sans dessin de pendu ni pression inutile.$n$, $n$Trouver le mot sans dessin de pendu ni pression inutile.$n$, $n$cooperation$n$, 3, 10, 'standard', 23, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-023.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 100, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Trouver avant 6 erreurs ; 5 manches, alternance de la première proposition.", "setup": "Une cible de 4 à 8 lettres ; ses lettres sont masquées, thème affiché.", "turn": "Proposer une lettre ou le mot ; bonne lettre révèle toutes ses positions."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-023$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-024$n$, $n$mots-repartie$n$, $n$syllables$n$, $n$Les syllabes en vrac$n$, $n$Recomposer un mot avec des fragments qui sonnent juste.$n$, $n$Recomposer un mot avec des fragments qui sonnent juste.$n$, $n$cooperation$n$, 3, 10, 'standard', 24, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-024.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Réponse exacte ; 5 manches sans pénalité pour les essais.", "setup": "Tirer un mot découpé manuellement en 2 à 4 fragments ; mélanger.", "turn": "Réordonner par boutons déplacer à gauche/droite ou glisser ; valider une fois satisfait."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-024$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-025$n$, $n$mots-repartie$n$, $n$letter_market$n$, $n$Le marché des lettres$n$, $n$Acheter les lettres utiles avant de composer le meilleur mot.$n$, $n$Acheter les lettres utiles avant de composer le meilleur mot.$n$, $n$duel$n$, 3, 10, 'standard', 25, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-025.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 100, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Score = longueur du mot, égalité partagée ; 3 manches.", "setup": "Chaque joueur reçoit A,E,I,O,R,S,T,N et 8 jetons ; 8 lettres coûtant 1 ou 2 sont au marché.", "turn": "Acheter à tour de rôle au plus 3 lettres ; former un seul mot du lexique livré, chaque lettre consommée une fois."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-025$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-026$n$, $n$mots-repartie$n$, $n$semantic_intruder$n$, $n$Le mot intrus$n$, $n$Un mot a changé de rayon : à vous de retrouver la logique.$n$, $n$Un mot a changé de rayon : à vous de retrouver la logique.$n$, $n$duel$n$, 3, 10, 'standard', 26, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-026.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "1 point par réponse juste ; 8 manches.", "setup": "Afficher 4 mots et une famille annoncée ; un seul ne correspond pas au critère explicite.", "turn": "Choisir l’intrus en secret puis révéler une justification déjà rédigée."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-026$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-027$n$, $n$mots-repartie$n$, $n$telegram$n$, $n$Le télégramme$n$, $n$Faire passer une scène avec cinq mots seulement.$n$, $n$Faire passer une scène avec cinq mots seulement.$n$, $n$cooperation$n$, 3, 10, 'standard', 27, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-027.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Validation subjective par l’auteur, sans score automatique de sens.", "setup": "Un joueur reçoit une scène ; il écrit exactement cinq mots, sans le mot cible.", "turn": "L’autre écrit une phrase qui reconstruit la scène ; révéler puis inverser."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-027$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-028$n$, $n$mots-repartie$n$, $n$rhymes$n$, $n$Rimes en relais$n$, $n$Composer une chaîne qui sonne, même quand le sens part de travers.$n$, $n$Composer une chaîne qui sonne, même quand le sens part de travers.$n$, $n$cooperation$n$, 3, 10, 'standard', 28, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-028.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "8 mots valides ou deux passes ; résultat collectif.", "setup": "Une terminaison parmi 8 et une liste de mots admis dans la session.", "turn": "Ajouter un mot de la famille sonore sans répétition, puis facultativement une phrase."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-028$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-029$n$, $n$mots-repartie$n$, $n$clue_grid$n$, $n$Un indice, trois cibles$n$, $n$Un indice bien choisi doit rapprocher trois mots d’un plateau.$n$, $n$Un indice bien choisi doit rapprocher trois mots d’un plateau.$n$, $n$cooperation$n$, 3, 10, 'standard', 29, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-029.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 100, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Réussite si les 3 cibles sont trouvées en 3 tours maximum.", "setup": "12 mots visibles ; le donneur voit 3 cibles, 8 neutres, 1 piège.", "turn": "Donner un seul mot d’indice et le nombre 3 ; l’autre sélectionne jusqu’à 3 mots. Une carte neutre arrête le tour, le piège finit la manche."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-029$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-030$n$, $n$mots-repartie$n$, $n$sentence_order$n$, $n$La phrase coupée$n$, $n$Remettre de l’ordre dans une phrase qui a perdu sa place.$n$, $n$Remettre de l’ordre dans une phrase qui a perdu sa place.$n$, $n$cooperation$n$, 3, 10, 'standard', 30, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-030.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Phrase source reconstituée ou autre ordre accepté par les deux ; révéler la source après 10 coups.", "setup": "Une phrase de 5 à 9 groupes édités ; fragments mélangés.", "turn": "Chacun propose un déplacement alternativement ; l’ordre est partagé."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-030$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-031$n$, $n$dessin-creation$n$, $n$draw_guess$n$, $n$Dessine, je devine$n$, $n$Même trois traits peuvent suffire pour faire reconnaître une idée.$n$, $n$Même trois traits peuvent suffire pour faire reconnaître une idée.$n$, $n$cooperation$n$, 3, 10, 'standard', 31, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-031.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "1 point commun si le mot est trouvé ; 6 tours.", "setup": "Cible concrète de la banque Objets ; un écran canvas, l’autre écran de réponses.", "turn": "Dessiner sans écrire de lettres ; 3 propositions de texte. Révéler, puis changer de rôle."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-031$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-032$n$, $n$dessin-creation$n$, $n$complete_doodle$n$, $n$Complète mon gribouillis$n$, $n$Un trait lancé au hasard devient quelque chose entre vos mains.$n$, $n$Un trait lancé au hasard devient quelque chose entre vos mains.$n$, $n$cooperation$n$, 3, 10, 'standard', 32, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-032.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Après 4 passages, donner un titre commun ; pas de note artistique.", "setup": "Une amorce vectorielle est dessinée automatiquement ; A ajoute 3 traits puis passe à B.", "turn": "B ajoute 3 traits ; chacun peut déplacer seulement ses propres traits jusqu’à validation."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-032$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-033$n$, $n$dessin-creation$n$, $n$draw_dictation$n$, $n$Le dessin dicté$n$, $n$L’un voit le modèle, l’autre doit se fier à ses indications.$n$, $n$L’un voit le modèle, l’autre doit se fier à ses indications.$n$, $n$cooperation$n$, 3, 10, 'standard', 33, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-033.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Révélation côte à côte après validation ; score optionnel par correspondance des formes, pas du style.", "setup": "Le guide voit un modèle géométrique ; l’autre a un canvas quadrillé vide.", "turn": "Le guide décrit par texte ; le dessinateur place des formes et demande une précision libre."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-033$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-034$n$, $n$dessin-creation$n$, $n$exquisite_drawing$n$, $n$Le personnage plié$n$, $n$Dessiner un personnage en découvrant seulement les points de raccord.$n$, $n$Dessiner un personnage en découvrant seulement les points de raccord.$n$, $n$cooperation$n$, 3, 10, 'standard', 34, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-034.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 18, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Une créature avec un nom choisi ensemble ; aucun score.", "setup": "Trois bandes : tête, corps, jambes ; A dessine tête et jambes, B dessine corps.", "turn": "Les bandes sont masquées, seuls deux repères de raccord apparaissent ; assembler à la fin."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-034$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-035$n$, $n$dessin-creation$n$, $n$pixel_art$n$, $n$La mosaïque à deux$n$, $n$Créer une petite image où chacun contrôle une partie des couleurs.$n$, $n$Créer une petite image où chacun contrôle une partie des couleurs.$n$, $n$cooperation$n$, 3, 10, 'standard', 35, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-035.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Tous deux valident le tableau ; en mode modèle, comparaison cellule par cellule.", "setup": "Grille 8x8 ; trois couleurs pour A, trois pour B ; modèle optionnel.", "turn": "Peindre ses cases ; pour recouvrir la couleur de l’autre, proposer une modification qu’il accepte."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-035$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-036$n$, $n$dessin-creation$n$, $n$tangram$n$, $n$Sept pièces, une silhouette$n$, $n$Faire rentrer les sept pièces sans espace ni chevauchement.$n$, $n$Faire rentrer les sept pièces sans espace ni chevauchement.$n$, $n$cooperation$n$, 3, 10, 'standard', 36, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-036.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Couverture exacte de la silhouette et absence de chevauchement.", "setup": "Set traditionnel de 7 pièces ; modèle carré fourni, transformations autorisées.", "turn": "Toucher une pièce, déplacer, tourner par 45 degrés ; retourner seulement le parallélogramme."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-036$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-037$n$, $n$dessin-creation$n$, $n$jigsaw$n$, $n$Puzzle de poche$n$, $n$Reconstituer une illustration originale en tuiles simples.$n$, $n$Reconstituer une illustration originale en tuiles simples.$n$, $n$cooperation$n$, 3, 10, 'standard', 37, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-037.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Toutes les tuiles aux bonnes coordonnées ; compter les déplacements sans compétition.", "setup": "Illustration SVG fournie découpée en 3x3 ou 4x4 rectangles mélangés.", "turn": "Toucher une tuile puis sa destination ; chacun peut déplacer la tuile active à son tour."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-037$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-038$n$, $n$dessin-creation$n$, $n$sticker_portrait$n$, $n$Le portrait en gommettes$n$, $n$Faire un portrait expressif avec une boîte de formes et d’accessoires.$n$, $n$Faire un portrait expressif avec une boîte de formes et d’accessoires.$n$, $n$echange$n$, 3, 10, 'standard', 38, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-038.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Galerie commune et export SVG/PNG côté app.", "setup": "Canvas carré ; yeux, bouche, cheveux, lunettes et chapeaux vectoriels.", "turn": "Chacun compose son personnage en 12 éléments maximum ; révéler les deux avatars."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-038$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-039$n$, $n$dessin-creation$n$, $n$emblem$n$, $n$Votre petit emblème$n$, $n$Associer deux idées en un signe que vous reconnaissez.$n$, $n$Associer deux idées en un signe que vous reconnaissez.$n$, $n$cooperation$n$, 3, 10, 'standard', 39, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-039.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Validation commune et nomination du badge en 24 caractères.", "setup": "Chaque joueur choisit un symbole et une couleur ; centre du badge partagé.", "turn": "A place le premier, B le second ; choisir cercle, carré arrondi ou losange comme support."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-039$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-040$n$, $n$dessin-creation$n$, $n$stroke_budget$n$, $n$Dix traits et pas un de plus$n$, $n$L’économie de traits oblige à choisir le détail qui fait reconnaître.$n$, $n$L’économie de traits oblige à choisir le détail qui fait reconnaître.$n$, $n$cooperation$n$, 3, 10, 'standard', 40, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-040.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "3 réponses maximum ; 4 manches alternées.", "setup": "Une cible et un compteur de 10 traits ; le partenaire ne voit pas le mot.", "turn": "Un pointerdown-pointerup compte pour un trait ; gomme consomme aussi un trait pour éviter les contournements."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-040$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-041$n$, $n$dessin-creation$n$, $n$mirror_draw$n$, $n$Le miroir créatif$n$, $n$Un geste se reflète et fabrique une image symétrique.$n$, $n$Un geste se reflète et fabrique une image symétrique.$n$, $n$cooperation$n$, 3, 10, 'standard', 41, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-041.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Nommer la figure finale ; aucune symétrie à corriger puisqu’elle est automatique.", "setup": "Axe vertical visible ; chacun dessine à tour de rôle sur la moitié gauche.", "turn": "Chaque trait est réfléchi par x’=largeur-x ; 6 tours de 2 traits."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-041$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-042$n$, $n$dessin-creation$n$, $n$palette$n$, $n$La palette commune$n$, $n$Composer ensemble cinq couleurs pour une ambiance concrète.$n$, $n$Composer ensemble cinq couleurs pour une ambiance concrète.$n$, $n$cooperation$n$, 3, 10, 'standard', 42, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-042.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 18, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Appliquer la palette à une illustration neutre en aperçu.", "setup": "Une scène textuelle et 18 pastilles nommées ; chacun sélectionne 3 couleurs en secret.", "turn": "Révéler, conserver les communes, puis négocier les places restantes jusqu’à 5."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-042$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-043$n$, $n$dessin-creation$n$, $n$poster$n$, $n$L’affiche improbable$n$, $n$Créer une affiche crédible pour un événement qui ne l’est pas.$n$, $n$Créer une affiche crédible pour un événement qui ne l’est pas.$n$, $n$cooperation$n$, 3, 10, 'standard', 43, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-043.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Une affiche complète avec date fictive affichée comme telle.", "setup": "Tirer un événement et une contrainte graphique ; une grille titre/image/date est fournie.", "turn": "A écrit le titre, B assemble le visuel ; inverser pour le sous-titre et le détail final."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-043$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-044$n$, $n$dessin-creation$n$, $n$silent_comic$n$, $n$La bande dessinée muette$n$, $n$Raconter une petite histoire en trois cases, sans texte.$n$, $n$Raconter une petite histoire en trois cases, sans texte.$n$, $n$cooperation$n$, 3, 10, 'standard', 44, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-044.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Révéler les titres et la planche ; l’écart d’interprétation fait partie du jeu.", "setup": "Trois cadres et un sujet simple ; A crée la première, B la deuxième, A conclut.", "turn": "Dessiner avec les mêmes personnages-gommettes ; au dernier tour, chacun donne un titre en privé."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-044$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-045$n$, $n$dessin-creation$n$, $n$tile_scene$n$, $n$L’île en tuiles$n$, $n$Construire une carte miniature agréable à explorer du regard.$n$, $n$Construire une carte miniature agréable à explorer du regard.$n$, $n$cooperation$n$, 3, 10, 'standard', 45, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-045.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Fin à 15 tuiles ; objectif commun : relier deux maisons par un chemin continu.", "setup": "Grille 5x5, centre terre ; tuiles eau, plage, forêt, chemin et maison.", "turn": "À tour de rôle, poser une tuile adjacente orthogonalement à une tuile existante ; chaque maison doit toucher un chemin."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-045$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-046$n$, $n$memoire-observation$n$, $n$memory_pairs$n$, $n$Les paires cachées$n$, $n$Un classique lisible, avec des objets vraiment différents.$n$, $n$Un classique lisible, avec des objets vraiment différents.$n$, $n$duel$n$, 3, 10, 'standard', 46, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-046.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Grille vide ; chaque paire vaut 1 point, égalité possible.", "setup": "Grille 4x4, 8 paires d’objets mélangées ; premier joueur tiré au sort.", "turn": "Retourner deux cartes ; paire trouvée retirée et même joueur rejoue, sinon masquer après 1,2 s et passer le tour."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-046$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-047$n$, $n$memoire-observation$n$, $n$change_detection$n$, $n$Qu’est-ce qui a bougé ?$n$, $n$Une scène familière, un détail déplacé.$n$, $n$Une scène familière, un détail déplacé.$n$, $n$duel$n$, 3, 10, 'standard', 47, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-047.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "choix privés puis révélation", "level_count": 8, "summary": {"end": "1 point par localisation juste ; 6 manches.", "setup": "Montrer 12 objets sur une grille 4x4 pendant 12 s puis un masque de 2 s.", "turn": "Un objet change de case ; toucher sa nouvelle position. Les deux joueurs répondent en privé."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-047$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-048$n$, $n$memoire-observation$n$, $n$differences$n$, $n$Les cinq différences$n$, $n$Comparer deux scènes conçues pour être lisibles sur téléphone.$n$, $n$Comparer deux scènes conçues pour être lisibles sur téléphone.$n$, $n$duel$n$, 3, 10, 'standard', 48, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-048.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Les cinq zones trouvées ; compteur d’erreurs facultatif, sans score de vitesse.", "setup": "Deux vues alternables de la même scène ; cinq différences discrètes mais visibles.", "turn": "Toucher une zone différente ; une pastille verrouille la différence trouvée."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-048$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-049$n$, $n$memoire-observation$n$, $n$zoom_recognition$n$, $n$L’objet aperçu$n$, $n$Reconnaître un objet à partir d’un détail qui s’élargit.$n$, $n$Reconnaître un objet à partir d’un détail qui s’élargit.$n$, $n$duel$n$, 3, 10, 'standard', 49, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-049.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "3/2/1 points selon le niveau où l’objet est trouvé ; 6 manches.", "setup": "Recadrer un SVG d’objet à 25 %, puis proposer 4 noms.", "turn": "Choisir ou demander un zoom arrière ; trois niveaux de cadrage maximum."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-049$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-050$n$, $n$memoire-observation$n$, $n$visual_search$n$, $n$La chasse au détail$n$, $n$Repérer une petite forme au milieu d’une scène bien remplie.$n$, $n$Repérer une petite forme au milieu d’une scène bien remplie.$n$, $n$duel$n$, 3, 10, 'standard', 50, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-050.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Cible trouvée ; 5 scènes, meilleur score = moins d’erreurs.", "setup": "Montrer la cible puis une grille de 36 icônes avec une seule occurrence exacte.", "turn": "Toucher l’icône identique ; un mauvais toucher ne retire pas de temps mais ajoute une erreur."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-050$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-051$n$, $n$memoire-observation$n$, $n$recall_set$n$, $n$Le plateau disparu$n$, $n$Retenir ce qui était présent, sans mémoriser une photographie entière.$n$, $n$Retenir ce qui était présent, sans mémoriser une photographie entière.$n$, $n$duel$n$, 3, 10, 'standard', 51, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-051.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "choix privés puis révélation", "level_count": 8, "summary": {"end": "Score = bons objets sélectionnés, sur 8 ; 5 manches.", "setup": "Afficher 8 objets durant 15 s, puis les cacher et présenter 16 candidats.", "turn": "Sélectionner exactement 8 objets ; confirmer avant révélation."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-051$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-052$n$, $n$memoire-observation$n$, $n$simon$n$, $n$La suite lumineuse$n$, $n$Une suite de boutons s’allume, puis c’est à vous de la reconstruire.$n$, $n$Une suite de boutons s’allume, puis c’est à vous de la reconstruire.$n$, $n$duel$n$, 3, 10, 'standard', 52, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-052.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 6, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 6, "summary": {"end": "Un niveau réussi allonge la suite ; arrêt après 2 erreurs ou niveau 8.", "setup": "Quatre boutons forme+couleur ; séquence de 3 à 8 éléments.", "turn": "Observer puis toucher les boutons dans l’ordre. Le serveur attend la réponse complète, sans rejouer les animations réseau."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-052$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-053$n$, $n$memoire-observation$n$, $n$rhythm$n$, $n$Le rythme en écho$n$, $n$Retrouver un motif de frappes avec un repère visuel.$n$, $n$Retrouver un motif de frappes avec un repère visuel.$n$, $n$duel$n$, 3, 10, 'standard', 53, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-053.svg$n$, $n$2.1.0$n$, $n${"audio_optional": true, "bank_type": "GEN", "content_count": 7, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 7, "summary": {"end": "Score = 8 moins le nombre de différences entre les deux masques binaires, sur 8 ; 4 manches. Utiliser des motifs ayant entre 3 et 5 temps actifs pour éviter un score élevé en laissant tout vide.", "setup": "Un métronome visuel à 80 BPM et une grille de 8 temps.", "turn": "Écouter ou regarder le motif puis cocher les temps joués ; pas besoin de réflexes réseau."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-053$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-054$n$, $n$memoire-observation$n$, $n$ordered_recall$n$, $n$Le panier dans l’ordre$n$, $n$Retenir une petite liste comme on prépare un panier.$n$, $n$Retenir une petite liste comme on prépare un panier.$n$, $n$duel$n$, 3, 10, 'standard', 54, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-054.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "choix privés puis révélation", "level_count": 8, "summary": {"end": "Score = positions exactes, sur 6 ; comparaison sans commentaire sur la mémoire des personnes.", "setup": "Afficher 6 objets l’un après l’autre, puis les mêmes mélangés.", "turn": "Les remettre en ordre ; les deux joueurs proposent leur ordre en privé."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-054$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-055$n$, $n$memoire-observation$n$, $n$spatial_recall$n$, $n$Le plan de mémoire$n$, $n$Retrouver où se trouvaient les choses.$n$, $n$Retrouver où se trouvaient les choses.$n$, $n$duel$n$, 3, 10, 'standard', 55, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-055.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Score commun ou duel = nombre de positions exactes.", "setup": "Grille 4x4 avec 6 objets, visible 15 s puis effacée.", "turn": "Placer les six objets dans les cases ; chacun peut choisir de discuter ou de répondre en privé."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-055$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-056$n$, $n$memoire-observation$n$, $n$pixel_recall$n$, $n$Le pixel retenu$n$, $n$Mémoriser un petit motif sans avoir besoin de dessiner.$n$, $n$Mémoriser un petit motif sans avoir besoin de dessiner.$n$, $n$duel$n$, 3, 10, 'standard', 56, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-056.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Score = cases exactes sur 25 ; révéler les divergences après validation.", "setup": "Afficher un motif bicolore de 5x5 pendant 12 s.", "turn": "Reproduire par touches ; chaque case alterne fond et couleur."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-056$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-057$n$, $n$memoire-observation$n$, $n$sorting$n$, $n$Le tri sans hésiter$n$, $n$Ranger des objets selon un critère visible, pas selon une intuition floue.$n$, $n$Ranger des objets selon un critère visible, pas selon une intuition floue.$n$, $n$duel$n$, 3, 10, 'standard', 57, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-057.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 3, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Score = bonnes affectations ; durée informative uniquement.", "setup": "24 cartes distribuées entre deux bacs nommés ; règle affichée en permanence.", "turn": "Toucher un bac pour chaque carte ; les deux joueurs ont la même suite dans un ordre différent."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-057$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-058$n$, $n$memoire-observation$n$, $n$go_nogo$n$, $n$Le bon signal$n$, $n$Réagir à une combinaison précise, pas à toute lumière qui clignote.$n$, $n$Réagir à une combinaison précise, pas à toute lumière qui clignote.$n$, $n$duel$n$, 3, 10, 'standard', 58, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-058.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Score = réponses correctes - fausses alarmes ; aucun classement entre appareils.", "setup": "Consigne « toucher seulement le cercle bleu » ; 20 stimuli de 900 ms.", "turn": "Toucher la cible, ignorer les autres. Les réponses sont enregistrées localement puis envoyées par lot."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-058$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-059$n$, $n$memoire-observation$n$, $n$precision$n$, $n$Le curseur juste$n$, $n$Retrouver une position vue quelques secondes avant.$n$, $n$Retrouver une position vue quelques secondes avant.$n$, $n$duel$n$, 3, 10, 'standard', 59, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-059.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "choix privés puis révélation", "level_count": 8, "summary": {"end": "Score = 100 moins l’écart absolu ; moyenne sur 5 manches.", "setup": "Montrer un repère sur une ligne de 0 à 100 pendant 3 s ; masquer le repère.", "turn": "Déplacer son curseur et confirmer ; révéler les deux positions et la cible."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-059$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-060$n$, $n$memoire-observation$n$, $n$split_memory$n$, $n$Deux mémoires, un plateau$n$, $n$Chacun a vu ce qui manquait à l’autre.$n$, $n$Chacun a vu ce qui manquait à l’autre.$n$, $n$cooperation$n$, 3, 10, 'standard', 60, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-060.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Réussite si toutes les positions sont justes ; une révélation aide facultative réduit le badge de défi.", "setup": "Un plateau de 8 objets ; A voit les quatre premiers, B les quatre autres, durant 12 s.", "turn": "Après masquage, reconstruire ensemble les huit positions dans une grille commune."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-060$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-061$n$, $n$logique-codes$n$, $n$sudoku$n$, $n$Sudoku d’objets$n$, $n$Remplacer les chiffres par quatre objets faciles à distinguer.$n$, $n$Remplacer les chiffres par quatre objets faciles à distinguer.$n$, $n$cooperation$n$, 3, 10, 'standard', 61, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-061.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Grille complète conforme ; aucune limite de temps.", "setup": "Grille 4x4 et blocs 2x2 ; quelques objets fixés, quatre choix dans la barre basse.", "turn": "Placer un objet dans une case ; chaque ligne, colonne et bloc doit contenir chacun des quatre objets une seule fois."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-061$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-062$n$, $n$logique-codes$n$, $n$nonogram$n$, $n$L’image en nombres$n$, $n$Colorer une image avec des indications de longueurs.$n$, $n$Colorer une image avec des indications de longueurs.$n$, $n$cooperation$n$, 3, 10, 'standard', 62, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-062.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Toutes les suites satisfaites et solution unique du niveau.", "setup": "Grille 5x5 ; suites de nombres à gauche et en haut.", "turn": "Colorer les groupes dans l’ordre, avec au moins une case vide entre deux groupes. Marquer les cases vides explicitement."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-062$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-063$n$, $n$logique-codes$n$, $n$lights$n$, $n$Tout éteindre$n$, $n$Un bouton agit sur ses voisins : trouver le bon ensemble de gestes.$n$, $n$Un bouton agit sur ses voisins : trouver le bon ensemble de gestes.$n$, $n$cooperation$n$, 3, 10, 'standard', 63, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-063.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Victoire quand tout est éteint ; minimum de coups calculé par exploration des 512 masques.", "setup": "Grille 3x3 ; chaque case est allumée ou éteinte.", "turn": "Toucher une case inverse son état et ceux de ses voisins orthogonaux."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-063$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-064$n$, $n$logique-codes$n$, $n$sliding$n$, $n$Le taquin$n$, $n$Faire glisser les pièces dans le seul espace libre.$n$, $n$Faire glisser les pièces dans le seul espace libre.$n$, $n$cooperation$n$, 3, 10, 'standard', 64, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-064.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Ordre 1 à 8 puis vide en bas à droite ; compteur de coups.", "setup": "Grille 3x3 avec huit tuiles numérotées et une case vide.", "turn": "Toucher une tuile voisine de la case vide pour la déplacer."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-064$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-065$n$, $n$logique-codes$n$, $n$inequality$n$, $n$Plus grand, plus petit$n$, $n$Un carré de chiffres où les signes donnent la direction.$n$, $n$Un carré de chiffres où les signes donnent la direction.$n$, $n$cooperation$n$, 3, 10, 'standard', 65, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-065.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Solution complète valide ; indices effaçables uniquement s’ils ne sont pas initiaux.", "setup": "Grille 4x4 ; chiffres 1 à 4, quelques valeurs et signes < ou > fixés.", "turn": "Compléter sans répétition en ligne ou colonne et en respectant tous les signes."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-065$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-066$n$, $n$logique-codes$n$, $n$towers$n$, $n$Les tours visibles$n$, $n$Comprendre ce qu’un point de vue permet de voir.$n$, $n$Comprendre ce qu’un point de vue permet de voir.$n$, $n$cooperation$n$, 3, 10, 'standard', 66, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-066.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Tous les indices et le carré latin sont satisfaits.", "setup": "Carré 4x4, hauteurs 1 à 4 ; nombres visibles depuis les bords.", "turn": "Placer les hauteurs sans doublon en ligne/colonne ; une tour haute masque toutes les plus petites derrière elle."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-066$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-067$n$, $n$logique-codes$n$, $n$rectangles$n$, $n$Les rectangles exacts$n$, $n$Découper le plateau en pièces qui ont exactement la bonne aire.$n$, $n$Découper le plateau en pièces qui ont exactement la bonne aire.$n$, $n$cooperation$n$, 3, 10, 'standard', 67, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-067.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Toute la grille couverte par des rectangles valides.", "setup": "Grille 4x4 avec indices de surface ; sélectionner deux coins pour dessiner un rectangle.", "turn": "Chaque rectangle contient un seul indice et autant de cases que sa valeur. Les rectangles ne se chevauchent pas."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-067$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-068$n$, $n$logique-codes$n$, $n$bridges$n$, $n$Les ponts des îles$n$, $n$Relier les îles sans croiser les routes.$n$, $n$Relier les îles sans croiser les routes.$n$, $n$cooperation$n$, 3, 10, 'standard', 68, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-068.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Degrés exacts et un seul réseau connecté.", "setup": "Îles numérotées sur une grille ; tracer entre voisins visibles en ligne ou colonne.", "turn": "Chaque connexion porte 0,1 ou 2 ponts ; pas de croisement ni de passage à travers une île."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-068$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-069$n$, $n$logique-codes$n$, $n$tents$n$, $n$Le camping bien rangé$n$, $n$Trouver une place à chaque tente autour des arbres.$n$, $n$Trouver une place à chaque tente autour des arbres.$n$, $n$cooperation$n$, 3, 10, 'standard', 69, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-069.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Totaux respectés et appariement complet arbre-tente existant.", "setup": "Grille 4x4 avec arbres et totaux par ligne/colonne.", "turn": "Placer une tente par arbre adjacent orthogonalement ; aucune tente ne touche une autre, même en diagonale."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-069$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-070$n$, $n$logique-codes$n$, $n$mines$n$, $n$Le jardin à explorer$n$, $n$Déduire les cases sûres d’un petit terrain.$n$, $n$Déduire les cases sûres d’un petit terrain.$n$, $n$cooperation$n$, 3, 10, 'standard', 70, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-070.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Toutes les cases sûres ouvertes ; toucher un obstacle termine la manche.", "setup": "Grille 6x6 avec 6 obstacles ; première ouverture garantie sûre avec zone voisine dégagée.", "turn": "Ouvrir une case ou poser un drapeau ; le nombre indique les obstacles parmi les huit voisines."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-070$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-071$n$, $n$logique-codes$n$, $n$mastermind$n$, $n$Le code à couleurs$n$, $n$Chaque essai donne une information, même quand il est faux.$n$, $n$Chaque essai donne une information, même quand il est faux.$n$, $n$cooperation$n$, 3, 10, 'standard', 71, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-071.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Trouver en 8 essais ; les deux joueurs décident ensemble.", "setup": "Code secret de 4 symboles parmi 6, répétitions autorisées.", "turn": "Proposer quatre symboles. Retour : bien placés et présents ailleurs, sans indiquer lesquels."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-071$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-072$n$, $n$logique-codes$n$, $n$caesar$n$, $n$Le message décalé$n$, $n$Un alphabet déplacé transforme une phrase en petit secret.$n$, $n$Un alphabet déplacé transforme une phrase en petit secret.$n$, $n$cooperation$n$, 3, 10, 'standard', 72, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-072.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 24, "summary": {"end": "Texte normalisé identique à la solution ; 5 messages.", "setup": "Message chiffré et roue de 26 lettres ; un indice de décalage est donné en facile.", "turn": "Tourner la roue puis écrire la phrase ; espaces et ponctuation restent visibles."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-072$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-073$n$, $n$logique-codes$n$, $n$cages$n$, $n$Les cages de calcul$n$, $n$Un petit carré latin avec des sommes à respecter.$n$, $n$Un petit carré latin avec des sommes à respecter.$n$, $n$cooperation$n$, 3, 10, 'standard', 73, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-073.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 7, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 7, "summary": {"end": "Toutes les contraintes respectées.", "setup": "Grille 3x3, chiffres 1 à 3 ; cages connexes avec somme cible.", "turn": "Placer les chiffres sans doublon en ligne/colonne ; chaque cage doit atteindre sa somme."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-073$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-074$n$, $n$logique-codes$n$, $n$loop$n$, $n$La boucle continue$n$, $n$Dessiner un seul chemin fermé autour des bons indices.$n$, $n$Dessiner un seul chemin fermé autour des bons indices.$n$, $n$cooperation$n$, 3, 10, 'standard', 74, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-074.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 5, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 5, "summary": {"end": "Une seule boucle sans branche, indices tous respectés.", "setup": "Grille de 2x2 cases et 3x3 points ; chaque case porte un indice de 0 à 3.", "turn": "Activer des segments entre points voisins ; le nombre d’une case compte ses côtés activés."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-074$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-075$n$, $n$logique-codes$n$, $n$untangle$n$, $n$Les fils démêlés$n$, $n$Déplacer des points jusqu’à ce que les fils ne se croisent plus.$n$, $n$Déplacer des points jusqu’à ce que les fils ne se croisent plus.$n$, $n$cooperation$n$, 3, 10, 'standard', 75, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-075.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Zéro croisement et aucun sommet superposé.", "setup": "Un graphe planaire de 6 sommets dont les positions ont été mélangées.", "turn": "Déplacer un sommet ; ses arêtes suivent. Les croisements non liés à un sommet commun sont indiqués."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-075$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-076$n$, $n$plateaux-strategie$n$, $n$tic_tac_toe$n$, $n$Trois en ligne$n$, $n$Le duel qui s’apprend en un tour, parfait pour une revanche.$n$, $n$Le duel qui s’apprend en un tour, parfait pour une revanche.$n$, $n$duel$n$, 3, 10, 'standard', 76, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-076.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Trois alignés horizontalement, verticalement ou diagonalement gagnent ; plateau plein sans ligne = nul.", "setup": "Grille 3x3 vide, croix pour A et cercle pour B.", "turn": "À tour de rôle, placer son symbole dans une case vide."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-076$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-077$n$, $n$plateaux-strategie$n$, $n$connect_four$n$, $n$Quatre qui tombent$n$, $n$Choisir une colonne, anticiper la prochaine hauteur disponible.$n$, $n$Choisir une colonne, anticiper la prochaine hauteur disponible.$n$, $n$duel$n$, 3, 10, 'standard', 77, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-077.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Premier alignement de 4 dans une des quatre directions ; nul si grille pleine.", "setup": "Grille de 7 colonnes et 6 lignes vide ; 21 jetons chacun.", "turn": "Choisir une colonne non pleine ; le jeton tombe dans sa case libre la plus basse."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-077$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-078$n$, $n$plateaux-strategie$n$, $n$battleship$n$, $n$La flotte secrète$n$, $n$Chercher, recouper et réduire les positions possibles.$n$, $n$Chercher, recouper et réduire les positions possibles.$n$, $n$duel$n$, 3, 10, 'standard', 78, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-078.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Tous les bateaux adverses coulés ; révéler les deux grilles.", "setup": "Deux grilles privées 6x6 ; bateaux de longueurs 3,2,2, placements droits non superposés ; contact autorisé.", "turn": "Un tir par tour ; retour eau, touché ou coulé. Un tir déjà joué est refusé sans perdre le tour."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-078$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-079$n$, $n$plateaux-strategie$n$, $n$dots_boxes$n$, $n$Les carrés à fermer$n$, $n$Un trait de plus peut donner un carré… ou plusieurs à l’autre.$n$, $n$Un trait de plus peut donner un carré… ou plusieurs à l’autre.$n$, $n$duel$n$, 3, 10, 'standard', 79, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-079.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Tous les côtés posés ; celui qui possède le plus de carrés gagne.", "setup": "16 points en grille 4x4, donc 9 carrés possibles.", "turn": "Tracer un côté libre ; fermer un carré le colore et donne un tour supplémentaire."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-079$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-080$n$, $n$plateaux-strategie$n$, $n$reversi$n$, $n$Le territoire retourné$n$, $n$Encadrer pour retourner les pions et changer le paysage.$n$, $n$Encadrer pour retourner les pions et changer le paysage.$n$, $n$duel$n$, 3, 10, 'standard', 80, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-080.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Deux passes consécutives ou grille pleine ; plus de pions gagne.", "setup": "Grille 6x6, quatre pions au centre en diagonales opposées.", "turn": "Placer un pion qui encadre au moins une ligne adverse entre le nouveau pion et un pion de sa couleur ; retourner toutes les lignes valides."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-080$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-081$n$, $n$plateaux-strategie$n$, $n$nim$n$, $n$Nim, le dernier jeton$n$, $n$Un petit calcul caché derrière des gestes simples.$n$, $n$Un petit calcul caché derrière des gestes simples.$n$, $n$duel$n$, 3, 10, 'standard', 81, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-081.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Le joueur qui prend le dernier jeton gagne.", "setup": "Trois tas de 3,4,5 jetons.", "turn": "Retirer au moins un jeton d’un seul tas ; aucun ajout."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-081$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-082$n$, $n$plateaux-strategie$n$, $n$domino$n$, $n$Dominos bloqués$n$, $n$Construire la chaîne tout en surveillant ce qui reste en main.$n$, $n$Construire la chaîne tout en surveillant ce qui reste en main.$n$, $n$duel$n$, 3, 10, 'standard', 82, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-082.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Main vide ou deux passes successives. Plus petit total de points en main gagne ; égalité si totaux égaux.", "setup": "Double-six de 28 tuiles ; 7 chacun, 14 hors jeu ; premier joueur aléatoire.", "turn": "Poser une tuile dont une extrémité correspond à un bout libre ; sans coup légal, passer."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-082$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-083$n$, $n$plateaux-strategie$n$, $n$rps$n$, $n$Pierre, feuille, ciseaux$n$, $n$Un duel de choix cachés, avec une révélation réellement simultanée.$n$, $n$Un duel de choix cachés, avec une révélation réellement simultanée.$n$, $n$duel$n$, 3, 10, 'standard', 83, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-083.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "choix privés puis révélation", "level_count": 1, "summary": {"end": "Pierre bat ciseaux, ciseaux bat feuille, feuille bat pierre. 1 point au gagnant ; égalité zéro.", "setup": "Les deux joueurs disposent des trois symboles ; 7 manches.", "turn": "Choisir et confirmer ; révéler uniquement après les deux confirmations."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-083$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-084$n$, $n$plateaux-strategie$n$, $n$checkers$n$, $n$Dames de poche$n$, $n$Avancer, capturer et protéger une pièce devenue dame.$n$, $n$Avancer, capturer et protéger une pièce devenue dame.$n$, $n$duel$n$, 3, 10, 'standard', 84, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-084.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Victoire si l’autre n’a plus de pion ou de coup légal ; nul après 40 demi-coups sans capture ni promotion.", "setup": "Grille 6x6 ; six pions par joueur sur les deux premières rangées sombres.", "turn": "Un pion avance en diagonale d’une case. Capture obligatoire en sautant un adversaire vers une case vide, vers l’avant ou l’arrière ; poursuivre une rafle possible. Dame : pas ou saut court dans les deux sens."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-084$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-085$n$, $n$plateaux-strategie$n$, $n$kalah$n$, $n$Les graines en voyage$n$, $n$Semer ses graines pour nourrir son propre grenier.$n$, $n$Semer ses graines pour nourrir son propre grenier.$n$, $n$duel$n$, 3, 10, 'standard', 85, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-085.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Si un camp est vide, l’autre récolte son restant ; plus de graines dans son grenier gagne.", "setup": "Six cases et un grenier par joueur ; 3 graines par case, soit 36.", "turn": "Choisir une case de son camp ; semer une graine par case en sens antihoraire, y compris son grenier mais pas celui de l’autre. Dernière graine dans son grenier : rejouer. Dernière dans une case propre vide avec case opposée non vide : capturer les deux contenus."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-085$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-086$n$, $n$plateaux-strategie$n$, $n$hex$n$, $n$La traversée hexagonale$n$, $n$Construire une connexion sans laisser l’autre fermer le passage.$n$, $n$Construire une connexion sans laisser l’autre fermer le passage.$n$, $n$duel$n$, 3, 10, 'standard', 86, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-086.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Premier chemin continu entre ses deux bords opposés.", "setup": "Plateau losange de 5x5 hexagones ; A relie haut-bas, B gauche-droite.", "turn": "Placer un pion dans une case libre ; au second tour seulement, B peut échanger les couleurs et objectifs."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-086$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-087$n$, $n$plateaux-strategie$n$, $n$auction$n$, $n$Les enchères de poche$n$, $n$Miser sans savoir combien l’autre tient à la même carte.$n$, $n$Miser sans savoir combien l’autre tient à la même carte.$n$, $n$duel$n$, 3, 10, 'standard', 87, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-087.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "choix privés puis révélation", "level_count": 1, "summary": {"end": "Après 6 lots, plus grande somme de valeurs gagne ; solde restant départage, puis égalité.", "setup": "12 jetons fictifs chacun ; 6 lots de valeurs visibles 1,2,3,4,5,6 mélangés.", "turn": "Miser en secret entre 0 et le solde. Le plus offrant paie et reçoit le lot ; égalité : lot défaussé, personne ne paie."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-087$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-088$n$, $n$plateaux-strategie$n$, $n$draft$n$, $n$Le draft des collections$n$, $n$Choisir une carte, c’est aussi retirer une possibilité à l’autre.$n$, $n$Choisir une carte, c’est aussi retirer une possibilité à l’autre.$n$, $n$duel$n$, 3, 10, 'standard', 88, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-088.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Pour chaque symbole, n cartes valent n(n-1)/2 points ; total le plus élevé gagne.", "setup": "24 cartes : 4 symboles répétés 6 fois ; marché de 4 cartes visibles, pioche mélangée.", "turn": "À tour de rôle, prendre une carte puis remplacer depuis la pioche ; 8 choix par personne."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-088$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-089$n$, $n$plateaux-strategie$n$, $n$domineering$n$, $n$Les pavés opposés$n$, $n$Occuper deux cases à la fois pour laisser l’autre sans place.$n$, $n$Occuper deux cases à la fois pour laisser l’autre sans place.$n$, $n$duel$n$, 3, 10, 'standard', 89, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-089.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Le joueur sans coup légal à son tour perd.", "setup": "Grille 5x5 vide ; A pose seulement verticalement, B horizontalement.", "turn": "Poser un domino sur deux cases vides adjacentes dans son orientation."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-089$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-090$n$, $n$plateaux-strategie$n$, $n$sim_graph$n$, $n$Le triangle empoisonné$n$, $n$Tracer ses liens sans être le premier à fermer son propre triangle.$n$, $n$Tracer ses liens sans être le premier à fermer son propre triangle.$n$, $n$duel$n$, 3, 10, 'standard', 90, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-090.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Perdre dès qu’un triangle a ses trois côtés de ta couleur ; pas de hasard.", "setup": "Six points disposés en cercle ; toutes les 15 arêtes possibles sont disponibles.", "turn": "Colorer une arête libre à sa couleur."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-090$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-091$n$, $n$cooperation-missions$n$, $n$blind_maze$n$, $n$Guide-moi$n$, $n$L’un connaît le chemin, l’autre tient le pion.$n$, $n$L’un connaît le chemin, l’autre tient le pion.$n$, $n$cooperation$n$, 3, 10, 'standard', 91, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-091.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Atteindre la sortie ; compteur collectif de déplacements.", "setup": "Labyrinthe 5x5 ; A voit les murs et la sortie, B voit son pion et les commandes.", "turn": "A guide par texte ; B choisit haut/bas/gauche/droite. Un mur bloque sans pénalité ; inverser les rôles au niveau suivant."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-091$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-092$n$, $n$cooperation-missions$n$, $n$split_build$n$, $n$Le plan et les pièces$n$, $n$Les instructions d’un côté, les bons éléments de l’autre.$n$, $n$Les instructions d’un côté, les bons éléments de l’autre.$n$, $n$cooperation$n$, 3, 10, 'standard', 92, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-092.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Correspondance de chaque pièce avec le modèle ; 3 tentatives de contrôle.", "setup": "A reçoit une grille modèle 4x4 de 6 pièces ; B reçoit les 6 pièces et une grille vide.", "turn": "A décrit forme, couleur et coordonnées ; B place puis valide le montage."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-092$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-093$n$, $n$cooperation-missions$n$, $n$split_code$n$, $n$Le coffre à deux clés$n$, $n$Chacun possède une contrainte indispensable au code.$n$, $n$Chacun possède une contrainte indispensable au code.$n$, $n$cooperation$n$, 3, 10, 'standard', 93, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-093.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Une seule combinaison doit satisfaire tous les indices ; 6 essais maximum.", "setup": "Code de trois chiffres distincts 0 à 5 ; deux indices privés issus de la solution, plus un indice commun.", "turn": "Comparer les contraintes par chat et proposer un code commun."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-093$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-094$n$, $n$cooperation-missions$n$, $n$split_map$n$, $n$La carte en deux couches$n$, $n$Les obstacles sont chez l’un, les cibles chez l’autre.$n$, $n$Les obstacles sont chez l’un, les cibles chez l’autre.$n$, $n$cooperation$n$, 3, 10, 'standard', 94, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-094.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Trois objectifs atteints puis sortie ; aucun réflexe requis.", "setup": "Carte 5x5 ; A voit les murs, B voit trois objectifs, les deux voient le pion.", "turn": "A propose un déplacement, B le confirme ; atteindre les objectifs dans l’ordre affiché à B."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-094$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-095$n$, $n$cooperation-missions$n$, $n$recipe$n$, $n$La recette virtuelle$n$, $n$Assembler une préparation fictive en partageant les informations.$n$, $n$Assembler une préparation fictive en partageant les informations.$n$, $n$cooperation$n$, 3, 10, 'standard', 95, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-095.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 6, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "La suite correspond au modèle ; révélation des deux fiches à la fin.", "setup": "A connaît les ingrédients, B l’ordre des gestes ; un plan de travail virtuel propose des cartes.", "turn": "A place un ingrédient, B choisit le geste suivant ; la recette se construit en six étapes."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-095$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-096$n$, $n$cooperation-missions$n$, $n$symbol_language$n$, $n$Le lexique inconnu$n$, $n$Décrire des symboles quand l’autre possède la traduction.$n$, $n$Décrire des symboles quand l’autre possède la traduction.$n$, $n$cooperation$n$, 3, 10, 'standard', 96, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-096.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Le pion arrive sur la cible du message ; 4 manches.", "setup": "A voit un message en quatre symboles ; B possède le lexique symbole-vers-direction.", "turn": "Décrire les formes par texte ; B répond avec les directions, A déplace un pion sur une grille."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-096$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-097$n$, $n$cooperation-missions$n$, $n$pipes$n$, $n$Les tuyaux tournants$n$, $n$Orienter les pièces jusqu’à ce que le trajet de l’eau soit continu.$n$, $n$Orienter les pièces jusqu’à ce que le trajet de l’eau soit continu.$n$, $n$cooperation$n$, 3, 10, 'standard', 97, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-097.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 8, "summary": {"end": "Un chemin de source à sortie sans fuite sur ce chemin ; les pièces hors chemin sont décoratives.", "setup": "Grille 4x4 ; source et sortie fixées, coudes et lignes ; A contrôle lignes impaires, B paires.", "turn": "Tourner une pièce de son secteur par 90° ; lancer l’eau quand les deux valident."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-097$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-098$n$, $n$cooperation-missions$n$, $n$doors$n$, $n$Les portes coordonnées$n$, $n$Faire avancer deux pions en tenant les bonnes portes ouvertes.$n$, $n$Faire avancer deux pions en tenant les bonnes portes ouvertes.$n$, $n$cooperation$n$, 3, 10, 'standard', 98, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-098.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Les deux pions atteignent leur sortie ; les portes restent ouvertes après activation dans le mode débutant.", "setup": "Deux couloirs de 6 cases ; un bouton dans chaque couloir ouvre la porte de l’autre.", "turn": "Déplacer un pion d’une case ; activer ou désactiver le bouton à distance depuis sa case dédiée."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-098$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-099$n$, $n$cooperation-missions$n$, $n$sokoban$n$, $n$Les caisses au bon endroit$n$, $n$Pousser, prévoir et garder une place pour contourner.$n$, $n$Pousser, prévoir et garder une place pour contourner.$n$, $n$cooperation$n$, 3, 10, 'standard', 99, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-099.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Toutes les caisses sur les cibles ; annuler un coup disponible.", "setup": "Pièce 6x6, deux caisses et deux cibles ; un pion contrôlé alternativement.", "turn": "Un déplacement peut pousser une caisse si la case derrière est libre ; impossible de tirer."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-099$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-100$n$, $n$cooperation-missions$n$, $n$packing$n$, $n$Le sac bien rempli$n$, $n$Faire tenir toutes les pièces, pas seulement celles qui arrangent.$n$, $n$Faire tenir toutes les pièces, pas seulement celles qui arrangent.$n$, $n$cooperation$n$, 3, 10, 'standard', 100, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-100.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Toutes les 20 cases couvertes exactement une fois.", "setup": "Plateau 5x4 et cinq tétriminos ; pièces réparties 3 pour A, 2 pour B.", "turn": "Placer ou tourner une pièce de son inventaire sans chevauchement ; proposer une modification de la pièce de l’autre."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-100$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-101$n$, $n$cooperation-missions$n$, $n$relay_machine$n$, $n$La machine à boutons$n$, $n$Chacun contrôle une partie d’une machine très concrète.$n$, $n$Chacun contrôle une partie d’une machine très concrète.$n$, $n$cooperation$n$, 3, 10, 'standard', 101, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-101.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Réussite lorsque B expédie avec énergie ≥6 et chaleur ≤2. Échec immédiat si chaleur >4. Réserve à zéro : A passe ; B peut encore refroidir puis expédier. Échec si réserve=0 et énergie<6. Aucun échec prématuré sur la seule réserve vide.", "setup": "Jauge énergie=0, chaleur=0, réserve=6 ; A ajoute de l’énergie, B refroidit ou expédie.", "turn": "A chauffe : énergie +2, chaleur +1, réserve -1. B refroidit : chaleur -2 minimum 0 ; ou expédie si énergie ≥6 et chaleur ≤2. Alterner les tours."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-101$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-102$n$, $n$cooperation-missions$n$, $n$route_budget$n$, $n$La livraison commune$n$, $n$Trouver un trajet qui ramasse tout avec une réserve limitée.$n$, $n$Trouver un trajet qui ramasse tout avec une réserve limitée.$n$, $n$cooperation$n$, 3, 10, 'standard', 102, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-102.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 7, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 7, "summary": {"end": "Arriver avec les deux colis avant épuisement ; trajet optimal fourni au serveur.", "setup": "Carte 5×5, départ, deux colis et une arrivée ; budget de déplacements indiqué par le niveau avant de commencer.", "turn": "À tour de rôle, déplacer le véhicule d’une case ; chaque mouvement coûte 1."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-102$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-103$n$, $n$cooperation-missions$n$, $n$balance$n$, $n$L’équilibre partagé$n$, $n$Placer les masses au bon endroit pour stabiliser une balance.$n$, $n$Placer les masses au bon endroit pour stabiliser une balance.$n$, $n$cooperation$n$, 3, 10, 'standard', 103, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-103.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Somme poids×position = 0 et tous les poids utilisés.", "setup": "Une barre avec positions -3,-2,-1,+1,+2,+3 ; poids 1,1,2,2,3,3 répartis.", "turn": "Placer un poids à une position libre ; chacun peut déplacer ses propres poids avant validation."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-103$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-104$n$, $n$cooperation-missions$n$, $n$schedule$n$, $n$Le rendez-vous à reconstruire$n$, $n$Croiser des horaires fictifs sans partager tout son tableau.$n$, $n$Croiser des horaires fictifs sans partager tout son tableau.$n$, $n$cooperation$n$, 3, 10, 'standard', 104, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-104.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Une seule paire satisfait toutes les contraintes ; 3 dossiers.", "setup": "A voit les disponibilités de lieu, B celles de trajet ; quatre créneaux possibles.", "turn": "Échanger des contraintes puis choisir lieu et créneau."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-104$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-105$n$, $n$cooperation-missions$n$, $n$deduction$n$, $n$L’objet disparu$n$, $n$Une petite enquête avec des faits qui résistent à la vérification.$n$, $n$Une petite enquête avec des faits qui résistent à la vérification.$n$, $n$cooperation$n$, 3, 10, 'standard', 105, 'published', false,
    $n$coming_soon$n$, false, true, array[$n$facile$n$,$n$normal$n$]::text[], $n$/assets/jeux/vignettes/N2-105.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "GEN", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["toucher"], "interaction": "tour par tour synchronisé", "level_count": 1, "summary": {"end": "Une affectation unique de tous les objets et pièces ; correction expliquée.", "setup": "Trois personnes, trois objets, trois pièces ; indices répartis sur les écrans.", "turn": "Compléter une grille d’association ; discuter les exclusions avant de proposer le tableau."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-105$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-106$n$, $n$histoires-improvisation$n$, $n$story_relay$n$, $n$Une phrase chacun$n$, $n$Construire un récit en se laissant de la place.$n$, $n$Construire un récit en se laissant de la place.$n$, $n$echange$n$, 3, 10, 'standard', 106, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-106.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "La huitième phrase conclut ; titre commun et export texte.", "setup": "Un début concret et un objectif de fin ; 8 phrases au total.", "turn": "Écrire une phrase de 180 caractères maximum à son tour ; les phrases précédentes restent visibles."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-106$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-107$n$, $n$histoires-improvisation$n$, $n$story_icons$n$, $n$Trois symboles, une histoire$n$, $n$Trois images obligent à trouver un lien inattendu.$n$, $n$Trois images obligent à trouver un lien inattendu.$n$, $n$echange$n$, 3, 10, 'standard', 107, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-107.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Les trois symboles ont été intégrés selon validation mutuelle.", "setup": "Tirer 3 symboles distincts ; chacun écrit un morceau de récit qui en utilise au moins un.", "turn": "A commence, B poursuit, A conclut ; chacun indique les symboles employés."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-107$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-108$n$, $n$histoires-improvisation$n$, $n$ending$n$, $n$La chute secrète$n$, $n$Même départ, deux fins qui n’avaient aucune raison de se ressembler.$n$, $n$Même départ, deux fins qui n’avaient aucune raison de se ressembler.$n$, $n$echange$n$, 3, 10, 'standard', 108, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-108.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "choix privés puis révélation", "level_count": 0, "summary": {"end": "Deux fins conservables ; aucun vote obligatoire ni gagnant.", "setup": "Une amorce commune de deux lignes ; réponses privées.", "turn": "Chacun écrit une chute de 300 caractères ; révéler simultanément puis choisir une réaction."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-108$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-109$n$, $n$histoires-improvisation$n$, $n$madlibs$n$, $n$L’histoire à trous$n$, $n$Choisir des mots avant de découvrir où ils vont tomber.$n$, $n$Choisir des mots avant de découvrir où ils vont tomber.$n$, $n$echange$n$, 3, 10, 'standard', 109, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-109.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 8, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Lecture du texte complet, puis permutation des rôles.", "setup": "A reçoit quatre champs typés sans le texte ; B reçoit les quatre autres.", "turn": "Saisir les noms, adjectifs et verbes demandés ; injecter dans le gabarit et révéler."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-109$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-110$n$, $n$histoires-improvisation$n$, $n$object_dialogue$n$, $n$Le dialogue des objets$n$, $n$Donner une mauvaise humeur ou un grand rêve à deux objets.$n$, $n$Donner une mauvaise humeur ou un grand rêve à deux objets.$n$, $n$echange$n$, 3, 10, 'standard', 110, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-110.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Dernière réplique propose un compromis ou une chute.", "setup": "Tirer deux objets et un désaccord banal ; chaque joueur incarne un objet.", "turn": "Écrire 6 répliques alternées en gardant le rôle attribué."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-110$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-111$n$, $n$histoires-improvisation$n$, $n$sales_pitch$n$, $n$Le vendeur de l’impossible$n$, $n$Vendre une invention absurde avec un argument presque convaincant.$n$, $n$Vendre une invention absurde avec un argument presque convaincant.$n$, $n$echange$n$, 3, 10, 'standard', 111, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-111.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Deux annonces affichées avec réactions libres, sans concours de persuasion réel.", "setup": "Un objet et une fonction impossible tirés ensemble ; A prépare une annonce de 250 caractères.", "turn": "B ajoute une objection en une phrase ; A répond par une dernière promesse. Inverser."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-111$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-112$n$, $n$histoires-improvisation$n$, $n$postcard$n$, $n$La carte postale impossible$n$, $n$Écrire depuis un endroit qui n’existe que dans le jeu.$n$, $n$Écrire depuis un endroit qui n’existe que dans le jeu.$n$, $n$echange$n$, 3, 10, 'standard', 112, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-112.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "1 point commun si destination devinée ; 4 cartes.", "setup": "Destination secrète parmi 24 lieux imaginaires ; modèle de carte postale illustrée.", "turn": "A rédige 3 indices sans nommer le lieu ; B choisit entre 4 destinations puis les rôles changent."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-112$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-113$n$, $n$histoires-improvisation$n$, $n$three_tones$n$, $n$La scène en trois tons$n$, $n$Le même incident devient comique, mystérieux puis tendre.$n$, $n$Le même incident devient comique, mystérieux puis tendre.$n$, $n$echange$n$, 3, 10, 'standard', 113, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-113.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "6 répliques affichées en trois colonnes.", "setup": "Une scène simple et trois tons dans un ordre tiré.", "turn": "Écrire chacun une réplique par ton ; garder les mêmes personnages et le même incident."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-113$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-114$n$, $n$histoires-improvisation$n$, $n$character$n$, $n$Le personnage à deviner$n$, $n$Jouer un trait sans le nommer.$n$, $n$Jouer un trait sans le nommer.$n$, $n$echange$n$, 3, 10, 'standard', 114, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-114.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "1 point par trait identifié ; inverser les rôles.", "setup": "A reçoit trois traits compatibles et une situation ; B voit seulement la situation.", "turn": "Échanger 6 répliques ; B sélectionne ensuite les trois traits parmi 8 propositions."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-114$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-115$n$, $n$histoires-improvisation$n$, $n$weird_menu$n$, $n$Le restaurant bizarre$n$, $n$Composer un menu cohérent dans un lieu qui ne l’est pas.$n$, $n$Composer un menu cohérent dans un lieu qui ne l’est pas.$n$, $n$echange$n$, 3, 10, 'standard', 115, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-115.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Menu illustré commun, sans score.", "setup": "Un lieu insolite, 6 ingrédients virtuels et 3 noms de plats à remplir.", "turn": "A invente l’entrée, B le plat, A le dessert ; B rédige le slogan du restaurant."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-115$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-116$n$, $n$histoires-improvisation$n$, $n$dubbing$n$, $n$Le doublage muet$n$, $n$Donner une voix à une petite animation sans paroles.$n$, $n$Donner une voix à une petite animation sans paroles.$n$, $n$echange$n$, 3, 10, 'standard', 116, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-116.svg$n$, $n$2.1.0$n$, $n${"audio_optional": true, "bank_type": "BANK", "content_count": 6, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Mini-film de 10 s rejouable ; voix optionnelle enregistrée séparément.", "setup": "Une animation SVG de 3 scènes : entrée, incident, réaction ; bulles vides.", "turn": "Chaque joueur remplit les bulles de son personnage ; rejouer la séquence avec les deux textes."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-116$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-117$n$, $n$histoires-improvisation$n$, $n$poem$n$, $n$Le poème de poche$n$, $n$Écrire quelque chose de joli sans chercher à impressionner.$n$, $n$Écrire quelque chose de joli sans chercher à impressionner.$n$, $n$echange$n$, 3, 10, 'standard', 117, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-117.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Quatrain mis en page sur une carte ; aucune note littéraire.", "setup": "Trois mots concrets et une forme de quatre vers ; alternance A-B-A-B.", "turn": "Chaque vers contient jusqu’à 60 caractères ; utiliser les trois mots au moins une fois selon confirmation mutuelle."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-117$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-118$n$, $n$histoires-improvisation$n$, $n$character_inventory$n$, $n$La valise des personnages$n$, $n$Faire deviner un personnage inventé à partir de ce qu’il emporte.$n$, $n$Faire deviner un personnage inventé à partir de ce qu’il emporte.$n$, $n$echange$n$, 3, 10, 'standard', 118, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-118.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Comparer deux interprétations, puis inverser ; pas de bonne réponse absolue.", "setup": "A choisit 4 objets et un métier fictif dans une liste privée.", "turn": "B voit la valise, propose un portrait en 200 caractères ; A révèle son idée."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-118$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-119$n$, $n$histoires-improvisation$n$, $n$branch_story$n$, $n$Le récit à embranchements$n$, $n$Laisser l’autre décider au moment où l’histoire bascule.$n$, $n$Laisser l’autre décider au moment où l’histoire bascule.$n$, $n$echange$n$, 3, 10, 'standard', 119, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-119.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 24, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Le dernier narrateur écrit une fin qui respecte les choix précédents.", "setup": "Une amorce ; A écrit une suite et deux actions possibles, sans question imposée.", "turn": "B choisit une action puis devient narrateur et propose deux nouvelles actions ; 4 décisions."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-119$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-120$n$, $n$histoires-improvisation$n$, $n$soundscape$n$, $n$Le paysage sonore$n$, $n$Composer un endroit avec des sons simples et originaux.$n$, $n$Composer un endroit avec des sons simples et originaux.$n$, $n$echange$n$, 3, 10, 'standard', 120, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-120.svg$n$, $n$2.1.0$n$, $n${"audio_optional": true, "bank_type": "BANK", "content_count": 4, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "tour par tour synchronisé", "level_count": 0, "summary": {"end": "Écouter les 8 temps puis révéler les titres ; texte et animation remplacent le son si nécessaire.", "setup": "Séquenceur de 8 pas, quatre sons synthétisés et deux ambiances abstraites.", "turn": "A place deux sons, B deux autres ; chacun ajoute un titre secret au paysage."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-120$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-121$n$, $n$complicite-confidences$n$, $n$taste_map$n$, $n$La carte de tes goûts$n$, $n$Une petite carte qui ressemble à ta semaine, pas à un profil figé.$n$, $n$Une petite carte qui ressemble à ta semaine, pas à un profil figé.$n$, $n$creation$n$, 3, 10, 'standard', 121, 'published', false,
    $n$playable$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-121.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "toucher et création", "level_count": 0, "summary": {"end": "Deux cartes côte à côte ; pas de pourcentage de ressemblance. Chacun peut garder sa carte privée après la partie.", "setup": "Afficher 12 étiquettes de goûts et un plateau à trois zones : « souvent », « parfois », « pas mon truc ». Aucune zone n'est préremplie.", "turn": "Chacun déplace 6 étiquettes de son choix, puis ajoute un détail facultatif de 80 caractères sur une étiquette. Révéler ensemble ; toucher une différence pour demander à en entendre davantage, sans réponse obligatoire."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-121$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-121$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-121$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-121$n$), 0) + 1, $n${"details": ["Pas de pourcentage de ressemblance.", "Une étiquette laissée de côté n'est pas un désaccord ; répondre n'est jamais obligatoire."], "how_to": ["Place jusqu'à six étiquettes dans les trois zones.", "Ajoute un détail facultatif sur l'une d'elles (80 caractères).", "Révélez, puis touchez une étiquette de l'autre pour en savoir plus."], "objective": "La carte de tes goûts : souvent, parfois, pas mon truc.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"ask": {"confirm": "Demander", "hint": "Une question facultative.", "prompt": "Touche une étiquette de {name}.", "title": "En savoir plus"}, "map": {"confirm": "Valider ma carte", "hint": "Touche une étiquette, puis une zone.", "prompt": "Range tes goûts.", "title": "Ta carte"}, "reply": {"confirm": "Répondre", "hint": "Facultatif.", "prompt": "Si tu en as envie.", "title": "Répondre"}}}$n$::jsonb, $n${"after": [{"key": "ask", "kind": "ask", "params": {"from": "map"}}, {"key": "reply", "kind": "reaction", "params": {"max": 200}}], "draw": {"fixed": {"zones": ["souvent", "parfois", "pas mon truc"]}, "lists": [{"bank": "taste_labels", "count": null, "key": "labels"}]}, "engine": "rounds", "mechanic": "taste_map", "rounds": 1, "steps": [{"key": "map", "kind": "zones", "params": {"max": 6}}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["Pas de pourcentage de ressemblance.", "Une étiquette laissée de côté n'est pas un désaccord ; répondre n'est jamais obligatoire."], "how_to": ["Place jusqu'à six étiquettes dans les trois zones.", "Ajoute un détail facultatif sur l'une d'elles (80 caractères).", "Révélez, puis touchez une étiquette de l'autre pour en savoir plus."], "objective": "La carte de tes goûts : souvent, parfois, pas mon truc.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"ask": {"confirm": "Demander", "hint": "Une question facultative.", "prompt": "Touche une étiquette de {name}.", "title": "En savoir plus"}, "map": {"confirm": "Valider ma carte", "hint": "Touche une étiquette, puis une zone.", "prompt": "Range tes goûts.", "title": "Ta carte"}, "reply": {"confirm": "Répondre", "hint": "Facultatif.", "prompt": "Si tu en as envie.", "title": "Répondre"}}}$n$::jsonb and cur.config = $n${"after": [{"key": "ask", "kind": "ask", "params": {"from": "map"}}, {"key": "reply", "kind": "reaction", "params": {"max": 200}}], "draw": {"fixed": {"zones": ["souvent", "parfois", "pas mon truc"]}, "lists": [{"bank": "taste_labels", "count": null, "key": "labels"}]}, "engine": "rounds", "mechanic": "taste_map", "rounds": 1, "steps": [{"key": "map", "kind": "zones", "params": {"max": 6}}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-121$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-122$n$, $n$complicite-confidences$n$, $n$gift_box$n$, $n$La boîte à surprises$n$, $n$Prépare un petit paquet numérique avec une surprise à chaque étage.$n$, $n$Prépare un petit paquet numérique avec une surprise à chaque étage.$n$, $n$creation$n$, 3, 10, 'standard', 122, 'published', false,
    $n$playable$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-122.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "toucher et création", "level_count": 0, "summary": {"end": "Deux boîtes terminées, exportables séparément après accord sur le partage. Aucun gage ni achat réel.", "setup": "Choisir une boîte, un ruban et trois compartiments : un objet symbolique, un mot et un petit dessin. Rien n'est envoyé avant confirmation.", "turn": "Composer en privé ; A et B valident puis découvrent chacun le paquet de l’autre, un compartiment à la fois. Le receveur décide quand ouvrir le suivant."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-122$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-122$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-122$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-122$n$), 0) + 1, $n${"details": ["Aucun gage, aucun achat réel.", "Rien n'est envoyé avant ta confirmation ; aucun message n'est écrit à ta place."], "how_to": ["Choisis un papier et un ruban.", "Remplis les trois compartiments (chacun peut rester vide).", "Quand vous avez validé tous les deux, chacun ouvre la boîte de l'autre, un compartiment à la fois."], "objective": "La boîte à surprises : un objet symbolique, un mot et un petit dessin pour l'autre.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"gift": {"confirm": "Fermer la boîte", "hint": "Un compartiment peut rester vide.", "prompt": "Prépare une surprise pour {name}.", "title": "Ta boîte"}}}$n$::jsonb, $n${"after": [], "draw": {"fixed": {"papers": [{"hex": "#F17868", "name": "papier corail"}, {"hex": "#A9D9C2", "name": "papier menthe"}, {"hex": "#F4D57A", "name": "papier jaune"}, {"hex": "#91BDD4", "name": "papier bleu"}, {"hex": "#C7B5E5", "name": "papier lilas"}, {"hex": "#D9B48F", "name": "papier kraft"}], "ribbons": [{"hex": "#663C59", "name": "ruban prune"}, {"hex": "#FFF5E8", "name": "ruban crème"}, {"hex": "#F17868", "name": "ruban rayé"}, {"hex": "#C9A227", "name": "ruban doré"}]}, "lists": [{"bank": "gift_prompts", "count": 3, "key": "prompts"}, {"bank": "objects", "count": 12, "key": "objects"}]}, "engine": "rounds", "mechanic": "gift_box", "rounds": 1, "steps": [{"key": "gift", "kind": "gift"}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["Aucun gage, aucun achat réel.", "Rien n'est envoyé avant ta confirmation ; aucun message n'est écrit à ta place."], "how_to": ["Choisis un papier et un ruban.", "Remplis les trois compartiments (chacun peut rester vide).", "Quand vous avez validé tous les deux, chacun ouvre la boîte de l'autre, un compartiment à la fois."], "objective": "La boîte à surprises : un objet symbolique, un mot et un petit dessin pour l'autre.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"gift": {"confirm": "Fermer la boîte", "hint": "Un compartiment peut rester vide.", "prompt": "Prépare une surprise pour {name}.", "title": "Ta boîte"}}}$n$::jsonb and cur.config = $n${"after": [], "draw": {"fixed": {"papers": [{"hex": "#F17868", "name": "papier corail"}, {"hex": "#A9D9C2", "name": "papier menthe"}, {"hex": "#F4D57A", "name": "papier jaune"}, {"hex": "#91BDD4", "name": "papier bleu"}, {"hex": "#C7B5E5", "name": "papier lilas"}, {"hex": "#D9B48F", "name": "papier kraft"}], "ribbons": [{"hex": "#663C59", "name": "ruban prune"}, {"hex": "#FFF5E8", "name": "ruban crème"}, {"hex": "#F17868", "name": "ruban rayé"}, {"hex": "#C9A227", "name": "ruban doré"}]}, "lists": [{"bank": "gift_prompts", "count": 3, "key": "prompts"}, {"bank": "objects", "count": 12, "key": "objects"}]}, "engine": "rounds", "mechanic": "gift_box", "rounds": 1, "steps": [{"key": "gift", "kind": "gift"}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-122$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-123$n$, $n$complicite-confidences$n$, $n$zine$n$, $n$Le mini-fanzine à deux$n$, $n$Quatre petites pages pour garder une trace de votre humeur du jour.$n$, $n$Quatre petites pages pour garder une trace de votre humeur du jour.$n$, $n$creation$n$, 3, 10, 'standard', 123, 'published', false,
    $n$playable$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-123.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "toucher et création", "level_count": 0, "summary": {"end": "Assembler les quatre pages avec navigation tactile. Enregistrer ou exporter après validation des deux.", "setup": "Ouvrir quatre pages : couverture commune, page de A, page de B, dernière page commune. Distribuer à chacun texte, gommettes et crayon.", "turn": "A et B composent leur page en parallèle ; chacun choisit ensuite un détail à proposer pour la couverture. La dernière page reçoit une création commune, en alternant deux interventions."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-123$n$, case when inserted then 'added' else 'updated' end from up;

-- Version de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with cur as (
  select v.rules, v.config from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version
  where g.id = $n$N2-123$n$
), ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select $n$N2-123$n$, coalesce((select max(version) from public.game_versions where game_id = $n$N2-123$n$), 0) + 1, $n${"details": ["Ta page reste privée jusqu'à la validation ; l'autre ne peut ni la modifier ni la publier.", "Enregistrement dans l'Espace seulement si vous le choisissez tous les deux."], "how_to": ["Compose ta page : texte (200 caractères), gommettes et crayon.", "Propose un détail de ta page pour la couverture.", "Après la révélation, la dernière page se remplit en alternant deux interventions chacun."], "objective": "Le mini-fanzine à deux : une couverture commune, une page chacun, une dernière page ensemble.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"cover": {"confirm": "Proposer", "hint": "Une gommette posée ou une courte phrase.", "prompt": "Quel détail de ta page proposes-tu ?", "title": "Pour la couverture"}, "last": {"confirm": "Ajouter", "hint": "80 caractères.", "prompt": "À ton tour d'ajouter une ligne ou une gommette.", "title": "Dernière page"}, "page": {"confirm": "Valider ma page", "hint": "Texte, gommettes et dessin : au moins un des trois.", "prompt": "Thème : {theme}", "title": "Ta page"}}}$n$::jsonb, $n${"after": [{"key": "last1", "kind": "line", "who": "seat1"}, {"after": "last1", "key": "last2", "kind": "line", "who": "seat2"}, {"after": "last2", "key": "last3", "kind": "line", "who": "seat1"}, {"after": "last3", "key": "last4", "kind": "line", "who": "seat2"}], "draw": {"lists": [{"bank": "zine_themes", "count": 1, "key": "themes"}, {"bank": "stickers", "count": null, "key": "stickers"}]}, "engine": "rounds", "mechanic": "zine", "rounds": 1, "steps": [{"key": "page", "kind": "page"}, {"key": "cover", "kind": "cover_pick", "params": {"from": "page"}}]}$n$::jsonb, now()
  where not exists (select 1 from cur where cur.rules = $n${"details": ["Ta page reste privée jusqu'à la validation ; l'autre ne peut ni la modifier ni la publier.", "Enregistrement dans l'Espace seulement si vous le choisissez tous les deux."], "how_to": ["Compose ta page : texte (200 caractères), gommettes et crayon.", "Propose un détail de ta page pour la couverture.", "Après la révélation, la dernière page se remplit en alternant deux interventions chacun."], "objective": "Le mini-fanzine à deux : une couverture commune, une page chacun, une dernière page ensemble.", "privacy": "Tes réponses restent cachées jusqu'à ce que vous ayez confirmé tous les deux. Tu peux toujours passer.", "step_texts": {"cover": {"confirm": "Proposer", "hint": "Une gommette posée ou une courte phrase.", "prompt": "Quel détail de ta page proposes-tu ?", "title": "Pour la couverture"}, "last": {"confirm": "Ajouter", "hint": "80 caractères.", "prompt": "À ton tour d'ajouter une ligne ou une gommette.", "title": "Dernière page"}, "page": {"confirm": "Valider ma page", "hint": "Texte, gommettes et dessin : au moins un des trois.", "prompt": "Thème : {theme}", "title": "Ta page"}}}$n$::jsonb and cur.config = $n${"after": [{"key": "last1", "kind": "line", "who": "seat1"}, {"after": "last1", "key": "last2", "kind": "line", "who": "seat2"}, {"after": "last2", "key": "last3", "kind": "line", "who": "seat1"}, {"after": "last3", "key": "last4", "kind": "line", "who": "seat2"}], "draw": {"lists": [{"bank": "zine_themes", "count": 1, "key": "themes"}, {"bank": "stickers", "count": null, "key": "stickers"}]}, "engine": "rounds", "mechanic": "zine", "rounds": 1, "steps": [{"key": "page", "kind": "page"}, {"key": "cover", "kind": "cover_pick", "params": {"from": "page"}}]}$n$::jsonb)
  returning version
)
update public.games set current_version = (select version from ins) where id = $n$N2-123$n$ and exists (select 1 from ins);

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-124$n$, $n$mots-repartie$n$, $n$word_growth$n$, $n$Le mot à rallonge$n$, $n$Un mot minuscule prend de la place à chaque tour.$n$, $n$Un mot minuscule prend de la place à chaque tour.$n$, $n$cooperation$n$, 3, 10, 'standard', 124, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-124.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "LEVEL", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "actions alternées ou confirmations privées", "level_count": 12, "summary": {"end": "Atteindre une feuille du graphe ; score commun = nombre d’étapes. Révéler les chemins possibles après la fin.", "setup": "Choisir un chemin du lexique fermé. Afficher le mot de départ et les lettres disponibles, sans dévoiler la cible finale.", "turn": "À son tour, ajouter exactement une lettre puis réordonner toutes les lettres pour obtenir un mot accepté du chemin ou de ses branches. Une lettre ne peut pas disparaître."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-124$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-125$n$, $n$mots-repartie$n$, $n$cross_letters$n$, $n$Les mots qui se croisent$n$, $n$Construis une petite grille avec les mots déjà sous les yeux.$n$, $n$Construis une petite grille avec les mots déjà sous les yeux.$n$, $n$cooperation$n$, 3, 10, 'standard', 125, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-125.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "LEVEL", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "actions alternées ou confirmations privées", "level_count": 12, "summary": {"end": "Les deux mots attendus sont lisibles dans leur sens normal et le centre concorde. Variante libre seulement après le niveau résolu.", "setup": "Donner deux mots de longueur 5 et un plateau en croix 5×5. Le centre est commun ; les lettres sont présentées en tuiles mobiles.", "turn": "A remplit l’horizontale et B la verticale. Une lettre au centre doit convenir aux deux mots ; chacun dispose d’un bouton proposer avant confirmation commune."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-125$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-126$n$, $n$mots-repartie$n$, $n$rebus$n$, $n$Les rébus en morceaux$n$, $n$Des images très simples, des sons à assembler et un mot qui finit par apparaître.$n$, $n$Des images très simples, des sons à assembler et un mot qui finit par apparaître.$n$, $n$cooperation$n$, 3, 10, 'standard', 126, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-126.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "LEVEL", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "actions alternées ou confirmations privées", "level_count": 12, "summary": {"end": "Un mot trouvé ou une explication affichée ; 6 rébus par partie, sans pénalité pour l’accent.", "setup": "Afficher deux pictogrammes et, au besoin, la lecture conventionnelle de chacun. Les rébus sont des jeux de sons, pas des devinettes d’orthographe.", "turn": "Chacun peut proposer une réponse texte ; l’autre confirme ou écrit une autre piste. Révéler l’indice de lecture à la demande, puis la solution après trois essais communs."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-126$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-127$n$, $n$dessin-creation$n$, $n$constellation$n$, $n$La constellation sonore$n$, $n$Relie quelques étoiles et transforme ton tracé en petite mélodie.$n$, $n$Relie quelques étoiles et transforme ton tracé en petite mélodie.$n$, $n$creation$n$, 3, 10, 'standard', 127, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-127.svg$n$, $n$2.1.0$n$, $n${"audio_optional": true, "bank_type": "LEVEL", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "toucher et création", "level_count": 12, "summary": {"end": "Jouer la ligne du temps de 8 notes et révéler le nom choisi ensemble. Animation et noms de notes remplacent le son.", "setup": "Placer 8 étoiles dans une aire 5×5. Chacune porte une note de la gamme do-ré-mi-sol-la ; son désactivé jusqu’à un toucher explicite.", "turn": "A relie deux étoiles, B prolonge d’une étoile, puis alterner jusqu’à 8 notes. Toucher une étoile deux fois permet de répéter la note ; glisser n’est jamais obligatoire."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-127$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-128$n$, $n$dessin-creation$n$, $n$flipbook$n$, $n$Le flipbook de poche$n$, $n$Une tasse qui saute, un nuage qui éternue : huit images suffisent.$n$, $n$Une tasse qui saute, un nuage qui éternue : huit images suffisent.$n$, $n$creation$n$, 3, 10, 'standard', 128, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-128.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "toucher et création", "level_count": 0, "summary": {"end": "Lire l’animation à 4 images/seconde, avec pause et image suivante. Exporter en planche PNG ; aucun encodeur vidéo requis.", "setup": "Choisir une scène et ouvrir 8 vignettes ; A possède les images impaires, B les paires. Une silhouette fantôme montre l’image précédente avec opacité 20 %.", "turn": "Sur chaque vignette, déplacer ou tourner les deux objets et ajouter au plus 3 traits. Les deux joueurs peuvent feuilleter l’ensemble sans modifier les images de l’autre."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-128$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-129$n$, $n$dessin-creation$n$, $n$weaving$n$, $n$Le petit métier à tisser$n$, $n$Croise les couleurs, décide du dessus et fabrique un motif commun.$n$, $n$Croise les couleurs, décide du dessus et fabrique un motif commun.$n$, $n$creation$n$, 3, 10, 'standard', 129, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-129.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "LEVEL", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "toucher et création", "level_count": 12, "summary": {"end": "Un textile 6×6, signé d’un titre commun. En modèle, vérifier les 36 orientations ; en libre, aucune note.", "setup": "Plateau de 6 fils verticaux et 6 fils horizontaux. A choisit les couleurs verticales, B les horizontales dans la même palette.", "turn": "Aux intersections, alterner dessus/dessous selon le motif choisi : toile, bandes ou libre. Chaque joueur modifie les intersections de sa moitié ; l’autre peut proposer une inversion."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-129$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-130$n$, $n$memoire-observation$n$, $n$silhouette$n$, $n$La silhouette juste$n$, $n$Reconnais une forme quand elle a perdu toutes ses couleurs.$n$, $n$Reconnais une forme quand elle a perdu toutes ses couleurs.$n$, $n$duel$n$, 3, 10, 'standard', 130, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-130.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "LEVEL", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "actions alternées ou confirmations privées", "level_count": 12, "summary": {"end": "1 point si juste ; 6 manches. L’indice laisse le score ludique inchangé mais apparaît au récapitulatif.", "setup": "Montrer la silhouette d’un objet et quatre objets en couleur issus de silhouettes distinctes ; l’échelle de tous les choix est identique.", "turn": "Choisir en privé, confirmer puis révéler. Un indice affiche une partie colorée de la cible ; aucun temps de réaction n’est comparé."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-130$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-131$n$, $n$memoire-observation$n$, $n$layers$n$, $n$Qui passe devant ?$n$, $n$Quelques formes se cachent mutuellement : retrouve leur ordre.$n$, $n$Quelques formes se cachent mutuellement : retrouve leur ordre.$n$, $n$duel$n$, 3, 10, 'standard', 131, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-131.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "LEVEL", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "actions alternées ou confirmations privées", "level_count": 12, "summary": {"end": "Ordre exact validé ; 6 scènes. Un indice révèle la position d’une couche, sans changer les autres.", "setup": "Afficher trois disques de même taille, partiellement superposés en diagonale, chacun avec un motif et un numéro. Chaque paire voisine se recouvre.", "turn": "Replacer les trois disques dans une pile « fond → devant ». L’aperçu du candidat est disponible après confirmation seulement."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-131$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-132$n$, $n$memoire-observation$n$, $n$rotation$n$, $n$La vitrine tournante$n$, $n$Le même petit plateau a tourné : retrouve où chaque objet doit aller.$n$, $n$Le même petit plateau a tourné : retrouve où chaque objet doit aller.$n$, $n$duel$n$, 3, 10, 'standard', 132, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-132.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "LEVEL", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "actions alternées ou confirmations privées", "level_count": 12, "summary": {"end": "Nombre de positions correctes sur 3 ; 6 manches. Afficher ensuite l’animation de rotation et la correspondance de chaque case.", "setup": "Montrer une grille 3×3 avec trois objets distincts et une flèche indiquant un quart ou un demi-tour. Le modèle reste visible.", "turn": "Chacun replace les objets dans une grille vide orientée comme indiqué. Les joueurs peuvent discuter avant de verrouiller leur réponse."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-132$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-133$n$, $n$logique-codes$n$, $n$akari$n$, $n$Allume la galerie$n$, $n$Une lampe bien placée peut éclairer toute une allée.$n$, $n$Une lampe bien placée peut éclairer toute une allée.$n$, $n$cooperation$n$, 3, 10, 'standard', 133, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-133.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "LEVEL", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "actions alternées ou confirmations privées", "level_count": 12, "summary": {"end": "Toutes les cases blanches sont éclairées, aucun conflit, tous les nombres respectés. La banque est vérifiée à solution unique.", "setup": "Grille 4×4 avec murs et indices. A et B partagent le même plateau ; les notes de case sont communes.", "turn": "Poser ou retirer une lampe. Elle éclaire horizontalement et verticalement jusqu’au mur. Aucune lampe ne doit en éclairer une autre ; chaque mur numéroté compte les lampes orthogonalement adjacentes."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-133$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-134$n$, $n$logique-codes$n$, $n$slant$n$, $n$Les diagonales tranquilles$n$, $n$Un trait par case, des chiffres aux coins et aucune boucle.$n$, $n$Un trait par case, des chiffres aux coins et aucune boucle.$n$, $n$cooperation$n$, 3, 10, 'standard', 134, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-134.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "LEVEL", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "actions alternées ou confirmations privées", "level_count": 12, "summary": {"end": "Tous les degrés indiqués sont respectés et les traits ne forment aucun cycle. Chaque niveau livré a une solution unique.", "setup": "Grille 3×3 de cases et 4×4 de sommets. Certains sommets portent le nombre de diagonales qui doivent les toucher.", "turn": "Toucher une case pour cycler vide, diagonale descendante, diagonale montante. Une diagonale doit figurer dans chaque case à la fin."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-134$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-135$n$, $n$logique-codes$n$, $n$hanoi$n$, $n$Les tours à déplacer$n$, $n$Déplacer trois petits disques semble simple. Jusqu’au premier détour.$n$, $n$Déplacer trois petits disques semble simple. Jusqu’au premier détour.$n$, $n$cooperation$n$, 3, 10, 'standard', 135, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-135.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "LEVEL", "content_count": 3, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "actions alternées ou confirmations privées", "level_count": 3, "summary": {"end": "Pile entière sur la tige cible. Montrer le nombre de coups et le minimum théorique 2^n-1 après réussite.", "setup": "Trois tiges, 3 à 5 disques empilés du plus grand au plus petit à gauche. La cible est la tige droite.", "turn": "À tour de rôle, sélectionner le disque supérieur d’une tige puis une destination vide ou surmontée d’un disque plus grand. Aucun autre disque ne se déplace."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-135$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-136$n$, $n$plateaux-strategie$n$, $n$shut_box$n$, $n$Ferme la boîte$n$, $n$Deux dés, neuf cases et le plaisir d’un compte juste.$n$, $n$Deux dés, neuf cases et le plaisir d’un compte juste.$n$, $n$duel$n$, 3, 10, 'standard', 136, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-136.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "LEVEL", "content_count": 3, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "actions alternées ou confirmations privées", "level_count": 3, "summary": {"end": "Sans combinaison légale, additionner les cases restantes ; boîte vide vaut 0. Après trois manches, le plus petit total gagne, égalité possible.", "setup": "Cases 1 à 9 ouvertes pour chacun. Trois manches ; même suite de dés préengagée côté serveur pour les deux joueurs, avec un index propre.", "turn": "Lancer deux dés. Fermer un sous-ensemble de cases ouvertes dont la somme vaut le total. Si 7, 8 et 9 sont fermées, choisir un ou deux dés AVANT le lancer."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-136$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-137$n$, $n$plateaux-strategie$n$, $n$pig$n$, $n$Encore un lancer ?$n$, $n$Tu peux encaisser. Tu peux aussi tenter le dé de trop.$n$, $n$Tu peux encaisser. Tu peux aussi tenter le dé de trop.$n$, $n$duel$n$, 3, 10, 'standard', 137, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-137.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "LEVEL", "content_count": 1, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "actions alternées ou confirmations privées", "level_count": 1, "summary": {"end": "Premier score encaissé ≥30 gagne ; à 30 tours achevés, plus haut score, puis égalité. Aucun argent ni achat de lancer.", "setup": "A et B commencent à 0 ; objectif 30 points, 30 tours maximum au total. Un tour peut comporter plusieurs lancers.", "turn": "Un résultat 2 à 6 s’ajoute à la cagnotte du tour. Encaisser ajoute cette cagnotte au score et passe la main. Un 1 efface seulement la cagnotte et termine le tour."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-137$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-138$n$, $n$plateaux-strategie$n$, $n$tricks$n$, $n$Le duel des cinq plis$n$, $n$Cinq cartes en main, une couleur à suivre et un atout à garder pour le bon moment.$n$, $n$Cinq cartes en main, une couleur à suivre et un atout à garder pour le bon moment.$n$, $n$duel$n$, 3, 10, 'standard', 138, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-138.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "LEVEL", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "actions alternées ou confirmations privées", "level_count": 12, "summary": {"end": "Cinq plis ; celui qui en gagne le plus remporte la donne. Trois donnes, premier joueur alterné ; aucun pari.", "setup": "Jeu de 15 cartes : soleil, lune, feuille, rangs 1 à 5. Distribuer 5 cartes à chacun ; une sixième carte commune fixe l’atout et reste hors jeu, 4 cartes sont écartées face cachée.", "turn": "A entame le premier pli. L’autre doit suivre la couleur s’il le peut ; sinon jouer n’importe quelle carte. Le plus fort atout gagne, sinon la plus forte carte de la couleur demandée. Le gagnant entame ensuite."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-138$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-139$n$, $n$cooperation-missions$n$, $n$mail_sort$n$, $n$Le tri du courrier$n$, $n$L’un lit les adresses, l’autre connaît les boîtes : il faut vous accorder.$n$, $n$L’un lit les adresses, l’autre connaît les boîtes : il faut vous accorder.$n$, $n$cooperation$n$, 3, 10, 'standard', 139, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-139.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "LEVEL", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "actions alternées ou confirmations privées", "level_count": 12, "summary": {"end": "Les six correspondances sont correctes ; révéler les erreurs avec leur adresse et proposer une correction commune.", "setup": "Six lettres numérotées et six boîtes à symboles. A voit la destination de chaque lettre ; B voit la correspondance destination-symbole.", "turn": "Échanger par texte, puis A choisit une lettre et B la boîte. La lettre est déposée après les deux confirmations ; un dépôt peut être repris avant validation finale."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-139$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-140$n$, $n$cooperation-missions$n$, $n$space_plan$n$, $n$Les deux astronautes$n$, $n$Préparez six actions pour rentrer avec les échantillons.$n$, $n$Préparez six actions pour rentrer avec les échantillons.$n$, $n$cooperation$n$, 3, 10, 'standard', 140, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-140.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "LEVEL", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "actions alternées ou confirmations privées", "level_count": 12, "summary": {"end": "Réussite en rentrant avec au moins 3 échantillons et des ressources non négatives. Échec si une action confirme un retour trop tôt ou si six actions passent sans retour.", "setup": "Oxygène 10, énergie 4, échantillons 0 ; six actions communes maximum. A choisit l’action, B la confirme. Le vaisseau démarre au camp.", "turn": "Actions : explorer coûte 2 oxygènes et 1 énergie et donne 1 échantillon ; recharger coûte 1 oxygène et donne 2 énergies ; rentrer coûte 2 oxygènes et clôt la mission. Discuter puis confirmer avant chaque action."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-140$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-141$n$, $n$cooperation-missions$n$, $n$logic_circuit$n$, $n$L’atelier des circuits$n$, $n$Trois interrupteurs, deux portes logiques et une lampe à allumer.$n$, $n$Trois interrupteurs, deux portes logiques et une lampe à allumer.$n$, $n$cooperation$n$, 3, 10, 'standard', 141, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-141.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "LEVEL", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "actions alternées ou confirmations privées", "level_count": 12, "summary": {"end": "Atteindre la sortie demandée ; plusieurs réglages peuvent être corrects. Révéler toutes les solutions après validation commune.", "setup": "A contrôle les interrupteurs x et y, B contrôle z. Le schéma indique clairement ET, OU, NON ou XOR avec sa table de vérité accessible.", "turn": "Modifier ses interrupteurs, prévoir la sortie ensemble, puis confirmer le test. Le serveur calcule le circuit à partir des trois booléens."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-141$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-142$n$, $n$histoires-improvisation$n$, $n$radio$n$, $n$Le studio radio$n$, $n$Votre émission dure une minute et peut annoncer absolument n’importe quel petit événement fictif.$n$, $n$Votre émission dure une minute et peut annoncer absolument n’importe quel petit événement fictif.$n$, $n$creation$n$, 3, 10, 'standard', 142, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-142.svg$n$, $n$2.1.0$n$, $n${"audio_optional": true, "bank_type": "BANK", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "toucher et création", "level_count": 0, "summary": {"end": "Une page d’émission et un jingle jouable. Export texte/PNG ; voix enregistrée seulement sur choix explicite, jamais requise.", "setup": "Quatre segments : jingle, titre, chronique, météo imaginaire. A prend le titre et la chronique, B le jingle et la météo ; inverser à la prochaine émission.", "turn": "Composer un jingle de 8 notes, écrire les textes dans les durées proposées puis prévisualiser la conduite. Lecture à voix haute facultative ; la version texte reste complète."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-142$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-143$n$, $n$histoires-improvisation$n$, $n$shadow_theatre$n$, $n$Le théâtre d’ombres$n$, $n$Deux silhouettes, trois poses et un petit incident à jouer.$n$, $n$Deux silhouettes, trois poses et un petit incident à jouer.$n$, $n$creation$n$, 3, 10, 'standard', 143, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-143.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "toucher et création", "level_count": 0, "summary": {"end": "Rejouer les trois tableaux avec une transition douce ou les lire un à un. Une pièce complète est exportable en trois vignettes.", "setup": "Un décor et deux personnages en silhouette ; chacun en contrôle un. Trois tableaux : entrée, incident, résolution.", "turn": "À chaque tableau, déplacer son personnage, choisir une pose et écrire une réplique de 100 caractères maximum. Confirmer puis passer au tableau suivant."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-143$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  values ($n$N2-144$n$, $n$histoires-improvisation$n$, $n$trailer$n$, $n$La bande-annonce$n$, $n$Six plans très courts pour donner envie de voir un film qui n’existe pas.$n$, $n$Six plans très courts pour donner envie de voir un film qui n’existe pas.$n$, $n$creation$n$, 3, 10, 'standard', 144, 'published', false,
    $n$coming_soon$n$, false, true, array[]::text[], $n$/assets/jeux/vignettes/N2-144.svg$n$, $n$2.1.0$n$, $n${"audio_optional": false, "bank_type": "BANK", "content_count": 12, "duration_hint": "3 à 10 min, estimation de conception", "inputs": ["texte", "toucher"], "interaction": "toucher et création", "level_count": 0, "summary": {"end": "Lire les six plans à 2 secondes chacun ou manuellement. Créer une affiche finale à partir du dernier plan, sans service vidéo externe.", "setup": "Six emplacements : monde, personnage, incident, obstacle, accélération, titre. Un genre et trois objets sont tirés ; aucun film existant à imiter.", "turn": "A compose les plans 1, 3, 5, B les plans 2, 4, 6. Un plan utilise un décor, deux objets maximum et une légende de 60 caractères. Monter les plans dans l’ordre voulu avant validation commune."}}$n$::jsonb)
  on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
    promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
    duration_max = excluded.duration_max, sort = excluded.sort, status = excluded.status, implementation = excluded.implementation,
    adult_available = excluded.adult_available, mute_ok = excluded.mute_ok, difficulties = excluded.difficulties,
    thumbnail = excluded.thumbnail, content_version = excluded.content_version, meta = excluded.meta
  where (games.category_id, games.mechanic, games.title, games.hook, games.style, games.sort, games.status, games.implementation,
         games.adult_available, games.difficulties, games.thumbnail, games.content_version, games.meta)
    is distinct from (excluded.category_id, excluded.mechanic, excluded.title, excluded.hook, excluded.style, excluded.sort,
         excluded.status, excluded.implementation, excluded.adult_available, excluded.difficulties, excluded.thumbnail,
         excluded.content_version, excluded.meta)
  returning (xmax = 0) as inserted
)
insert into import_log select 'game', $n$N2-144$n$, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.game_cards (id, game_id, kind, content, content_level, adult, topic_tags, theme, sort, status, is_demo, content_version)
  select v.id, v.game_id, 'question', v.content, case when v.adult then 'intime' else 'standard' end, v.adult, v.tags, v.theme, v.sort,
    'published', false, $n$2.1.0$n$
  from (values ($n$N2-001-C001$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel petit mensonge racontes-tu quand tu n'as aucune envie de sortir ?"}$n$::jsonb, false, array[$n$desir$n$]::text[], $n$drole$n$, 0), ($n$N2-001-C002$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel achat te fait encore rire tellement il ne te sert à rien ?"}$n$::jsonb, false, array[$n$humour$n$]::text[], $n$drole$n$, 1), ($n$N2-001-C003$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle chanson défends-tu alors que tout le monde la trouve ringarde ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 2), ($n$N2-001-C004$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel aliment manges-tu d'une manière qui fait râler les autres ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 3), ($n$N2-001-C005$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel message as-tu déjà envoyé à la mauvaise personne ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 4), ($n$N2-001-C006$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel mot te fait toujours hésiter au moment de le prononcer ?"}$n$::jsonb, false, array[$n$limites$n$]::text[], $n$drole$n$, 5), ($n$N2-001-C007$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle est ta technique pour faire semblant d'avoir compris une blague ?"}$n$::jsonb, false, array[$n$humour$n$]::text[], $n$drole$n$, 6), ($n$N2-001-C008$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel objet perds-tu alors qu'il était dans ta main dix secondes avant ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 7), ($n$N2-001-C009$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle tenue te semblait incroyable à l'époque et te fait sourire aujourd'hui ?"}$n$::jsonb, false, array[$n$humour$n$]::text[], $n$drole$n$, 8), ($n$N2-001-C010$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel détail ridicule peut te gâcher un film ?"}$n$::jsonb, false, array[$n$humour$n$]::text[], $n$drole$n$, 9), ($n$N2-001-C011$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle habitude te trahit quand tu essaies d'avoir l'air à l'aise ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 10), ($n$N2-001-C012$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel plat commandes-tu en prétendant que tu vas goûter autre chose cette fois ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 11), ($n$N2-001-C013$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel compliment t'a laissé sans réponse parce qu'il était vraiment bizarre ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 12), ($n$N2-001-C014$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle excuse peu crédible as-tu déjà sortie pour quitter une soirée ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 13), ($n$N2-001-C015$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle petite catastrophe en cuisine racontes-tu encore ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 14), ($n$N2-001-C016$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel petit tic te trahit quand tu te concentres ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 15), ($n$N2-001-C017$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle règle inventée chez toi te semble parfaitement normale ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 16), ($n$N2-001-C018$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel objet inutile refuses-tu de jeter ?"}$n$::jsonb, false, array[$n$limites$n$]::text[], $n$drole$n$, 17), ($n$N2-001-C019$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Dans quelle situation as-tu ri au pire moment ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 18), ($n$N2-001-C020$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle recherche internet récente pourrait faire rire quelqu'un qui la découvre ?"}$n$::jsonb, false, array[$n$humour$n$]::text[], $n$drole$n$, 19), ($n$N2-001-C021$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle appli ou quel jeu te fait perdre toute notion du temps ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 20), ($n$N2-001-C022$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle petite victoire te donne une fierté disproportionnée ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 21), ($n$N2-001-C023$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel surnom as-tu reçu et préféré oublier ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 22), ($n$N2-001-C024$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel talent complètement inutile mériterait quand même une médaille chez toi ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 23), ($n$N2-001-C025$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel petit geste te fait sentir qu'on a vraiment pensé à toi ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 24), ($n$N2-001-C026$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel souvenir de repas aimerais-tu revivre ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 25), ($n$N2-001-C027$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle partie de ta personnalité met du temps à se montrer ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 26), ($n$N2-001-C028$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle attention te touche plus qu'un cadeau cher ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 27), ($n$N2-001-C029$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel compliment as-tu gardé en tête longtemps ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 28), ($n$N2-001-C030$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle petite chose sur toi aimerais-tu qu'on retienne dès la première rencontre ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 29), ($n$N2-001-C031$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle chose sais-tu mieux faire que tu ne le laisses croire ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 30), ($n$N2-001-C032$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle journée ordinaire récente mériterait une photo souvenir ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 31), ($n$N2-001-C033$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel endroit t'aide à retrouver ton calme ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 32), ($n$N2-001-C034$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle invitation accepterais-tu presque toujours ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 33), ($n$N2-001-C035$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Qu'as-tu fini par aimer alors que tu jurais que ce n'était pas ton truc ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 34), ($n$N2-001-C036$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle amitié t'a appris quelque chose sur toi ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 35), ($n$N2-001-C037$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle petite liberté voudrais-tu protéger dans ta vie ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 36), ($n$N2-001-C038$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel projet repousses-tu alors qu'il te ferait du bien ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 37), ($n$N2-001-C039$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Qu'est-ce qui te donne confiance lors d'une première rencontre ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 38), ($n$N2-001-C040$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel genre d'humour te fait baisser la garde ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 39), ($n$N2-001-C041$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle qualité remarques-tu seulement après plusieurs conversations ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 40), ($n$N2-001-C042$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle odeur te ramène immédiatement à un souvenir précis ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 41), ($n$N2-001-C043$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel conseil as-tu ignoré avant de reconnaître qu'il était bon ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 42), ($n$N2-001-C044$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle chose aimerais-tu apprendre juste pour le plaisir ?"}$n$::jsonb, false, array[$n$sexualite$n$]::text[], $n$personnel$n$, 43), ($n$N2-001-C045$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quand tu es contrarié, qu'est-ce qui t'aide vraiment à redescendre ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 44), ($n$N2-001-C046$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel détail te fait sentir que quelqu'un t'écoute ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 45), ($n$N2-001-C047$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel changement récent te rend fier de toi ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 46), ($n$N2-001-C048$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle expérience simple aimerais-tu partager avec quelqu'un ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 47), ($n$N2-001-C049$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Qu'est-ce qui te met à l'aise pour parler de sexe avec quelqu'un ?"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 48), ($n$N2-001-C050$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel mot pour parler de sexe te fait rire, même quand la conversation est sérieuse ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$humour$n$]::text[], $n$intimite$n$, 49), ($n$N2-001-C051$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Qu'est-ce qui te coupe l'envie, même si l'attirance est là ?"}$n$::jsonb, true, array[$n$desir$n$]::text[], $n$intimite$n$, 50), ($n$N2-001-C052$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Comment préfères-tu faire comprendre que tu as envie d'intimité ?"}$n$::jsonb, true, array[$n$desir$n$]::text[], $n$intimite$n$, 51), ($n$N2-001-C053$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle maladresse dans une conversation sur le sexe pourrait te faire rire plutôt que te gêner ?"}$n$::jsonb, true, array[$n$limites$n$]::text[], $n$intimite$n$, 52), ($n$N2-001-C054$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Qu'est-ce qui t'aide à dire ce que tu aimes pendant un moment intime ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 53), ($n$N2-001-C055$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel cliché des scènes de sexe au cinéma te fait lever les yeux au ciel ?"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 54), ($n$N2-001-C056$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel imprévu pourrait te faire éclater de rire pendant un moment intime ?"}$n$::jsonb, true, array[$n$humour$n$]::text[], $n$intimite$n$, 55), ($n$N2-001-C057$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel détail du quotidien te fait trouver quelqu'un franchement sexy ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 56), ($n$N2-001-C058$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel type de compliment sur ton corps te plaît vraiment ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 57), ($n$N2-001-C059$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Comment préfères-tu aborder la contraception avec un partenaire ?"}$n$::jsonb, true, array[$n$sante_sexuelle$n$]::text[], $n$intimite$n$, 58), ($n$N2-001-C060$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Comment aimerais-tu parler du dépistage avant une relation sexuelle ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$sante_sexuelle$n$]::text[], $n$intimite$n$, 59), ($n$N2-001-C061$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Dans ta vie intime, quel petit détail compte beaucoup plus qu'on ne l'imagine ?"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 60), ($n$N2-001-C062$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Comment fais-tu la différence entre curiosité sexuelle et envie réelle ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$desir$n$]::text[], $n$intimite$n$, 61), ($n$N2-001-C063$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "La masturbation, pour toi : un jardin secret ou un sujet dont tu peux parler simplement ?"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 62), ($n$N2-001-C064$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Comment aimerais-tu discuter des sextoys sans que cela devienne gênant ?"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 63), ($n$N2-001-C065$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Que souhaites-tu garder privé concernant ton passé sexuel ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$passe$n$]::text[], $n$intimite$n$, 64), ($n$N2-001-C066$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle limite aimerais-tu pouvoir exprimer plus facilement ?"}$n$::jsonb, true, array[$n$limites$n$]::text[], $n$intimite$n$, 65), ($n$N2-001-C067$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quand une conversation devient intime, qu'est-ce qui te donne envie de continuer à te confier ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 66), ($n$N2-001-C068$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Qu'est-ce qui te rassure quand ton désir n'est pas le même que celui de l'autre ?"}$n$::jsonb, true, array[$n$desir$n$]::text[], $n$intimite$n$, 67), ($n$N2-001-C069$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel message censé être sexy a déjà perdu tout son effet à cause d'un autocorrecteur ou d'un emoji mal choisi ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$humour$n$]::text[], $n$intimite$n$, 68), ($n$N2-001-C070$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Qu'attends-tu de l'autre après un moment intime ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 69), ($n$N2-001-C071$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle place veux-tu donner aux messages suggestifs dans tes échanges ?"}$n$::jsonb, true, array[$n$numerique$n$]::text[], $n$intimite$n$, 70), ($n$N2-001-C072$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Comment fixerais-tu tes limites concernant les photos intimes ?"}$n$::jsonb, true, array[$n$limites$n$,$n$numerique$n$]::text[], $n$intimite$n$, 71), ($n$N2-001-C073$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Comment réagirais-tu si une proposition sexuelle ne t'intéressait pas ?"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 72), ($n$N2-001-C074$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel conseil sur le sexe entendu partout te paraît complètement à côté de ta vie ?"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 73), ($n$N2-001-C075$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle tenue te donne le sentiment d'être sexy sans devoir jouer un personnage ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 74), ($n$N2-001-C076$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Comment aimerais-tu aborder un fantasme sans promettre de le réaliser ?"}$n$::jsonb, true, array[$n$desir$n$]::text[], $n$intimite$n$, 75), ($n$N2-001-C077$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quelle chanson casserait instantanément l'ambiance d'un moment intime pour toi ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 76), ($n$N2-001-C078$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel sujet intime trouves-tu plus facile à aborder par message qu'en face à face ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 77), ($n$N2-001-C079$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Qu'est-ce qui t'attire sexuellement chez quelqu'un sans apparaître sur une photo ?"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 78), ($n$N2-001-C080$n$, $n$N2-001$n$, $n${"choices": [], "format": "open", "text": "Quel sujet sexuel te rend curieux sans que tu aies forcément envie de l'expérimenter ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$desir$n$]::text[], $n$intimite$n$, 79)) as v(id, game_id, content, adult, tags, theme, sort)
  on conflict (id) do update set content = excluded.content, content_level = excluded.content_level, adult = excluded.adult,
    topic_tags = excluded.topic_tags, theme = excluded.theme, sort = excluded.sort, status = 'published',
    content_version = excluded.content_version
  where (game_cards.content, game_cards.adult, game_cards.topic_tags, game_cards.theme, game_cards.sort, game_cards.status)
    is distinct from (excluded.content, excluded.adult, excluded.topic_tags, excluded.theme, excluded.sort, 'published')
  returning id, (xmax = 0) as inserted
)
insert into import_log select 'card', id, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.game_cards (id, game_id, kind, content, content_level, adult, topic_tags, theme, sort, status, is_demo, content_version)
  select v.id, v.game_id, 'question', v.content, case when v.adult then 'intime' else 'standard' end, v.adult, v.tags, v.theme, v.sort,
    'published', false, $n$2.1.0$n$
  from (values ($n$N2-002-C001$n$, $n$N2-002$n$, $n${"choices": ["Commander quelque chose", "Improviser avec le frigo"], "format": "choice", "text": "Pour un repas raté :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 0), ($n$N2-002-C002$n$, $n$N2-002$n$, $n${"choices": ["Sortir sans programme", "Rester en pyjama"], "format": "choice", "text": "Un dimanche sans obligation :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 1), ($n$N2-002-C003$n$, $n$N2-002$n$, $n${"choices": ["Tout réserver", "Garder une journée au hasard"], "format": "choice", "text": "En voyage :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 2), ($n$N2-002-C004$n$, $n$N2-002$n$, $n${"choices": ["Le finir pour savoir", "Changer sans remords"], "format": "choice", "text": "Un film moyen :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 3), ($n$N2-002-C005$n$, $n$N2-002$n$, $n${"choices": ["Partir discrètement", "Assumer un grand au revoir"], "format": "choice", "text": "Une soirée qui s'éternise :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 4), ($n$N2-002-C006$n$, $n$N2-002$n$, $n${"choices": ["Une surprise", "Une idée que tu as donnée"], "format": "choice", "text": "Un cadeau :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 5), ($n$N2-002-C007$n$, $n$N2-002$n$, $n${"choices": ["Chanter faux", "Discuter de tout"], "format": "choice", "text": "Un trajet à deux :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 6), ($n$N2-002-C008$n$, $n$N2-002$n$, $n${"choices": ["Expliquer la situation", "Assumer et espérer qu'elle fasse rire"], "format": "choice", "text": "Tu envoies une blague au mauvais destinataire :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 7), ($n$N2-002-C009$n$, $n$N2-002$n$, $n${"choices": ["La supprimer", "En faire une blague"], "format": "choice", "text": "Une photo de toi ratée :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 8), ($n$N2-002-C010$n$, $n$N2-002$n$, $n${"choices": ["Tester un peu de tout", "Reprendre ton préféré"], "format": "choice", "text": "Un buffet :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 9), ($n$N2-002-C011$n$, $n$N2-002$n$, $n${"choices": ["Une chanson maîtrisée", "Un tube beaucoup trop ambitieux"], "format": "choice", "text": "Un karaoké :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 10), ($n$N2-002-C012$n$, $n$N2-002$n$, $n${"choices": ["Musique à fond", "Silence absolu"], "format": "choice", "text": "Une maison vide :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 11), ($n$N2-002-C013$n$, $n$N2-002$n$, $n${"choices": ["Tenter le coup risqué", "Assurer quelques points"], "format": "choice", "text": "Un jeu serré :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 12), ($n$N2-002-C014$n$, $n$N2-002$n$, $n${"choices": ["Demander conseil", "Choisir au nom du plat"], "format": "choice", "text": "Un restaurant inconnu :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 13), ($n$N2-002-C015$n$, $n$N2-002$n$, $n${"choices": ["Le porter fièrement", "Le garder pour chez toi"], "format": "choice", "text": "Un vêtement confortable mais laid :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 14), ($n$N2-002-C016$n$, $n$N2-002$n$, $n${"choices": ["Chercher un abri", "Continuer en riant"], "format": "choice", "text": "Un rendez-vous sous la pluie :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 15), ($n$N2-002-C017$n$, $n$N2-002$n$, $n${"choices": ["Avoir un petit indice", "Ne rien savoir"], "format": "choice", "text": "Une surprise organisée pour toi :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 16), ($n$N2-002-C018$n$, $n$N2-002$n$, $n${"choices": ["Essayer de rester sérieux", "Contaminer l'autre"], "format": "choice", "text": "Un fou rire en public :"}$n$::jsonb, false, array[$n$humour$n$]::text[], $n$drole$n$, 17), ($n$N2-002-C019$n$, $n$N2-002$n$, $n${"choices": ["Économie immédiate", "Dernière vidéo quand même"], "format": "choice", "text": "Ton téléphone à 2 % :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 18), ($n$N2-002-C020$n$, $n$N2-002$n$, $n${"choices": ["Observer les gens", "Inventer leur histoire"], "format": "choice", "text": "Une longue file d'attente :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 19), ($n$N2-002-C021$n$, $n$N2-002$n$, $n${"choices": ["La couper en deux", "La garder et offrir le prochain dessert"], "format": "choice", "text": "Il reste une seule part de ton dessert préféré :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 20), ($n$N2-002-C022$n$, $n$N2-002$n$, $n${"choices": ["Tes classiques assumés", "Des découvertes à faire ensemble"], "format": "choice", "text": "Tu dois choisir la musique d'une soirée :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 21), ($n$N2-002-C023$n$, $n$N2-002$n$, $n${"choices": ["Bien cadrée", "Prise sur le vif"], "format": "choice", "text": "Une photo souvenir :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 22), ($n$N2-002-C024$n$, $n$N2-002$n$, $n${"choices": ["Participer", "Commenter comme un journaliste"], "format": "choice", "text": "Un défi ridicule :"}$n$::jsonb, false, array[$n$humour$n$]::text[], $n$drole$n$, 23), ($n$N2-002-C025$n$, $n$N2-002$n$, $n${"choices": ["Une balade", "Un repas tranquille"], "format": "choice", "text": "Pour apprendre à connaître quelqu'un :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 24), ($n$N2-002-C026$n$, $n$N2-002$n$, $n${"choices": ["En parler tout de suite", "Y réfléchir avant"], "format": "choice", "text": "Quand tu doutes :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 25), ($n$N2-002-C027$n$, $n$N2-002$n$, $n${"choices": ["Fait à la main", "Choisi avec précision"], "format": "choice", "text": "Un cadeau qui te touche :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 26), ($n$N2-002-C028$n$, $n$N2-002$n$, $n${"choices": ["Une pause courte", "Une discussion immédiate"], "format": "choice", "text": "Un désaccord :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 27), ($n$N2-002-C029$n$, $n$N2-002$n$, $n${"choices": ["Un appel", "Un message bien écrit"], "format": "choice", "text": "Une nouvelle importante :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 28), ($n$N2-002-C030$n$, $n$N2-002$n$, $n${"choices": ["En privé", "Devant des proches"], "format": "choice", "text": "Un compliment :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 29), ($n$N2-002-C031$n$, $n$N2-002$n$, $n${"choices": ["De la présence", "Un peu d'espace"], "format": "choice", "text": "Une journée difficile :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 30), ($n$N2-002-C032$n$, $n$N2-002$n$, $n${"choices": ["Proposer trois idées", "Choisir ensemble depuis zéro"], "format": "choice", "text": "Une sortie à organiser :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 31), ($n$N2-002-C033$n$, $n$N2-002$n$, $n${"choices": ["Une photo", "Un objet"], "format": "choice", "text": "Un souvenir :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 32), ($n$N2-002-C034$n$, $n$N2-002$n$, $n${"choices": ["En parler tôt", "Attendre qu'il prenne forme"], "format": "choice", "text": "Un projet personnel :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 33), ($n$N2-002-C035$n$, $n$N2-002$n$, $n${"choices": ["La célébrer tout de suite", "Prévoir un moment spécial"], "format": "choice", "text": "Une bonne nouvelle :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 34), ($n$N2-002-C036$n$, $n$N2-002$n$, $n${"choices": ["Qu'on te le demande", "Le remarquer toi-même"], "format": "choice", "text": "Un service à rendre :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 35), ($n$N2-002-C037$n$, $n$N2-002$n$, $n${"choices": ["Reprogrammer immédiatement", "Laisser retomber la frustration"], "format": "choice", "text": "Un rendez-vous manqué :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 36), ($n$N2-002-C038$n$, $n$N2-002$n$, $n${"choices": ["Jouer", "Créer quelque chose"], "format": "choice", "text": "Une soirée à distance :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 37), ($n$N2-002-C039$n$, $n$N2-002$n$, $n${"choices": ["Une recommandation précise", "Une playlist entière"], "format": "choice", "text": "Une découverte musicale :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 38), ($n$N2-002-C040$n$, $n$N2-002$n$, $n${"choices": ["L'écrire", "Le dire de vive voix"], "format": "choice", "text": "Un besoin difficile à dire :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 39), ($n$N2-002-C041$n$, $n$N2-002$n$, $n${"choices": ["Clarifier ce qui s'est passé", "Dire ce que tu as ressenti"], "format": "choice", "text": "Après un malentendu, tu préfères commencer par :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 40), ($n$N2-002-C042$n$, $n$N2-002$n$, $n${"choices": ["Un petit message", "Un temps réservé"], "format": "choice", "text": "Une attention régulière :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 41), ($n$N2-002-C043$n$, $n$N2-002$n$, $n${"choices": ["Faire une liste", "En parler en marchant"], "format": "choice", "text": "Une décision qui compte :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 42), ($n$N2-002-C044$n$, $n$N2-002$n$, $n${"choices": ["Le raconter toi-même", "Attendre qu'on te demande"], "format": "choice", "text": "Un souvenir gênant :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 43), ($n$N2-002-C045$n$, $n$N2-002$n$, $n${"choices": ["Faire simple et juste", "Voir grand"], "format": "choice", "text": "Une surprise à préparer :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 44), ($n$N2-002-C046$n$, $n$N2-002$n$, $n${"choices": ["Le partager en silence", "Le garder pour toi"], "format": "choice", "text": "Un moment de calme :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 45), ($n$N2-002-C047$n$, $n$N2-002$n$, $n${"choices": ["Essayer ensemble", "Tester avant de la proposer"], "format": "choice", "text": "Une nouveauté :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 46), ($n$N2-002-C048$n$, $n$N2-002$n$, $n${"choices": ["Une activité choisie", "Aucun programme"], "format": "choice", "text": "Une journée libre à deux :"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 47), ($n$N2-002-C049$n$, $n$N2-002$n$, $n${"choices": ["Par écrit d'abord", "De vive voix d'abord"], "format": "choice", "text": "Pour parler de sexe :"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 48), ($n$N2-002-C050$n$, $n$N2-002$n$, $n${"choices": ["Des mots directs", "Une approche progressive"], "format": "choice", "text": "Pour exprimer ton désir :"}$n$::jsonb, true, array[$n$desir$n$]::text[], $n$intimite$n$, 49), ($n$N2-002-C051$n$, $n$N2-002$n$, $n${"choices": ["En parler tranquillement avant", "Laisser la conversation venir quand vous vous rapprochez"], "format": "choice", "text": "Avant un premier moment intime avec quelqu'un, tu préfères :"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 50), ($n$N2-002-C052$n$, $n$N2-002$n$, $n${"choices": ["En parler sans projet", "En parler seulement s'il y a une envie réelle"], "format": "choice", "text": "Concernant les fantasmes :"}$n$::jsonb, true, array[$n$desir$n$]::text[], $n$intimite$n$, 51), ($n$N2-002-C053$n$, $n$N2-002$n$, $n${"choices": ["Une phrase courte", "Une explication détaillée"], "format": "choice", "text": "Pour parler d'une limite sexuelle :"}$n$::jsonb, true, array[$n$sexualite$n$,$n$limites$n$]::text[], $n$intimite$n$, 52), ($n$N2-002-C054$n$, $n$N2-002$n$, $n${"choices": ["Chercher un autre moment", "Choisir une autre forme de proximité"], "format": "choice", "text": "Si vos envies diffèrent :"}$n$::jsonb, true, array[$n$desir$n$]::text[], $n$intimite$n$, 53), ($n$N2-002-C055$n$, $n$N2-002$n$, $n${"choices": ["Discuter un peu", "Profiter du calme"], "format": "choice", "text": "Après un moment intime :"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 54), ($n$N2-002-C056$n$, $n$N2-002$n$, $n${"choices": ["Un échange général", "Une question précise"], "format": "choice", "text": "Pour parler de sextoys :"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 55), ($n$N2-002-C057$n$, $n$N2-002$n$, $n${"choices": ["Partager les grandes lignes", "Répondre au cas par cas"], "format": "choice", "text": "Concernant ton passé sexuel :"}$n$::jsonb, true, array[$n$sexualite$n$,$n$passe$n$]::text[], $n$intimite$n$, 56), ($n$N2-002-C058$n$, $n$N2-002$n$, $n${"choices": ["Avant le rendez-vous", "Pendant un moment calme en présence"], "format": "choice", "text": "Pour discuter de contraception :"}$n$::jsonb, true, array[$n$sante_sexuelle$n$]::text[], $n$intimite$n$, 57), ($n$N2-002-C059$n$, $n$N2-002$n$, $n${"choices": ["Une invitation claire", "Une touche d'humour"], "format": "choice", "text": "Un message suggestif :"}$n$::jsonb, true, array[$n$numerique$n$]::text[], $n$intimite$n$, 58), ($n$N2-002-C060$n$, $n$N2-002$n$, $n${"choices": ["Sur ton allure", "Sur la manière dont tu fais sentir l'autre"], "format": "choice", "text": "Un compliment intime :"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 59), ($n$N2-002-C061$n$, $n$N2-002$n$, $n${"choices": ["Un message le lendemain", "Une confidence au calme"], "format": "choice", "text": "Pour évoquer un moment intime qui t'a plu :"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 60), ($n$N2-002-C062$n$, $n$N2-002$n$, $n${"choices": ["Comme d'un sujet ordinaire", "Dans un échange réservé à l'intimité"], "format": "choice", "text": "Pour parler de masturbation :"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 61), ($n$N2-002-C063$n$, $n$N2-002$n$, $n${"choices": ["En parler rapidement", "D'abord identifier ce qui te fatigue"], "format": "choice", "text": "Une baisse de désir :"}$n$::jsonb, true, array[$n$desir$n$]::text[], $n$intimite$n$, 62), ($n$N2-002-C064$n$, $n$N2-002$n$, $n${"choices": ["Dire ce que tu apprécies", "Dire ce qui te convient moins"], "format": "choice", "text": "Pour exprimer une préférence sexuelle :"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 63), ($n$N2-002-C065$n$, $n$N2-002$n$, $n${"choices": ["Proposer de la tendresse sans attente", "Laisser de l'espace"], "format": "choice", "text": "Quand tu reçois un refus :"}$n$::jsonb, true, array[$n$limites$n$]::text[], $n$intimite$n$, 64), ($n$N2-002-C066$n$, $n$N2-002$n$, $n${"choices": ["Une discussion dédiée", "Une conversation plus large sur vos attentes"], "format": "choice", "text": "Pour parler d'exclusivité sexuelle, tu préfères :"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 65), ($n$N2-002-C067$n$, $n$N2-002$n$, $n${"choices": ["Ce n'est pas ton truc", "Tu peux en discuter, sans promettre d'en envoyer"], "format": "choice", "text": "Concernant les photos intimes :"}$n$::jsonb, true, array[$n$numerique$n$]::text[], $n$intimite$n$, 66), ($n$N2-002-C068$n$, $n$N2-002$n$, $n${"choices": ["Une conversation dédiée", "L'intégrer à la discussion sur la protection"], "format": "choice", "text": "Pour aborder le dépistage :"}$n$::jsonb, true, array[$n$sante_sexuelle$n$]::text[], $n$intimite$n$, 67), ($n$N2-002-C069$n$, $n$N2-002$n$, $n${"choices": ["Prendre le temps d'y penser", "Donner ton ressenti immédiat"], "format": "choice", "text": "Une proposition intime inattendue :"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 68), ($n$N2-002-C070$n$, $n$N2-002$n$, $n${"choices": ["Une tenue qui te plaît", "Le regard de quelqu'un qui te désire"], "format": "choice", "text": "Pour te sentir sexy :"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 69), ($n$N2-002-C071$n$, $n$N2-002$n$, $n${"choices": ["En rire ensemble", "Se laisser un instant pour souffler"], "format": "choice", "text": "Un moment intime interrompu :"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 70), ($n$N2-002-C072$n$, $n$N2-002$n$, $n${"choices": ["Tu éclates de rire", "Tu coupes le téléphone pour garder l'ambiance"], "format": "choice", "text": "Ton téléphone lance une notification absurde au milieu d'un échange sexy :"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 71), ($n$N2-002-C073$n$, $n$N2-002$n$, $n${"choices": ["La commenter en riant", "Laisser passer pour garder l'ambiance"], "format": "choice", "text": "Une scène de sexe invraisemblable dans un film :"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 72), ($n$N2-002-C074$n$, $n$N2-002$n$, $n${"choices": ["Écouter sans t'engager", "Dire d'abord tes limites"], "format": "choice", "text": "Un fantasme différent du tien :"}$n$::jsonb, true, array[$n$desir$n$]::text[], $n$intimite$n$, 73), ($n$N2-002-C075$n$, $n$N2-002$n$, $n${"choices": ["Une playlist choisie", "Le calme sans musique"], "format": "choice", "text": "Une ambiance intime :"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 74), ($n$N2-002-C076$n$, $n$N2-002$n$, $n${"choices": ["Un moment prévu, sans être pressés", "Une discussion spontanée quand vous êtes à l'aise"], "format": "choice", "text": "Pour choisir le moment d'une conversation intime :"}$n$::jsonb, true, array[$n$sexualite$n$,$n$desir$n$]::text[], $n$intimite$n$, 75), ($n$N2-002-C077$n$, $n$N2-002$n$, $n${"choices": ["Les éviter", "En discuter avant de les employer"], "format": "choice", "text": "Concernant les mots crus :"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 76), ($n$N2-002-C078$n$, $n$N2-002$n$, $n${"choices": ["Tu racontes une anecdote précise", "Tu partages surtout ce que tu as appris sur toi"], "format": "choice", "text": "Pour parler de ton passé intime :"}$n$::jsonb, true, array[$n$passe$n$]::text[], $n$intimite$n$, 77), ($n$N2-002-C079$n$, $n$N2-002$n$, $n${"choices": ["Une pièce que tu portes déjà avec assurance", "Quelque chose que tu gardes pour les grandes occasions"], "format": "choice", "text": "Une tenue choisie pour te sentir sexy :"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 78), ($n$N2-002-C080$n$, $n$N2-002$n$, $n${"choices": ["Une voix qui te plaît", "Un humour qui tombe juste"], "format": "choice", "text": "Ce qui te paraît le plus sexy :"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 79)) as v(id, game_id, content, adult, tags, theme, sort)
  on conflict (id) do update set content = excluded.content, content_level = excluded.content_level, adult = excluded.adult,
    topic_tags = excluded.topic_tags, theme = excluded.theme, sort = excluded.sort, status = 'published',
    content_version = excluded.content_version
  where (game_cards.content, game_cards.adult, game_cards.topic_tags, game_cards.theme, game_cards.sort, game_cards.status)
    is distinct from (excluded.content, excluded.adult, excluded.topic_tags, excluded.theme, excluded.sort, 'published')
  returning id, (xmax = 0) as inserted
)
insert into import_log select 'card', id, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.game_cards (id, game_id, kind, content, content_level, adult, topic_tags, theme, sort, status, is_demo, content_version)
  select v.id, v.game_id, 'question', v.content, case when v.adult then 'intime' else 'standard' end, v.adult, v.tags, v.theme, v.sort,
    'published', false, $n$2.1.0$n$
  from (values ($n$N2-003-C001$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà passé plus de temps à préparer une réponse drôle qu'à tenir la conversation ?"}$n$::jsonb, false, array[$n$passe$n$,$n$humour$n$]::text[], $n$drole$n$, 0), ($n$N2-003-C002$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà ri à un message en pleine réunion ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 1), ($n$N2-003-C003$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà fait semblant de connaître une chanson ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 2), ($n$N2-003-C004$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà acheté un objet après minuit et regretté le lendemain ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 3), ($n$N2-003-C005$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà cherché ton téléphone pendant que tu l'utilisais ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 4), ($n$N2-003-C006$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà salué quelqu'un qui ne te saluait pas ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 5), ($n$N2-003-C007$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà répété une conversation devant le miroir ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 6), ($n$N2-003-C008$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà raté une recette en voulant l'améliorer ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 7), ($n$N2-003-C009$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà regardé la fin d'un film avant le début ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 8), ($n$N2-003-C010$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà gardé un emballage parce qu'il était trop beau ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 9), ($n$N2-003-C011$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà inventé une excuse pour rentrer dormir ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 10), ($n$N2-003-C012$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà fait un long détour juste pour manger quelque chose ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 11), ($n$N2-003-C013$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà dansé seul en attendant que l'eau chauffe ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 12), ($n$N2-003-C014$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà répondu à voix haute à une vidéo ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 13), ($n$N2-003-C015$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà fait un achat uniquement pour la couleur ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 14), ($n$N2-003-C016$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà fait croire que ton plat trop épicé ne te faisait rien ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 15), ($n$N2-003-C017$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà porté un vêtement à l'envers sans t'en rendre compte ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 16), ($n$N2-003-C018$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà regretté un vocal dès que tu t'es entendu le réécouter ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 17), ($n$N2-003-C019$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà oublié pourquoi tu étais entré dans une pièce ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 18), ($n$N2-003-C020$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà perdu à un jeu que tu venais d'expliquer ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 19), ($n$N2-003-C021$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà confondu deux prénoms pendant une présentation ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 20), ($n$N2-003-C022$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà souri en lisant un vieux message banal ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 21), ($n$N2-003-C023$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà collectionné quelque chose de complètement inutile ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 22), ($n$N2-003-C024$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà fait une surprise qui ne s'est pas passée comme prévu ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$drole$n$, 23), ($n$N2-003-C025$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà changé d'avis sur quelqu'un après une longue conversation ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 24), ($n$N2-003-C026$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà gardé un mot écrit à la main pendant des années ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 25), ($n$N2-003-C027$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà repris contact avec un ami qui te manquait ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 26), ($n$N2-003-C028$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà osé dire que tu avais besoin d'aide ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 27), ($n$N2-003-C029$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà appris une compétence pour faire plaisir à quelqu'un ?"}$n$::jsonb, false, array[$n$sexualite$n$,$n$passe$n$]::text[], $n$personnel$n$, 28), ($n$N2-003-C030$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà quitté une soirée plus heureux que tu ne l'imaginais ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 29), ($n$N2-003-C031$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà pleuré de rire avec une personne que tu connaissais peu ?"}$n$::jsonb, false, array[$n$passe$n$,$n$humour$n$]::text[], $n$personnel$n$, 30), ($n$N2-003-C032$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà traversé la ville pour une rencontre improvisée ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 31), ($n$N2-003-C033$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà offert quelque chose que tu avais fabriqué ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 32), ($n$N2-003-C034$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà pardonné à une personne sans vouloir reprendre contact avec elle ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 33), ($n$N2-003-C035$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà fait une activité seul malgré ton appréhension ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 34), ($n$N2-003-C036$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà écrit une lettre sans l'envoyer ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 35), ($n$N2-003-C037$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà changé une habitude après une remarque bienveillante ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 36), ($n$N2-003-C038$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà compris trop tard qu'une personne te plaisait ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 37), ($n$N2-003-C039$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà apprécié un silence partagé ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 38), ($n$N2-003-C040$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà été touché par une attention minuscule ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 39), ($n$N2-003-C041$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà eu un premier rendez-vous devenu une belle amitié ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 40), ($n$N2-003-C042$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà raconté un rêve à quelqu'un dès le réveil ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 41), ($n$N2-003-C043$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà reçu une excuse qui t'a vraiment apaisé ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 42), ($n$N2-003-C044$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà fait un compliment à un inconnu ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 43), ($n$N2-003-C045$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà pris une décision importante après une simple balade ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 44), ($n$N2-003-C046$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "Dans une ancienne relation amoureuse, as-tu gardé un objet dont tu avais oublié l'histoire ?"}$n$::jsonb, false, array[$n$souvenirs$n$,$n$ancienne_relation$n$]::text[], $n$personnel$n$, 45), ($n$N2-003-C047$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà accepté une invitation qui a changé ton année ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 46), ($n$N2-003-C048$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà dit franchement que quelqu'un te manquait ?"}$n$::jsonb, false, array[$n$passe$n$]::text[], $n$personnel$n$, 47), ($n$N2-003-C049$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà parlé de contraception avant une relation sexuelle ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$sante_sexuelle$n$,$n$passe$n$]::text[], $n$intimite$n$, 48), ($n$N2-003-C050$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà proposé de parler du dépistage avec un partenaire ?"}$n$::jsonb, true, array[$n$sante_sexuelle$n$,$n$passe$n$]::text[], $n$intimite$n$, 49), ($n$N2-003-C051$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà changé d'avis après avoir envisagé un rapport sexuel ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$passe$n$]::text[], $n$intimite$n$, 50), ($n$N2-003-C052$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà dit non à une expérience sexuelle qui ne te tentait pas ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$limites$n$,$n$passe$n$]::text[], $n$intimite$n$, 51), ($n$N2-003-C053$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà demandé une pause pendant un moment intime ?"}$n$::jsonb, true, array[$n$passe$n$]::text[], $n$intimite$n$, 52), ($n$N2-003-C054$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà parlé de masturbation avec un partenaire ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$passe$n$]::text[], $n$intimite$n$, 53), ($n$N2-003-C055$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà discuté de sextoys sans décider d'en utiliser ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$passe$n$]::text[], $n$intimite$n$, 54), ($n$N2-003-C056$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà partagé un fantasme en précisant que tu ne voulais pas le réaliser ?"}$n$::jsonb, true, array[$n$desir$n$,$n$passe$n$]::text[], $n$intimite$n$, 55), ($n$N2-003-C057$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà expliqué une préférence sexuelle avec tes propres mots ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$passe$n$]::text[], $n$intimite$n$, 56), ($n$N2-003-C058$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà posé une limite concernant les photos intimes ?"}$n$::jsonb, true, array[$n$limites$n$,$n$numerique$n$,$n$passe$n$]::text[], $n$intimite$n$, 57), ($n$N2-003-C059$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà choisi de ne pas raconter un détail de ton passé sexuel ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$passe$n$]::text[], $n$intimite$n$, 58), ($n$N2-003-C060$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà vécu une attirance sexuelle sans envie de relation amoureuse ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$desir$n$,$n$passe$n$]::text[], $n$intimite$n$, 59), ($n$N2-003-C061$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà vécu une relation amoureuse avec peu de désir sexuel ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$desir$n$,$n$passe$n$]::text[], $n$intimite$n$, 60), ($n$N2-003-C062$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà discuté d'exclusivité sexuelle avant de faire des suppositions ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$passe$n$]::text[], $n$intimite$n$, 61), ($n$N2-003-C063$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà ri avec un partenaire pendant un moment intime ?"}$n$::jsonb, true, array[$n$passe$n$]::text[], $n$intimite$n$, 62), ($n$N2-003-C064$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà dit que la fatigue prenait le dessus sur ton envie ?"}$n$::jsonb, true, array[$n$desir$n$,$n$passe$n$]::text[], $n$intimite$n$, 63), ($n$N2-003-C065$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà avoué qu'une chanson te mettait dans une ambiance sexy alors que ses paroles étaient tout sauf romantiques ?"}$n$::jsonb, true, array[$n$passe$n$]::text[], $n$intimite$n$, 64), ($n$N2-003-C066$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà réalisé, après coup, qu'une personne essayait de te séduire ?"}$n$::jsonb, true, array[$n$limites$n$,$n$passe$n$]::text[], $n$intimite$n$, 65), ($n$N2-003-C067$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà osé dire qu'une plaisanterie sexuelle te gênait ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$passe$n$]::text[], $n$intimite$n$, 66), ($n$N2-003-C068$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà demandé de ne pas raconter votre intimité à des amis ?"}$n$::jsonb, true, array[$n$passe$n$]::text[], $n$intimite$n$, 67), ($n$N2-003-C069$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà préparé une soirée intime puis préféré discuter pendant des heures ?"}$n$::jsonb, true, array[$n$desir$n$,$n$passe$n$]::text[], $n$intimite$n$, 68), ($n$N2-003-C070$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà choisi une chanson pour une ambiance intime puis regretté le choix des paroles ?"}$n$::jsonb, true, array[$n$passe$n$]::text[], $n$intimite$n$, 69), ($n$N2-003-C071$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà commenté une scène de sexe au cinéma au point de casser complètement son ambiance ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$passe$n$]::text[], $n$intimite$n$, 70), ($n$N2-003-C072$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà été interrompu par une sonnerie au pire moment d'un rendez-vous intime ?"}$n$::jsonb, true, array[$n$passe$n$]::text[], $n$intimite$n$, 71), ($n$N2-003-C073$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà reçu un compliment sexy tellement maladroit qu'il t'a fait rire ?"}$n$::jsonb, true, array[$n$passe$n$,$n$humour$n$]::text[], $n$intimite$n$, 72), ($n$N2-003-C074$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà demandé davantage de tendresse sans rapport sexuel ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$passe$n$]::text[], $n$intimite$n$, 73), ($n$N2-003-C075$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà discuté du rôle de la pornographie dans une relation ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$passe$n$]::text[], $n$intimite$n$, 74), ($n$N2-003-C076$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà choisi de garder un fantasme pour toi ?"}$n$::jsonb, true, array[$n$desir$n$,$n$passe$n$]::text[], $n$intimite$n$, 75), ($n$N2-003-C077$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà changé plusieurs fois un message sexy avant de finir par envoyer un simple « salut » ?"}$n$::jsonb, true, array[$n$passe$n$]::text[], $n$intimite$n$, 76), ($n$N2-003-C078$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà éclaté de rire pendant une conversation que tu essayais de rendre sexy ?"}$n$::jsonb, true, array[$n$passe$n$,$n$humour$n$]::text[], $n$intimite$n$, 77), ($n$N2-003-C079$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà réalisé qu'une tenue confortable te faisait te sentir plus sexy qu'une tenue prévue pour séduire ?"}$n$::jsonb, true, array[$n$passe$n$]::text[], $n$intimite$n$, 78), ($n$N2-003-C080$n$, $n$N2-003$n$, $n${"choices": [], "format": "experience", "text": "As-tu déjà réalisé que tes préférences sexuelles avaient évolué ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$passe$n$]::text[], $n$intimite$n$, 79)) as v(id, game_id, content, adult, tags, theme, sort)
  on conflict (id) do update set content = excluded.content, content_level = excluded.content_level, adult = excluded.adult,
    topic_tags = excluded.topic_tags, theme = excluded.theme, sort = excluded.sort, status = 'published',
    content_version = excluded.content_version
  where (game_cards.content, game_cards.adult, game_cards.topic_tags, game_cards.theme, game_cards.sort, game_cards.status)
    is distinct from (excluded.content, excluded.adult, excluded.topic_tags, excluded.theme, excluded.sort, 'published')
  returning id, (xmax = 0) as inserted
)
insert into import_log select 'card', id, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.game_cards (id, game_id, kind, content, content_level, adult, topic_tags, theme, sort, status, is_demo, content_version)
  select v.id, v.game_id, 'question', v.content, case when v.adult then 'intime' else 'standard' end, v.adult, v.tags, v.theme, v.sort,
    'published', false, $n$2.1.0$n$
  from (values ($n$N2-004-C001$n$, $n$N2-004$n$, $n${"choices": ["Une imitation", "Un lapsus", "Un rire contagieux"], "format": "prediction", "text": "Qu'est-ce qui te ferait le plus rire dans un vocal ?"}$n$::jsonb, false, array[$n$humour$n$]::text[], $n$drole$n$, 0), ($n$N2-004-C002$n$, $n$N2-004$n$, $n${"choices": ["Une idée", "Une conversation", "Une image drôle"], "format": "prediction", "text": "Qu'est-ce qui finit le plus souvent dans tes captures d'écran ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 1), ($n$N2-004-C003$n$, $n$N2-004$n$, $n${"choices": ["Chercher tes clés", "Changer de tenue", "Sous-estimer le trajet"], "format": "prediction", "text": "Quel retard te ressemble le plus ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 2), ($n$N2-004-C004$n$, $n$N2-004$n$, $n${"choices": ["Nourriture", "Livres", "Gadgets"], "format": "prediction", "text": "Quel rayon te fait traîner dans un magasin ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 3), ($n$N2-004-C005$n$, $n$N2-004$n$, $n${"choices": ["Un bon oreiller", "Une grande tasse", "Des chaussons"], "format": "prediction", "text": "Quel petit confort défendrais-tu ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 4), ($n$N2-004-C006$n$, $n$N2-004$n$, $n${"choices": ["Attendre ton tour", "Compter les points", "Garder un secret"], "format": "prediction", "text": "Quelle règle de jeu oublies-tu le plus facilement ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 5), ($n$N2-004-C007$n$, $n$N2-004$n$, $n${"choices": ["Goûter", "Organiser", "Improviser"], "format": "prediction", "text": "Quel rôle prends-tu dans une cuisine à deux ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 6), ($n$N2-004-C008$n$, $n$N2-004$n$, $n${"choices": ["Descendre au mauvais arrêt", "Commander un plat totalement inattendu", "Partir avec la mauvaise valise"], "format": "prediction", "text": "Quel raté de voyage raconterais-tu encore un an plus tard ?"}$n$::jsonb, false, array[$n$humour$n$]::text[], $n$drole$n$, 7), ($n$N2-004-C009$n$, $n$N2-004$n$, $n${"choices": ["Les travaux", "Le karaoké", "Les meubles déplacés"], "format": "prediction", "text": "Quel bruit de voisin te ferait lever les yeux au ciel ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 8), ($n$N2-004-C010$n$, $n$N2-004$n$, $n${"choices": ["Retrouver tes affaires", "Toujours avoir une batterie pleine", "Éplucher sans effort"], "format": "prediction", "text": "Quel superpouvoir minuscule choisirais-tu ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 9), ($n$N2-004-C011$n$, $n$N2-004$n$, $n${"choices": ["Un livre", "Un coussin", "Des écouteurs"], "format": "prediction", "text": "Quel objet emporterais-tu pour un trajet long ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 10), ($n$N2-004-C012$n$, $n$N2-004$n$, $n${"choices": ["Trop commander", "Mal lire le menu", "Acheter des snacks"], "format": "prediction", "text": "Quelle erreur fais-tu quand tu as faim ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 11), ($n$N2-004-C013$n$, $n$N2-004$n$, $n${"choices": ["Un jeu de mots", "Une imitation", "Une observation juste"], "format": "prediction", "text": "Quel genre de blague te fait craquer ?"}$n$::jsonb, false, array[$n$humour$n$]::text[], $n$drole$n$, 12), ($n$N2-004-C014$n$, $n$N2-004$n$, $n${"choices": ["Un quiz", "Un jeu de cartes", "Une course improvisée"], "format": "prediction", "text": "Quelle activité te rend étonnamment compétitif ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 13), ($n$N2-004-C015$n$, $n$N2-004$n$, $n${"choices": ["Un plat réconfortant", "Un vieux film", "Une sieste"], "format": "prediction", "text": "Quel plaisir gardes-tu pour les jours de pluie ?"}$n$::jsonb, false, array[$n$sexualite$n$]::text[], $n$drole$n$, 14), ($n$N2-004-C016$n$, $n$N2-004$n$, $n${"choices": ["Un chat", "Un hibou", "Un ours"], "format": "prediction", "text": "Quel animal représenterait ton réveil ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 15), ($n$N2-004-C017$n$, $n$N2-004$n$, $n${"choices": ["Trois mots", "Un pavé", "Plusieurs vocaux"], "format": "prediction", "text": "Quel message te ressemble le plus ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 16), ($n$N2-004-C018$n$, $n$N2-004$n$, $n${"choices": ["Le chargeur", "Le parfum", "Le livre du trajet"], "format": "prediction", "text": "Quel oubli te ferait revenir chez toi ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 17), ($n$N2-004-C019$n$, $n$N2-004$n$, $n${"choices": ["Un fondant", "Une glace", "Une tarte"], "format": "prediction", "text": "Quel dessert partagerais-tu le moins volontiers ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 18), ($n$N2-004-C020$n$, $n$N2-004$n$, $n${"choices": ["Raconter une histoire", "Danser", "Reconnaître les chansons"], "format": "prediction", "text": "Quel talent de soirée aimerais-tu posséder ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 19), ($n$N2-004-C021$n$, $n$N2-004$n$, $n${"choices": ["Un silence gêné", "Un petit raté", "Une victoire inattendue"], "format": "prediction", "text": "Quelle situation te donne envie de faire une blague ?"}$n$::jsonb, false, array[$n$desir$n$,$n$humour$n$]::text[], $n$drole$n$, 20), ($n$N2-004-C022$n$, $n$N2-004$n$, $n${"choices": ["Une passoire", "Une chaussette", "Un parapluie"], "format": "prediction", "text": "Quel objet choisirais-tu pour une photo absurde ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 21), ($n$N2-004-C023$n$, $n$N2-004$n$, $n${"choices": ["Les dialogues", "Les costumes", "Les incohérences"], "format": "prediction", "text": "Quel défaut de film remarques-tu en premier ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 22), ($n$N2-004-C024$n$, $n$N2-004$n$, $n${"choices": ["Dessiner", "Inventer une chanson", "Jouer un personnage"], "format": "prediction", "text": "Quel défi accepterais-tu le plus vite ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$drole$n$, 23), ($n$N2-004-C025$n$, $n$N2-004$n$, $n${"choices": ["Le calme", "Une balade", "Une conversation légère"], "format": "prediction", "text": "Qu'est-ce qui te repose le plus ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 24), ($n$N2-004-C026$n$, $n$N2-004$n$, $n${"choices": ["Une boisson proposée", "Un sourire", "Une place préparée"], "format": "prediction", "text": "Qu'est-ce qui te fait sentir accueilli ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 25), ($n$N2-004-C027$n$, $n$N2-004$n$, $n${"choices": ["L'humour", "La curiosité", "La délicatesse"], "format": "prediction", "text": "Quelle qualité te donne envie de revoir quelqu'un ?"}$n$::jsonb, false, array[$n$desir$n$]::text[], $n$personnel$n$, 26), ($n$N2-004-C028$n$, $n$N2-004$n$, $n${"choices": ["Se souvenir d'un détail", "Respecter ton temps", "Prendre de tes nouvelles"], "format": "prediction", "text": "Quelle attention remarques-tu d'abord ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 27), ($n$N2-004-C029$n$, $n$N2-004$n$, $n${"choices": ["Apprendre", "Voyager", "Créer"], "format": "prediction", "text": "Quel projet te motive le plus ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 28), ($n$N2-004-C030$n$, $n$N2-004$n$, $n${"choices": ["Un appel", "Une photo", "Un message enthousiaste"], "format": "prediction", "text": "Comment partages-tu une bonne nouvelle ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 29), ($n$N2-004-C031$n$, $n$N2-004$n$, $n${"choices": ["Une phrase", "Une odeur", "Une image"], "format": "prediction", "text": "Quel souvenir gardes-tu le mieux ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 30), ($n$N2-004-C032$n$, $n$N2-004$n$, $n${"choices": ["Un marché", "Un café", "Un parc"], "format": "prediction", "text": "Quel type de sortie te met à l'aise ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 31), ($n$N2-004-C033$n$, $n$N2-004$n$, $n${"choices": ["Une reformulation", "Une question précise", "Un silence attentif"], "format": "prediction", "text": "Quel signe te montre une vraie écoute ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 32), ($n$N2-004-C034$n$, $n$N2-004$n$, $n${"choices": ["Une phrase directe", "Une aide concrète", "Une présence discrète"], "format": "prediction", "text": "Quel encouragement te convient ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 33), ($n$N2-004-C035$n$, $n$N2-004$n$, $n${"choices": ["Ton temps seul", "Tes amitiés", "Tes projets"], "format": "prediction", "text": "Quelle liberté te tient à cœur ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 34), ($n$N2-004-C036$n$, $n$N2-004$n$, $n${"choices": ["Un souvenir retrouvé", "Un objet utile", "Une création personnelle"], "format": "prediction", "text": "Quel cadeau te toucherait ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 35), ($n$N2-004-C037$n$, $n$N2-004$n$, $n${"choices": ["Finir quelque chose", "Voir un proche", "Découvrir un lieu"], "format": "prediction", "text": "Qu'est-ce qui te redonne de l'énergie ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 36), ($n$N2-004-C038$n$, $n$N2-004$n$, $n${"choices": ["Un repas partagé", "Une conversation", "Une réussite"], "format": "prediction", "text": "Quel souvenir aimerais-tu conserver ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 37), ($n$N2-004-C039$n$, $n$N2-004$n$, $n${"choices": ["Avec un complice", "Avec une liste", "À l'intuition"], "format": "prediction", "text": "Comment préfères-tu préparer une surprise ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 38), ($n$N2-004-C040$n$, $n$N2-004$n$, $n${"choices": ["Une explication claire", "Un peu de temps", "Un geste attentionné"], "format": "prediction", "text": "Après un malentendu, qu'est-ce qui t'aide à repartir du bon pied ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 39), ($n$N2-004-C041$n$, $n$N2-004$n$, $n${"choices": ["Être accompagné", "Comprendre les étapes", "Pouvoir essayer sans enjeu"], "format": "prediction", "text": "Qu'est-ce qui t'aide à tenter quelque chose ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 40), ($n$N2-004-C042$n$, $n$N2-004$n$, $n${"choices": ["Lumineux", "Douillet", "Minimaliste"], "format": "prediction", "text": "Quel espace te ressemble ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 41), ($n$N2-004-C043$n$, $n$N2-004$n$, $n${"choices": ["Un jeu", "Un repas en visio", "Une création commune"], "format": "prediction", "text": "Quelle forme de rendez-vous à distance te tente ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 42), ($n$N2-004-C044$n$, $n$N2-004$n$, $n${"choices": ["La musique", "La décoration", "Les odeurs"], "format": "prediction", "text": "Quel détail rends-tu personnel chez toi ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 43), ($n$N2-004-C045$n$, $n$N2-004$n$, $n${"choices": ["Avec des mots", "Avec du temps", "Avec des services"], "format": "prediction", "text": "Comment montres-tu ton attachement ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 44), ($n$N2-004-C046$n$, $n$N2-004$n$, $n${"choices": ["Une longue discussion", "De petits échanges", "Une activité partagée"], "format": "prediction", "text": "Quel rythme de découverte préfères-tu ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 45), ($n$N2-004-C047$n$, $n$N2-004$n$, $n${"choices": ["Une passion", "Ton métier", "Un souvenir"], "format": "prediction", "text": "Quel sujet pourrais-tu expliquer longtemps ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 46), ($n$N2-004-C048$n$, $n$N2-004$n$, $n${"choices": ["Une photo", "Une note", "Un petit objet"], "format": "prediction", "text": "Quelle trace d'une belle journée préfères-tu ?"}$n$::jsonb, false, array[$n$quotidien$n$]::text[], $n$personnel$n$, 47), ($n$N2-004-C049$n$, $n$N2-004$n$, $n${"choices": ["Un message", "Un appel", "Une conversation en présence"], "format": "prediction", "text": "Pour parler de ton désir, quel support te convient ?"}$n$::jsonb, true, array[$n$desir$n$]::text[], $n$intimite$n$, 48), ($n$N2-004-C050$n$, $n$N2-004$n$, $n${"choices": ["Un moment calme", "Une balade privée", "Une soirée dédiée"], "format": "prediction", "text": "Quel contexte facilite une discussion sur le sexe ?"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 49), ($n$N2-004-C051$n$, $n$N2-004$n$, $n${"choices": ["Les limites", "Le désir", "La contraception"], "format": "prediction", "text": "Quel sujet intime te semble le plus facile à aborder ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 50), ($n$N2-004-C052$n$, $n$N2-004$n$, $n${"choices": ["Un compliment sur ton charme", "Sur ta présence", "Sur ta manière d'écouter"], "format": "prediction", "text": "Quel compliment intime te touche ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 51), ($n$N2-004-C053$n$, $n$N2-004$n$, $n${"choices": ["Avoir le temps de parler", "Savoir exprimer tes envies", "Ne pas avoir de programme à suivre"], "format": "prediction", "text": "Avant un premier moment intime, qu'est-ce qui te met le plus à l'aise ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 52), ($n$N2-004-C054$n$, $n$N2-004$n$, $n${"choices": ["La masturbation", "Les sextoys", "Les variations du désir"], "format": "prediction", "text": "Quel sujet aimerais-tu dédramatiser ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 53), ($n$N2-004-C055$n$, $n$N2-004$n$, $n${"choices": ["De la curiosité respectueuse", "De la discrétion", "Un accueil sans commentaire"], "format": "prediction", "text": "Quelle réaction attends-tu à une confidence sexuelle ?"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 54), ($n$N2-004-C056$n$, $n$N2-004$n$, $n${"choices": ["Un texte", "Un vocal, si vous êtes à l'aise", "Une conversation en direct"], "format": "prediction", "text": "Pour un échange intime à distance, quel format choisirais-tu le plus volontiers ?"}$n$::jsonb, true, array[$n$limites$n$,$n$numerique$n$]::text[], $n$intimite$n$, 55), ($n$N2-004-C057$n$, $n$N2-004$n$, $n${"choices": ["« Aucun souci »", "« Tu veux de l'espace ? »", "« On fait autre chose ? »"], "format": "prediction", "text": "Quelle réponse t'aide après un refus intime ?"}$n$::jsonb, true, array[$n$limites$n$]::text[], $n$intimite$n$, 56), ($n$N2-004-C058$n$, $n$N2-004$n$, $n${"choices": ["Confiance", "Liberté", "Tendresse"], "format": "prediction", "text": "Quel mot décrit une intimité qui te convient ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 57), ($n$N2-004-C059$n$, $n$N2-004$n$, $n${"choices": ["Un échange général", "Une confidence personnelle", "Garder cela privé"], "format": "prediction", "text": "Pour parler de fantasmes, tu préfères :"}$n$::jsonb, true, array[$n$desir$n$]::text[], $n$intimite$n$, 58), ($n$N2-004-C060$n$, $n$N2-004$n$, $n${"choices": ["Protection", "Limites", "Attentes relationnelles"], "format": "prediction", "text": "Quel sujet demandes-tu à clarifier avant le sexe ?"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 59), ($n$N2-004-C061$n$, $n$N2-004$n$, $n${"choices": ["Il détend", "Il rapproche", "Il me gêne parfois"], "format": "prediction", "text": "Quel rôle joue l'humour dans l'intimité ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 60), ($n$N2-004-C062$n$, $n$N2-004$n$, $n${"choices": ["Du temps", "Une discussion", "Moins de pression"], "format": "prediction", "text": "Quel soutien t'aide si ton désir baisse ?"}$n$::jsonb, true, array[$n$desir$n$]::text[], $n$intimite$n$, 61), ($n$N2-004-C063$n$, $n$N2-004$n$, $n${"choices": ["Des câlins", "Une discussion", "Une activité calme"], "format": "prediction", "text": "Quelle forme de proximité veux-tu sans sexe ?"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 62), ($n$N2-004-C064$n$, $n$N2-004$n$, $n${"choices": ["Musique douce", "Silence", "Peu importe si tu te sens bien"], "format": "prediction", "text": "Quelle ambiance te plaît pour un moment intime ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 63), ($n$N2-004-C065$n$, $n$N2-004$n$, $n${"choices": ["Une conversation neutre", "Une ressource à lire", "Ne pas aborder ce sujet"], "format": "prediction", "text": "Pour parler d'un sextoy, tu préfères :"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 64), ($n$N2-004-C066$n$, $n$N2-004$n$, $n${"choices": ["Une manière de prononcer ton prénom", "Une façon de retrousser ses manches", "Une concentration très sérieuse"], "format": "prediction", "text": "Quel petit détail peut te sembler sexy sans raison très logique ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 65), ($n$N2-004-C067$n$, $n$N2-004$n$, $n${"choices": ["Le dire immédiatement", "Demander une pause", "Reprendre la discussion plus tard"], "format": "prediction", "text": "Quand une envie change, tu préfères :"}$n$::jsonb, true, array[$n$desir$n$]::text[], $n$intimite$n$, 66), ($n$N2-004-C068$n$, $n$N2-004$n$, $n${"choices": ["Une voix", "Un regard", "Une façon de rire"], "format": "prediction", "text": "Quel détail te paraît le plus sexy au quotidien ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 67), ($n$N2-004-C069$n$, $n$N2-004$n$, $n${"choices": ["Du temps pour réfléchir", "Un accord clair", "Une marque de tendresse"], "format": "prediction", "text": "Que souhaites-tu après une conversation intime importante ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 68), ($n$N2-004-C070$n$, $n$N2-004$n$, $n${"choices": ["Un téléphone qui vibre sans arrêt", "Une plaisanterie au mauvais moment", "Une musique vraiment mal choisie"], "format": "prediction", "text": "Quel petit tue-l'amour peut te sortir d'une ambiance sexy ?"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 69), ($n$N2-004-C071$n$, $n$N2-004$n$, $n${"choices": ["Nommer les limites", "Expliquer tes attentes", "Prendre le temps de réfléchir"], "format": "prediction", "text": "Pour parler d'exclusivité sexuelle, tu préfères :"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 70), ($n$N2-004-C072$n$, $n$N2-004$n$, $n${"choices": ["Une chanson absurdement solennelle", "Une sonnerie ridicule", "Un objet qui tombe avec fracas"], "format": "prediction", "text": "Quel imprévu te ferait rire pendant un moment intime ?"}$n$::jsonb, true, array[$n$humour$n$]::text[], $n$intimite$n$, 71), ($n$N2-004-C073$n$, $n$N2-004$n$, $n${"choices": ["Choisir ce que tu racontes", "Ne pas être comparé", "Ne pas être interrogé sur tout"], "format": "prediction", "text": "Concernant ton passé sexuel, tu veux surtout :"}$n$::jsonb, true, array[$n$sexualite$n$,$n$passe$n$]::text[], $n$intimite$n$, 72), ($n$N2-004-C074$n$, $n$N2-004$n$, $n${"choices": ["Un vocabulaire simple", "Des mots précis", "Trouver tes mots progressivement"], "format": "prediction", "text": "Pour parler de plaisir, tu préfères :"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 73), ($n$N2-004-C075$n$, $n$N2-004$n$, $n${"choices": ["Direct et simple", "Taquin, avec un peu d'humour", "Réservé au début, plus à l'aise ensuite"], "format": "prediction", "text": "Dans une conversation sur le sexe, quel ton te ressemble le plus ?"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 74), ($n$N2-004-C076$n$, $n$N2-004$n$, $n${"choices": ["Tout est parfaitement coordonné", "Personne n'est jamais fatigué", "La chambre est toujours impeccable"], "format": "prediction", "text": "Quel cliché de scène de sexe te fait le plus sourire ?"}$n$::jsonb, true, array[$n$sexualite$n$,$n$humour$n$]::text[], $n$intimite$n$, 75), ($n$N2-004-C077$n$, $n$N2-004$n$, $n${"choices": ["Un repas et une longue discussion", "Un film tout près l'un de l'autre", "Une soirée calme chacun de son côté"], "format": "prediction", "text": "Un moment prévu pour l'intimité tombe à l'eau : tu préférerais improviser quoi ?"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 76), ($n$N2-004-C078$n$, $n$N2-004$n$, $n${"choices": ["Le repos", "La tendresse", "Le temps pour toi"], "format": "prediction", "text": "Quel besoin peut passer avant le sexe ce soir ?"}$n$::jsonb, true, array[$n$sexualite$n$]::text[], $n$intimite$n$, 77), ($n$N2-004-C079$n$, $n$N2-004$n$, $n${"choices": ["Une tenue choisie", "Un compliment juste", "Ton propre état d'esprit"], "format": "prediction", "text": "Qu'est-ce qui te fait te sentir sexy ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 78), ($n$N2-004-C080$n$, $n$N2-004$n$, $n${"choices": ["Un fou rire inattendu", "Un compliment très personnel", "Une complicité tranquille"], "format": "prediction", "text": "Quel souvenir d'un rendez-vous intime te ferait sourire le lendemain ?"}$n$::jsonb, true, array[$n$intimite$n$]::text[], $n$intimite$n$, 79)) as v(id, game_id, content, adult, tags, theme, sort)
  on conflict (id) do update set content = excluded.content, content_level = excluded.content_level, adult = excluded.adult,
    topic_tags = excluded.topic_tags, theme = excluded.theme, sort = excluded.sort, status = 'published',
    content_version = excluded.content_version
  where (game_cards.content, game_cards.adult, game_cards.topic_tags, game_cards.theme, game_cards.sort, game_cards.status)
    is distinct from (excluded.content, excluded.adult, excluded.topic_tags, excluded.theme, excluded.sort, 'published')
  returning id, (xmax = 0) as inserted
)
insert into import_log select 'card', id, case when inserted then 'added' else 'updated' end from up;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$appreciation$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"J’ai remarqué ta manière de…"$n$::jsonb), (1, $n$"J’ai aimé quand tu as…"$n$::jsonb), (2, $n$"Un détail chez toi qui me fait sourire…"$n$::jsonb), (3, $n$"Tu as rendu ce moment plus simple en…"$n$::jsonb), (4, $n$"Ta façon de raconter…"$n$::jsonb), (5, $n$"Je trouve ça courageux de ta part d’avoir…"$n$::jsonb), (6, $n$"Merci d’avoir pris le temps de…"$n$::jsonb), (7, $n$"Tu as été particulièrement attentif quand…"$n$::jsonb), (8, $n$"Ce que tu viens de dire m’a plu parce que…"$n$::jsonb), (9, $n$"J’ai apprécié que tu respectes…"$n$::jsonb), (10, $n$"Ton humour m’a fait du bien quand…"$n$::jsonb), (11, $n$"Tu m’as surpris en…"$n$::jsonb), (12, $n$"Je retiens de notre échange…"$n$::jsonb), (13, $n$"Un effort que j’ai vu…"$n$::jsonb), (14, $n$"Ta patience s’est vue quand…"$n$::jsonb), (15, $n$"Tu as trouvé les mots pour…"$n$::jsonb), (16, $n$"J’aime ton enthousiasme quand tu parles de…"$n$::jsonb), (17, $n$"Tu as fait une place à…"$n$::jsonb), (18, $n$"Une qualité que j’ai observée aujourd’hui…"$n$::jsonb), (19, $n$"Tu as eu une bonne idée en…"$n$::jsonb), (20, $n$"Ta franchise m’a aidé à…"$n$::jsonb), (21, $n$"Je trouve ta curiosité agréable quand…"$n$::jsonb), (22, $n$"Un petit geste que je n’ai pas oublié…"$n$::jsonb), (23, $n$"Tu as bien fait de dire…"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$appreciation$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$appreciation$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$attentions$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"Dessine une médaille pour une petite réussite de l’autre."$n$::jsonb), (1, $n$"Écris une phrase d’encouragement précise."$n$::jsonb), (2, $n$"Crée un mini-badge avec deux symboles."$n$::jsonb), (3, $n$"Partage un souvenir drôle en une phrase."$n$::jsonb), (4, $n$"Dessine un objet qui te fait penser à l’échange."$n$::jsonb), (5, $n$"Écris un compliment sur une action observée."$n$::jsonb), (6, $n$"Compose une carte avec trois couleurs."$n$::jsonb), (7, $n$"Donne un titre de film inventé à votre partie."$n$::jsonb), (8, $n$"Prépare un acrostiche avec un pseudonyme choisi."$n$::jsonb), (9, $n$"Envoie un merci pour un détail concret."$n$::jsonb), (10, $n$"Dessine une tasse et ajoute un petit mot."$n$::jsonb), (11, $n$"Crée un trophée absurde pour la dernière manche."$n$::jsonb), (12, $n$"Raconte une micro-anecdote qui fait sourire."$n$::jsonb), (13, $n$"Écris une invitation à refaire un jeu dans l’app."$n$::jsonb), (14, $n$"Compose une devise de cinq mots."$n$::jsonb), (15, $n$"Fais un portrait en trois adjectifs bienveillants."$n$::jsonb), (16, $n$"Dessine une étoile et nomme une qualité observée."$n$::jsonb), (17, $n$"Écris un mot pour une prochaine journée chargée."$n$::jsonb), (18, $n$"Propose un titre à votre galerie de dessins."$n$::jsonb), (19, $n$"Crée un ticket fictif pour une soirée de jeux."$n$::jsonb), (20, $n$"Fais un dessin en dix traits pour l’autre."$n$::jsonb), (21, $n$"Écris une phrase qui célèbre un effort."$n$::jsonb), (22, $n$"Choisis un symbole pour le moment présent."$n$::jsonb), (23, $n$"Écris une conclusion drôle à votre session."$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$attentions$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$attentions$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$capsule$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"une petite habitude à essayer"$n$::jsonb), (1, $n$"un livre à commencer"$n$::jsonb), (2, $n$"une recette à tester"$n$::jsonb), (3, $n$"une promenade à prévoir"$n$::jsonb), (4, $n$"un tiroir à ranger"$n$::jsonb), (5, $n$"une idée à dessiner"$n$::jsonb), (6, $n$"une photo à retrouver"$n$::jsonb), (7, $n$"un ami à appeler"$n$::jsonb), (8, $n$"une chanson à apprendre"$n$::jsonb), (9, $n$"une compétence à découvrir"$n$::jsonb), (10, $n$"un message à écrire"$n$::jsonb), (11, $n$"un objet à réparer"$n$::jsonb), (12, $n$"un film à voir"$n$::jsonb), (13, $n$"un jeu à essayer"$n$::jsonb), (14, $n$"un moment pour souffler"$n$::jsonb), (15, $n$"un endroit à explorer"$n$::jsonb), (16, $n$"un projet à nommer"$n$::jsonb), (17, $n$"une peur légère à apprivoiser"$n$::jsonb), (18, $n$"une activité à reprendre"$n$::jsonb), (19, $n$"un compliment à donner"$n$::jsonb), (20, $n$"un souvenir à noter"$n$::jsonb), (21, $n$"un petit budget à organiser"$n$::jsonb), (22, $n$"une journée sans programme"$n$::jsonb), (23, $n$"une question personnelle à laisser mûrir"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$capsule$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$capsule$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$categories$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"category": "animal", "examples": {"C": "chat", "P": "poisson", "S": "souris", "T": "tigre"}}$n$::jsonb), (1, $n${"category": "aliment", "examples": {"C": "carotte", "P": "pomme", "S": "salade", "T": "tomate"}}$n$::jsonb), (2, $n${"category": "objet transportable", "examples": {"C": "clé", "P": "parapluie", "S": "sac", "T": "tasse"}}$n$::jsonb), (3, $n${"category": "lieu", "examples": {"C": "cinéma", "P": "parc", "S": "stade", "T": "théâtre"}}$n$::jsonb), (4, $n${"category": "vêtement", "examples": {"C": "chemise", "P": "pantalon", "S": "short", "T": "tunique"}}$n$::jsonb), (5, $n${"category": "métier", "examples": {"C": "cuisinier", "P": "plombier", "S": "serveur", "T": "tailleur"}}$n$::jsonb), (6, $n${"category": "plante", "examples": {"C": "cactus", "P": "palmier", "S": "sapin", "T": "tulipe"}}$n$::jsonb), (7, $n${"category": "dans une maison", "examples": {"C": "canapé", "P": "porte", "S": "serviette", "T": "table"}}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$categories$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$categories$n$ and idx >= 8;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$chain$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"chat"$n$::jsonb), (1, $n$"tasse"$n$::jsonb), (2, $n$"étoile"$n$::jsonb), (3, $n$"escalier"$n$::jsonb), (4, $n$"robe"$n$::jsonb), (5, $n$"enveloppe"$n$::jsonb), (6, $n$"école"$n$::jsonb), (7, $n$"éponge"$n$::jsonb), (8, $n$"été"$n$::jsonb), (9, $n$"éléphant"$n$::jsonb), (10, $n$"train"$n$::jsonb), (11, $n$"nuage"$n$::jsonb), (12, $n$"éclair"$n$::jsonb), (13, $n$"route"$n$::jsonb), (14, $n$"écharpe"$n$::jsonb), (15, $n$"écran"$n$::jsonb), (16, $n$"navire"$n$::jsonb), (17, $n$"équipe"$n$::jsonb), (18, $n$"étagère"$n$::jsonb), (19, $n$"encre"$n$::jsonb), (20, $n$"entrée"$n$::jsonb), (21, $n$"épice"$n$::jsonb), (22, $n$"épi"$n$::jsonb), (23, $n$"image"$n$::jsonb), (24, $n$"église"$n$::jsonb), (25, $n$"escargot"$n$::jsonb), (26, $n$"tapis"$n$::jsonb), (27, $n$"souris"$n$::jsonb), (28, $n$"savon"$n$::jsonb), (29, $n$"neige"$n$::jsonb), (30, $n$"eau"$n$::jsonb), (31, $n$"urne"$n$::jsonb), (32, $n$"univers"$n$::jsonb), (33, $n$"soleil"$n$::jsonb), (34, $n$"lampe"$n$::jsonb), (35, $n$"éventail"$n$::jsonb), (36, $n$"livre"$n$::jsonb), (37, $n$"rose"$n$::jsonb), (38, $n$"espace"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$chain$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$chain$n$ and idx >= 39;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$character_parts$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"tête ronde"$n$::jsonb), (1, $n$"tête carrée"$n$::jsonb), (2, $n$"oreilles longues"$n$::jsonb), (3, $n$"antenne"$n$::jsonb), (4, $n$"moustache"$n$::jsonb), (5, $n$"lunettes"$n$::jsonb), (6, $n$"manteau"$n$::jsonb), (7, $n$"pull rayé"$n$::jsonb), (8, $n$"salopette"$n$::jsonb), (9, $n$"cape"$n$::jsonb), (10, $n$"jupe"$n$::jsonb), (11, $n$"veste"$n$::jsonb), (12, $n$"bottes"$n$::jsonb), (13, $n$"chaussons"$n$::jsonb), (14, $n$"patins"$n$::jsonb), (15, $n$"jambes fines"$n$::jsonb), (16, $n$"pieds larges"$n$::jsonb), (17, $n$"roulettes"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$character_parts$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$character_parts$n$ and idx >= 18;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$character_traits$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"bavard"$n$::jsonb), (1, $n$"distrait"$n$::jsonb), (2, $n$"généreux"$n$::jsonb), (3, $n$"pressé"$n$::jsonb), (4, $n$"méticuleux"$n$::jsonb), (5, $n$"rêveur"$n$::jsonb), (6, $n$"curieux"$n$::jsonb), (7, $n$"prudent"$n$::jsonb), (8, $n$"théâtral"$n$::jsonb), (9, $n$"timide"$n$::jsonb), (10, $n$"enthousiaste"$n$::jsonb), (11, $n$"sérieux"$n$::jsonb), (12, $n$"impatient"$n$::jsonb), (13, $n$"maladroit"$n$::jsonb), (14, $n$"fier"$n$::jsonb), (15, $n$"serviable"$n$::jsonb), (16, $n$"sceptique"$n$::jsonb), (17, $n$"gourmand"$n$::jsonb), (18, $n$"optimiste"$n$::jsonb), (19, $n$"organisé"$n$::jsonb), (20, $n$"nostalgique"$n$::jsonb), (21, $n$"inventif"$n$::jsonb), (22, $n$"solennel"$n$::jsonb), (23, $n$"espiègle"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$character_traits$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$character_traits$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$cipher$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"BONJOUR TOI"$n$::jsonb), (1, $n$"LA CLE EST ICI"$n$::jsonb), (2, $n$"LE CHAT DORT"$n$::jsonb), (3, $n$"RENDEZ VOUS AU CAFE"$n$::jsonb), (4, $n$"REGARDE LA LUNE"$n$::jsonb), (5, $n$"LA TASSE EST VIDE"$n$::jsonb), (6, $n$"LE TRAIN ARRIVE"$n$::jsonb), (7, $n$"PRENDS LE PARAPLUIE"$n$::jsonb), (8, $n$"LE LIVRE EST OUVERT"$n$::jsonb), (9, $n$"UNE SURPRISE ATTEND"$n$::jsonb), (10, $n$"ON JOUE ENCORE"$n$::jsonb), (11, $n$"LE JARDIN EST CALME"$n$::jsonb), (12, $n$"LA PORTE EST BLEUE"$n$::jsonb), (13, $n$"GARDE LE SOURIRE"$n$::jsonb), (14, $n$"LA CARTE EST CACHEE"$n$::jsonb), (15, $n$"LE SOLEIL SE LEVE"$n$::jsonb), (16, $n$"LE MESSAGE EST COURT"$n$::jsonb), (17, $n$"BRAVO POUR CE CODE"$n$::jsonb), (18, $n$"LA VALISE EST PRETE"$n$::jsonb), (19, $n$"LE BATEAU PART"$n$::jsonb), (20, $n$"LA FLEUR EST ROSE"$n$::jsonb), (21, $n$"LE DESSIN EST FINI"$n$::jsonb), (22, $n$"TOURNE LA PAGE"$n$::jsonb), (23, $n$"LE CADEAU EST PETIT"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$cipher$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$cipher$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$date_menu$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"cost": 3, "label": "petit duel"}$n$::jsonb), (1, $n${"cost": 2, "label": "dessin partagé"}$n$::jsonb), (2, $n${"cost": 2, "label": "conversation légère"}$n$::jsonb), (3, $n${"cost": 4, "label": "refrain écrit original"}$n$::jsonb), (4, $n${"cost": 3, "label": "puzzle à deux"}$n$::jsonb), (5, $n${"cost": 2, "label": "carte postale imaginaire"}$n$::jsonb), (6, $n${"cost": 2, "label": "création d’un badge"}$n$::jsonb), (7, $n${"cost": 3, "label": "histoire improvisée"}$n$::jsonb), (8, $n${"cost": 2, "label": "memory"}$n$::jsonb), (9, $n${"cost": 1, "label": "capsule du futur"}$n$::jsonb), (10, $n${"cost": 1, "label": "portrait en objets"}$n$::jsonb), (11, $n${"cost": 3, "label": "défi de mots"}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$date_menu$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$date_menu$n$ and idx >= 12;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$decor$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"lampe"$n$::jsonb), (1, $n$"coussin"$n$::jsonb), (2, $n$"fauteuil"$n$::jsonb), (3, $n$"tapis"$n$::jsonb), (4, $n$"table"$n$::jsonb), (5, $n$"plante"$n$::jsonb), (6, $n$"fenêtre"$n$::jsonb), (7, $n$"rideau"$n$::jsonb), (8, $n$"livre"$n$::jsonb), (9, $n$"tasse"$n$::jsonb), (10, $n$"étagère"$n$::jsonb), (11, $n$"bougie virtuelle"$n$::jsonb), (12, $n$"cadre"$n$::jsonb), (13, $n$"horloge"$n$::jsonb), (14, $n$"vase"$n$::jsonb), (15, $n$"couverture"$n$::jsonb), (16, $n$"enceinte"$n$::jsonb), (17, $n$"plateau"$n$::jsonb), (18, $n$"pouf"$n$::jsonb), (19, $n$"guirlande"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$decor$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$decor$n$ and idx >= 20;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$dialogues$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"tasse et cuillère : le bruit du matin"$n$::jsonb), (1, $n$"chaussette et chaussure : une longue journée"$n$::jsonb), (2, $n$"clé et porte : une arrivée tardive"$n$::jsonb), (3, $n$"lampe et livre : l’heure de dormir"$n$::jsonb), (4, $n$"parapluie et nuage : un rendez-vous manqué"$n$::jsonb), (5, $n$"valise et chapeau : le poids des souvenirs"$n$::jsonb), (6, $n$"montre et réveil : la ponctualité"$n$::jsonb), (7, $n$"coussin et fauteuil : une sieste disputée"$n$::jsonb), (8, $n$"fleur et vase : la décoration"$n$::jsonb), (9, $n$"stylo et carnet : une page blanche"$n$::jsonb), (10, $n$"téléphone et chargeur : une batterie vide"$n$::jsonb), (11, $n$"boussole et carte : une direction discutée"$n$::jsonb), (12, $n$"fourchette et assiette : le dernier morceau"$n$::jsonb), (13, $n$"rideau et fenêtre : la lumière"$n$::jsonb), (14, $n$"ballon et panier : une mauvaise trajectoire"$n$::jsonb), (15, $n$"peigne et miroir : une coiffure"$n$::jsonb), (16, $n$"bougie et allumette : une fête"$n$::jsonb), (17, $n$"chaise et table : une place"$n$::jsonb), (18, $n$"enveloppe et lettre : un secret"$n$::jsonb), (19, $n$"cadre et photo : un souvenir"$n$::jsonb), (20, $n$"dé et plateau : la chance"$n$::jsonb), (21, $n$"guitare et médiator : une répétition"$n$::jsonb), (22, $n$"pinceau et palette : une couleur"$n$::jsonb), (23, $n$"chausson et tapis : une glissade"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$dialogues$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$dialogues$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$doodle_shapes$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"arc ouvert"$n$::jsonb), (1, $n$"spirale"$n$::jsonb), (2, $n$"zigzag"$n$::jsonb), (3, $n$"deux cercles"$n$::jsonb), (4, $n$"boucle"$n$::jsonb), (5, $n$"vague"$n$::jsonb), (6, $n$"triangle ouvert"$n$::jsonb), (7, $n$"ligne brisée"$n$::jsonb), (8, $n$"ovale incliné"$n$::jsonb), (9, $n$"trois points"$n$::jsonb), (10, $n$"crochet"$n$::jsonb), (11, $n$"demi-lune"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$doodle_shapes$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$doodle_shapes$n$ and idx >= 12;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$dubbing$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"beats": ["A apporte un ballon", "le ballon monte", "B arrive avec une échelle"], "scene": "ballon"}$n$::jsonb), (1, $n${"beats": ["A cache une boîte", "B entre trop tôt", "la boîte miaule"], "scene": "cadeau"}$n$::jsonb), (2, $n${"beats": ["A ouvre le parapluie", "B regarde le ciel", "le soleil apparaît"], "scene": "parapluie"}$n$::jsonb), (3, $n${"beats": ["A cherche sa tasse", "B montre une plante", "la tasse sert de pot"], "scene": "tasse"}$n$::jsonb), (4, $n${"beats": ["A ferme la valise", "B montre une chaussette", "un chapeau dépasse"], "scene": "valise"}$n$::jsonb), (5, $n${"beats": ["A éteint la lampe", "B ouvre un livre", "A rallume doucement"], "scene": "lampe"}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$dubbing$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$dubbing$n$ and idx >= 6;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$fantasy_places$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"la ville des ascenseurs-bulles"$n$::jsonb), (1, $n$"le village des parapluies"$n$::jsonb), (2, $n$"la gare des trains immobiles"$n$::jsonb), (3, $n$"la plage des horloges"$n$::jsonb), (4, $n$"le musée des excuses"$n$::jsonb), (5, $n$"la forêt des lampes"$n$::jsonb), (6, $n$"le café des nuages"$n$::jsonb), (7, $n$"l’île des chaussettes"$n$::jsonb), (8, $n$"la montagne des coussins"$n$::jsonb), (9, $n$"le marché des souvenirs"$n$::jsonb), (10, $n$"le port des valises"$n$::jsonb), (11, $n$"la bibliothèque des rêves"$n$::jsonb), (12, $n$"le jardin des lettres"$n$::jsonb), (13, $n$"le cinéma des poissons"$n$::jsonb), (14, $n$"le château des tasses"$n$::jsonb), (15, $n$"la rue des portes minuscules"$n$::jsonb), (16, $n$"le désert des fleurs"$n$::jsonb), (17, $n$"le quartier des chats polis"$n$::jsonb), (18, $n$"la place des réveils silencieux"$n$::jsonb), (19, $n$"le pont des cadeaux"$n$::jsonb), (20, $n$"la maison des saisons"$n$::jsonb), (21, $n$"le lac des étoiles"$n$::jsonb), (22, $n$"l’atelier des boussoles"$n$::jsonb), (23, $n$"la terrasse de la lune"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$fantasy_places$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$fantasy_places$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$flipbook_scenes$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"name": "Le ballon rebondit", "objects": ["ballon", "etoile"]}$n$::jsonb), (1, $n${"name": "La tasse fait sa révérence", "objects": ["tasse", "chapeau"]}$n$::jsonb), (2, $n${"name": "Le nuage éternue", "objects": ["nuage", "fleur"]}$n$::jsonb), (3, $n${"name": "Le cadeau s’ouvre", "objects": ["cadeau", "coeur"]}$n$::jsonb), (4, $n${"name": "La lune joue à cache-cache", "objects": ["lune", "nuage"]}$n$::jsonb), (5, $n${"name": "La valise glisse", "objects": ["valise", "chaussure"]}$n$::jsonb), (6, $n${"name": "La fleur danse", "objects": ["fleur", "soleil"]}$n$::jsonb), (7, $n${"name": "Le parapluie s’envole", "objects": ["parapluie", "nuage"]}$n$::jsonb), (8, $n${"name": "Le poisson fait une bulle", "objects": ["poisson", "rond-a"]}$n$::jsonb), (9, $n${"name": "La lettre arrive", "objects": ["enveloppe", "maison"]}$n$::jsonb), (10, $n${"name": "La lampe salue", "objects": ["lampe", "chapeau"]}$n$::jsonb), (11, $n${"name": "La montre se réveille", "objects": ["montre", "soleil"]}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$flipbook_scenes$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$flipbook_scenes$n$ and idx >= 12;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$geometry$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"rotation": 0, "shape": "circle", "x": 0, "y": 0}$n$::jsonb), (1, $n${"rotation": 90, "shape": "square", "x": 2, "y": 0}$n$::jsonb), (2, $n${"rotation": 180, "shape": "triangle", "x": 4, "y": 1}$n$::jsonb), (3, $n${"rotation": 270, "shape": "circle", "x": 1, "y": 2}$n$::jsonb), (4, $n${"rotation": 0, "shape": "square", "x": 3, "y": 3}$n$::jsonb), (5, $n${"rotation": 90, "shape": "triangle", "x": 5, "y": 3}$n$::jsonb), (6, $n${"rotation": 180, "shape": "circle", "x": 0, "y": 5}$n$::jsonb), (7, $n${"rotation": 270, "shape": "square", "x": 4, "y": 5}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$geometry$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$geometry$n$ and idx >= 8;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$gift_prompts$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"Une pause qui tombe bien"$n$::jsonb), (1, $n$"Un petit encouragement"$n$::jsonb), (2, $n$"De quoi rire après une longue journée"$n$::jsonb), (3, $n$"Un souvenir inventé de votre première aventure"$n$::jsonb), (4, $n$"Un merci pour un détail précis"$n$::jsonb), (5, $n$"Un paquet de bonne humeur"$n$::jsonb), (6, $n$"Un objet porte-bonheur imaginaire"$n$::jsonb), (7, $n$"Un cadeau de bienvenue"$n$::jsonb), (8, $n$"Une invitation sans obligation"$n$::jsonb), (9, $n$"Un clin d’œil à une passion"$n$::jsonb), (10, $n$"Une surprise complètement kitsch"$n$::jsonb), (11, $n$"Une boîte sans occasion particulière"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$gift_prompts$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$gift_prompts$n$ and idx >= 12;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$intruders$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"answer": "valise", "category": "instruments", "items": ["piano", "flûte", "tambour", "valise"], "reason": "La valise transporte des affaires."}$n$::jsonb), (1, $n${"answer": "chaise", "category": "fruits", "items": ["pomme", "banane", "orange", "chaise"], "reason": "La chaise est un meuble."}$n$::jsonb), (2, $n${"answer": "lampe", "category": "vêtements", "items": ["veste", "chemise", "pantalon", "lampe"], "reason": "La lampe éclaire."}$n$::jsonb), (3, $n${"answer": "train", "category": "animaux", "items": ["chat", "chien", "lapin", "train"], "reason": "Le train est un véhicule."}$n$::jsonb), (4, $n${"answer": "porte", "category": "couleurs", "items": ["bleu", "rouge", "vert", "porte"], "reason": "La porte est un objet."}$n$::jsonb), (5, $n${"answer": "fleur", "category": "véhicules", "items": ["train", "avion", "bateau", "fleur"], "reason": "La fleur est une plante."}$n$::jsonb), (6, $n${"answer": "citron", "category": "meubles", "items": ["table", "chaise", "armoire", "citron"], "reason": "Le citron est un fruit."}$n$::jsonb), (7, $n${"answer": "lundi", "category": "formes", "items": ["cercle", "carré", "triangle", "lundi"], "reason": "Lundi est un jour."}$n$::jsonb), (8, $n${"answer": "piano", "category": "jours", "items": ["lundi", "mardi", "jeudi", "piano"], "reason": "Le piano est un instrument."}$n$::jsonb), (9, $n${"answer": "nuage", "category": "parties d’un livre", "items": ["page", "couverture", "chapitre", "nuage"], "reason": "Le nuage est un élément du ciel."}$n$::jsonb), (10, $n${"answer": "ballon", "category": "objets pour écrire", "items": ["stylo", "crayon", "feutre", "ballon"], "reason": "Le ballon ne sert pas à écrire."}$n$::jsonb), (11, $n${"answer": "poisson", "category": "parties d’une maison", "items": ["toit", "porte", "fenêtre", "poisson"], "reason": "Le poisson est un animal."}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$intruders$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$intruders$n$ and idx >= 12;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$inventions$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"un parapluie qui négocie avec les nuages"$n$::jsonb), (1, $n$"une tasse qui choisit le sujet de conversation"$n$::jsonb), (2, $n$"des chaussons qui retrouvent le téléphone"$n$::jsonb), (3, $n$"une valise qui refuse les vêtements tristes"$n$::jsonb), (4, $n$"un réveil qui raconte une excuse"$n$::jsonb), (5, $n$"une lampe qui applaudit les bonnes idées"$n$::jsonb), (6, $n$"un coussin qui change de côté tout seul"$n$::jsonb), (7, $n$"une clé qui donne des conseils de sortie"$n$::jsonb), (8, $n$"un chapeau qui traduit les soupirs"$n$::jsonb), (9, $n$"un carnet qui range les pensées par couleur"$n$::jsonb), (10, $n$"un miroir qui invente des slogans"$n$::jsonb), (11, $n$"une chaise qui demande une pause"$n$::jsonb), (12, $n$"un stylo qui écrit seulement les compliments"$n$::jsonb), (13, $n$"un frigo qui compose des poèmes"$n$::jsonb), (14, $n$"une boussole qui indique les desserts"$n$::jsonb), (15, $n$"une montre qui compte les fous rires"$n$::jsonb), (16, $n$"une étagère qui réclame de nouveaux livres"$n$::jsonb), (17, $n$"une plante qui commente la météo"$n$::jsonb), (18, $n$"un tapis qui choisit la musique"$n$::jsonb), (19, $n$"une enveloppe qui hésite avant de s’ouvrir"$n$::jsonb), (20, $n$"un ballon qui fait des détours"$n$::jsonb), (21, $n$"des lunettes qui sous-titrent les chats"$n$::jsonb), (22, $n$"une cuillère qui refroidit les discussions"$n$::jsonb), (23, $n$"un manteau qui prévoit les retrouvailles"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$inventions$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$inventions$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$jobs$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"réparateur de nuages"$n$::jsonb), (1, $n$"gardien de siestes"$n$::jsonb), (2, $n$"facteur des étoiles"$n$::jsonb), (3, $n$"jardinier de balcons"$n$::jsonb), (4, $n$"inventeur de parapluies"$n$::jsonb), (5, $n$"collectionneur de silences"$n$::jsonb), (6, $n$"cuisinier de fêtes"$n$::jsonb), (7, $n$"guide de petites îles"$n$::jsonb), (8, $n$"bibliothécaire de rêves"$n$::jsonb), (9, $n$"photographe de chats"$n$::jsonb), (10, $n$"accordeur de réveils"$n$::jsonb), (11, $n$"architecte de cabanes"$n$::jsonb), (12, $n$"tailleur de chapeaux"$n$::jsonb), (13, $n$"pilote de montgolfières"$n$::jsonb), (14, $n$"restaurateur de jouets"$n$::jsonb), (15, $n$"dessinateur de cartes"$n$::jsonb), (16, $n$"gardien de phare"$n$::jsonb), (17, $n$"vendeur de souvenirs"$n$::jsonb), (18, $n$"réparateur de bicyclettes"$n$::jsonb), (19, $n$"fabricant de marionnettes"$n$::jsonb), (20, $n$"chef de gare miniature"$n$::jsonb), (21, $n$"organisateur de pique-niques"$n$::jsonb), (22, $n$"détective des objets perdus"$n$::jsonb), (23, $n$"musicien de rue"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$jobs$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$jobs$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$ladders$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"end": "fort", "path": ["pont", "port", "fort"], "start": "pont"}$n$::jsonb), (1, $n${"end": "rose", "path": ["robe", "rose"], "start": "robe"}$n$::jsonb), (2, $n${"end": "lime", "path": ["rame", "rime", "lime"], "start": "rame"}$n$::jsonb), (3, $n${"end": "pont", "path": ["port", "pont"], "start": "port"}$n$::jsonb), (4, $n${"end": "pont", "path": ["fort", "port", "pont"], "start": "fort"}$n$::jsonb), (5, $n${"end": "rame", "path": ["lime", "rime", "rame"], "start": "lime"}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$ladders$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$ladders$n$ and idx >= 6;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$madlibs$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"fields": ["personne", "objet1", "verbe1", "objet2", "phrase", "adjectif", "verbe2", "lieu"], "template": "Ce matin, {personne} a ouvert une boutique de {objet1}. Pour entrer, il fallait {verbe1}. Le premier client portait {objet2} et répétait « {phrase} ». L’ambiance était {adjectif}. À midi, tout le monde a décidé de {verbe2} près de {lieu}."}$n$::jsonb), (1, $n${"fields": ["lieu", "objet1", "personne", "verbe1", "adjectif", "objet2", "phrase", "verbe2"], "template": "Le musée de {lieu} expose {objet1}. Son gardien, {personne}, exige de {verbe1} avant la visite. La salle est {adjectif}. À côté de {objet2}, une pancarte annonce « {phrase} ». Personne n’ose {verbe2}."}$n$::jsonb), (2, $n${"fields": ["lieu", "personne", "objet1", "objet2", "adjectif", "verbe1", "phrase", "verbe2"], "template": "Pour son voyage vers {lieu}, {personne} emporte {objet1} et {objet2}. Le trajet promet d’être {adjectif}. Le conducteur demande de {verbe1}, puis déclare « {phrase} ». À l’arrivée, il reste à {verbe2}."}$n$::jsonb), (3, $n${"fields": ["personne", "objet1", "objet2", "phrase", "adjectif", "verbe1", "verbe2", "lieu"], "template": "Le restaurant de {personne} sert {objet1} en décoration. Sur la table, {objet2} porte la mention « {phrase} ». L’ambiance est {adjectif}. Pour payer, il faut {verbe1}, puis {verbe2} devant {lieu}."}$n$::jsonb), (4, $n${"fields": ["lieu", "verbe1", "personne", "objet1", "objet2", "adjectif", "phrase", "verbe2"], "template": "À {lieu}, le règlement oblige à {verbe1}. {personne} arrive avec {objet1} et {objet2}. Le programme est {adjectif}. Tout commence par « {phrase} » et finit par {verbe2}."}$n$::jsonb), (5, $n${"fields": ["personne", "lieu", "objet1", "objet2", "adjectif", "verbe1", "phrase", "verbe2"], "template": "Le spectacle de {personne} se tient à {lieu}. Sur scène, {objet1} fait face à {objet2}. Le décor est {adjectif}. Le public doit {verbe1} en entendant « {phrase} », puis {verbe2}."}$n$::jsonb), (6, $n${"fields": ["personne", "verbe1", "lieu", "objet1", "objet2", "adjectif", "phrase", "verbe2"], "template": "La mission de {personne} consiste à {verbe1} près de {lieu}. Avec {objet1} et {objet2}, tout semble {adjectif}. Le mot de passe est « {phrase} ». Pour repartir, il faut {verbe2}."}$n$::jsonb), (7, $n${"fields": ["lieu", "personne", "objet1", "objet2", "adjectif", "verbe1", "phrase", "verbe2"], "template": "La fête commence à {lieu}. {personne} apporte {objet1} et {objet2}. Le thème est {adjectif}. Il faut {verbe1} en disant « {phrase} », avant de {verbe2}."}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$madlibs$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$madlibs$n$ and idx >= 8;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$memory_prompts$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"un fou rire"$n$::jsonb), (1, $n$"un repas mémorable"$n$::jsonb), (2, $n$"un trajet inattendu"$n$::jsonb), (3, $n$"une petite victoire"$n$::jsonb), (4, $n$"une surprise reçue"$n$::jsonb), (5, $n$"un objet retrouvé"$n$::jsonb), (6, $n$"un concert"$n$::jsonb), (7, $n$"une rencontre"$n$::jsonb), (8, $n$"un voyage"$n$::jsonb), (9, $n$"un plat raté"$n$::jsonb), (10, $n$"un déménagement"$n$::jsonb), (11, $n$"un moment de courage"$n$::jsonb), (12, $n$"une journée ordinaire heureuse"$n$::jsonb), (13, $n$"une promenade"$n$::jsonb), (14, $n$"une première tentative"$n$::jsonb), (15, $n$"un cadeau fait main"$n$::jsonb), (16, $n$"une conversation importante"$n$::jsonb), (17, $n$"une panne devenue drôle"$n$::jsonb), (18, $n$"une fête improvisée"$n$::jsonb), (19, $n$"une nouvelle apprise"$n$::jsonb), (20, $n$"un endroit découvert"$n$::jsonb), (21, $n$"un rendez-vous manqué"$n$::jsonb), (22, $n$"une soirée tranquille"$n$::jsonb), (23, $n$"un projet terminé"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$memory_prompts$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$memory_prompts$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$menus$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"restaurant sur la lune"$n$::jsonb), (1, $n$"cantine de pirates polis"$n$::jsonb), (2, $n$"café dans un arbre"$n$::jsonb), (3, $n$"buffet dans un train miniature"$n$::jsonb), (4, $n$"terrasse sous un aquarium"$n$::jsonb), (5, $n$"salon de thé pour explorateurs"$n$::jsonb), (6, $n$"pique-nique dans une bibliothèque"$n$::jsonb), (7, $n$"restaurant de nuages"$n$::jsonb), (8, $n$"cantine de musiciens"$n$::jsonb), (9, $n$"café au milieu des fleurs"$n$::jsonb), (10, $n$"table dans un phare"$n$::jsonb), (11, $n$"restaurant de détectives distraits"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$menus$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$menus$n$ and idx >= 12;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$mood$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"soleil"$n$::jsonb), (1, $n$"nuage"$n$::jsonb), (2, $n$"pluie"$n$::jsonb), (3, $n$"éclair"$n$::jsonb), (4, $n$"brume"$n$::jsonb), (5, $n$"arc-en-ciel"$n$::jsonb), (6, $n$"posé"$n$::jsonb), (7, $n$"dispersé"$n$::jsonb), (8, $n$"curieux"$n$::jsonb), (9, $n$"fatigué"$n$::jsonb), (10, $n$"motivé"$n$::jsonb), (11, $n$"tendu"$n$::jsonb), (12, $n$"léger"$n$::jsonb), (13, $n$"saturé"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$mood$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$mood$n$ and idx >= 14;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$objects$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"clé"$n$::jsonb), (1, $n$"tasse"$n$::jsonb), (2, $n$"fleur"$n$::jsonb), (3, $n$"étoile"$n$::jsonb), (4, $n$"livre"$n$::jsonb), (5, $n$"lampe"$n$::jsonb), (6, $n$"ballon"$n$::jsonb), (7, $n$"parapluie"$n$::jsonb), (8, $n$"valise"$n$::jsonb), (9, $n$"chaussure"$n$::jsonb), (10, $n$"lunettes"$n$::jsonb), (11, $n$"chapeau"$n$::jsonb), (12, $n$"montre"$n$::jsonb), (13, $n$"appareil photo"$n$::jsonb), (14, $n$"enveloppe"$n$::jsonb), (15, $n$"cadeau"$n$::jsonb), (16, $n$"boussole"$n$::jsonb), (17, $n$"lune"$n$::jsonb), (18, $n$"soleil"$n$::jsonb), (19, $n$"nuage"$n$::jsonb), (20, $n$"arbre"$n$::jsonb), (21, $n$"maison"$n$::jsonb), (22, $n$"dé"$n$::jsonb), (23, $n$"poisson"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$objects$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$objects$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$pairs$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"left": "pluie", "right": "vacances"}$n$::jsonb), (1, $n${"left": "café", "right": "nuit"}$n$::jsonb), (2, $n${"left": "clé", "right": "voyage"}$n$::jsonb), (3, $n${"left": "livre", "right": "silence"}$n$::jsonb), (4, $n${"left": "soleil", "right": "musique"}$n$::jsonb), (5, $n${"left": "cuisine", "right": "surprise"}$n$::jsonb), (6, $n${"left": "photo", "right": "enfance"}$n$::jsonb), (7, $n${"left": "train", "right": "rencontre"}$n$::jsonb), (8, $n${"left": "fleur", "right": "message"}$n$::jsonb), (9, $n${"left": "mer", "right": "liberté"}$n$::jsonb), (10, $n${"left": "chat", "right": "dimanche"}$n$::jsonb), (11, $n${"left": "danse", "right": "timidité"}$n$::jsonb), (12, $n${"left": "valise", "right": "secret"}$n$::jsonb), (13, $n${"left": "lampe", "right": "lecture"}$n$::jsonb), (14, $n${"left": "chaussure", "right": "aventure"}$n$::jsonb), (15, $n${"left": "montre", "right": "attente"}$n$::jsonb), (16, $n${"left": "parapluie", "right": "partage"}$n$::jsonb), (17, $n${"left": "chapeau", "right": "personnage"}$n$::jsonb), (18, $n${"left": "cadeau", "right": "mémoire"}$n$::jsonb), (19, $n${"left": "fenêtre", "right": "rêve"}$n$::jsonb), (20, $n${"left": "jardin", "right": "repos"}$n$::jsonb), (21, $n${"left": "ballon", "right": "fête"}$n$::jsonb), (22, $n${"left": "boussole", "right": "doute"}$n$::jsonb), (23, $n${"left": "lettre", "right": "courage"}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$pairs$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$pairs$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$palettes$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"hex": "#FFF5E8", "name": "crème"}$n$::jsonb), (1, $n${"hex": "#F17868", "name": "corail"}$n$::jsonb), (2, $n${"hex": "#663C59", "name": "prune"}$n$::jsonb), (3, $n${"hex": "#516B80", "name": "bleu ardoise"}$n$::jsonb), (4, $n${"hex": "#A9D9C2", "name": "menthe"}$n$::jsonb), (5, $n${"hex": "#F4D57A", "name": "jaune doux"}$n$::jsonb), (6, $n${"hex": "#765647", "name": "brun"}$n$::jsonb), (7, $n${"hex": "#BC7758", "name": "cuivre"}$n$::jsonb), (8, $n${"hex": "#E8AEC2", "name": "rose"}$n$::jsonb), (9, $n${"hex": "#C7B5E5", "name": "lilas"}$n$::jsonb), (10, $n${"hex": "#A6B79A", "name": "sauge"}$n$::jsonb), (11, $n${"hex": "#F6C5A6", "name": "pêche"}$n$::jsonb), (12, $n${"hex": "#253C54", "name": "marine"}$n$::jsonb), (13, $n${"hex": "#67B9B1", "name": "turquoise"}$n$::jsonb), (14, $n${"hex": "#ADD8E8", "name": "ciel"}$n$::jsonb), (15, $n${"hex": "#A1A6AA", "name": "gris"}$n$::jsonb), (16, $n${"hex": "#FFFDF7", "name": "ivoire"}$n$::jsonb), (17, $n${"hex": "#30323D", "name": "anthracite"}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$palettes$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$palettes$n$ and idx >= 18;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$pixel_patterns$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"name": "cœur", "rows": ["01010", "11111", "11111", "01110", "00100"]}$n$::jsonb), (1, $n${"name": "maison", "rows": ["00100", "01110", "11111", "10101", "11111"]}$n$::jsonb), (2, $n${"name": "croix", "rows": ["00100", "00100", "11111", "00100", "00100"]}$n$::jsonb), (3, $n${"name": "diamant", "rows": ["00100", "01110", "11011", "01110", "00100"]}$n$::jsonb), (4, $n${"name": "voile", "rows": ["00100", "01100", "11100", "11111", "01110"]}$n$::jsonb), (5, $n${"name": "tasse", "rows": ["00000", "11110", "10011", "10011", "11110"]}$n$::jsonb), (6, $n${"name": "lettre", "rows": ["11111", "11011", "10101", "10001", "11111"]}$n$::jsonb), (7, $n${"name": "sapin", "rows": ["00100", "01110", "00100", "11111", "00100"]}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$pixel_patterns$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$pixel_patterns$n$ and idx >= 8;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$poem_words$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"fenêtre"$n$::jsonb), (1, $n$"café"$n$::jsonb), (2, $n$"dimanche"$n$::jsonb), (3, $n$"pluie"$n$::jsonb), (4, $n$"lumière"$n$::jsonb), (5, $n$"chemin"$n$::jsonb), (6, $n$"tasse"$n$::jsonb), (7, $n$"silence"$n$::jsonb), (8, $n$"jardin"$n$::jsonb), (9, $n$"soleil"$n$::jsonb), (10, $n$"lettre"$n$::jsonb), (11, $n$"voyage"$n$::jsonb), (12, $n$"main"$n$::jsonb), (13, $n$"sourire"$n$::jsonb), (14, $n$"matin"$n$::jsonb), (15, $n$"nuage"$n$::jsonb), (16, $n$"train"$n$::jsonb), (17, $n$"fleur"$n$::jsonb), (18, $n$"porte"$n$::jsonb), (19, $n$"soir"$n$::jsonb), (20, $n$"page"$n$::jsonb), (21, $n$"étoile"$n$::jsonb), (22, $n$"maison"$n$::jsonb), (23, $n$"rire"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$poem_words$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$poem_words$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$portrait$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"f": "curieuse", "m": "curieux"}$n$::jsonb), (1, $n${"f": "réservée", "m": "réservé"}$n$::jsonb), (2, $n${"f": "loyale", "m": "loyal"}$n$::jsonb), (3, $n${"f": "joueuse", "m": "joueur"}$n$::jsonb), (4, $n${"f": "obstinée", "m": "obstiné"}$n$::jsonb), (5, $n${"f": "patiente", "m": "patient"}$n$::jsonb), (6, $n${"f": "spontanée", "m": "spontané"}$n$::jsonb), (7, $n${"f": "prudente", "m": "prudent"}$n$::jsonb), (8, $n${"f": "tendre", "m": "tendre"}$n$::jsonb), (9, $n${"f": "franche", "m": "franc"}$n$::jsonb), (10, $n${"f": "créative", "m": "créatif"}$n$::jsonb), (11, $n${"f": "discrète", "m": "discret"}$n$::jsonb), (12, $n${"f": "sociable", "m": "sociable"}$n$::jsonb), (13, $n${"f": "indépendante", "m": "indépendant"}$n$::jsonb), (14, $n${"f": "généreuse", "m": "généreux"}$n$::jsonb), (15, $n${"f": "observatrice", "m": "observateur"}$n$::jsonb), (16, $n${"f": "rêveuse", "m": "rêveur"}$n$::jsonb), (17, $n${"f": "organisée", "m": "organisé"}$n$::jsonb), (18, $n${"f": "distraite", "m": "distrait"}$n$::jsonb), (19, $n${"f": "audacieuse", "m": "audacieux"}$n$::jsonb), (20, $n${"f": "calme", "m": "calme"}$n$::jsonb), (21, $n${"f": "bavarde", "m": "bavard"}$n$::jsonb), (22, $n${"f": "pudique", "m": "pudique"}$n$::jsonb), (23, $n${"f": "enthousiaste", "m": "enthousiaste"}$n$::jsonb), (24, $n${"f": "sensible", "m": "sensible"}$n$::jsonb), (25, $n${"f": "taquine", "m": "taquin"}$n$::jsonb), (26, $n${"f": "persévérante", "m": "persévérant"}$n$::jsonb), (27, $n${"f": "méthodique", "m": "méthodique"}$n$::jsonb), (28, $n${"f": "intuitive", "m": "intuitif"}$n$::jsonb), (29, $n${"f": "protectrice", "m": "protecteur"}$n$::jsonb), (30, $n${"f": "exigeante", "m": "exigeant"}$n$::jsonb), (31, $n${"f": "souple", "m": "souple"}$n$::jsonb), (32, $n${"f": "optimiste", "m": "optimiste"}$n$::jsonb), (33, $n${"f": "lucide", "m": "lucide"}$n$::jsonb), (34, $n${"f": "aventurière", "m": "aventurier"}$n$::jsonb), (35, $n${"f": "casanière", "m": "casanier"}$n$::jsonb), (36, $n${"f": "matinale", "m": "matinal"}$n$::jsonb), (37, $n${"f": "noctambule", "m": "noctambule"}$n$::jsonb), (38, $n${"f": "gourmande", "m": "gourmand"}$n$::jsonb), (39, $n${"f": "minimaliste", "m": "minimaliste"}$n$::jsonb), (40, $n${"f": "sentimentale", "m": "sentimental"}$n$::jsonb), (41, $n${"f": "pragmatique", "m": "pragmatique"}$n$::jsonb), (42, $n${"f": "romantique", "m": "romantique"}$n$::jsonb), (43, $n${"f": "ironique", "m": "ironique"}$n$::jsonb), (44, $n${"f": "passionnée", "m": "passionné"}$n$::jsonb), (45, $n${"f": "mesurée", "m": "mesuré"}$n$::jsonb), (46, $n${"f": "impatiente", "m": "impatient"}$n$::jsonb), (47, $n${"f": "attentive", "m": "attentif"}$n$::jsonb), (48, $n${"f": "confiante", "m": "confiant"}$n$::jsonb), (49, $n${"f": "timide", "m": "timide"}$n$::jsonb), (50, $n${"f": "énergique", "m": "énergique"}$n$::jsonb), (51, $n${"f": "contemplative", "m": "contemplatif"}$n$::jsonb), (52, $n${"f": "inventive", "m": "inventif"}$n$::jsonb), (53, $n${"f": "fiable", "m": "fiable"}$n$::jsonb), (54, $n${"f": "compétitive", "m": "compétitif"}$n$::jsonb), (55, $n${"f": "conciliante", "m": "conciliant"}$n$::jsonb), (56, $n${"f": "directe", "m": "direct"}$n$::jsonb), (57, $n${"f": "diplomate", "m": "diplomate"}$n$::jsonb), (58, $n${"f": "modeste", "m": "modeste"}$n$::jsonb), (59, $n${"f": "ambitieuse", "m": "ambitieux"}$n$::jsonb), (60, $n${"f": "chaleureuse", "m": "chaleureux"}$n$::jsonb), (61, $n${"f": "distante", "m": "distant"}$n$::jsonb), (62, $n${"f": "expressive", "m": "expressif"}$n$::jsonb), (63, $n${"f": "silencieuse", "m": "silencieux"}$n$::jsonb), (64, $n${"f": "flexible", "m": "flexible"}$n$::jsonb), (65, $n${"f": "tenace", "m": "tenace"}$n$::jsonb), (66, $n${"f": "nostalgique", "m": "nostalgique"}$n$::jsonb), (67, $n${"f": "rebelle", "m": "rebelle"}$n$::jsonb), (68, $n${"f": "méticuleuse", "m": "méticuleux"}$n$::jsonb), (69, $n${"f": "insouciante", "m": "insouciant"}$n$::jsonb), (70, $n${"f": "débrouillarde", "m": "débrouillard"}$n$::jsonb), (71, $n${"f": "ponctuelle", "m": "ponctuel"}$n$::jsonb), (72, $n${"f": "détendue", "m": "détendu"}$n$::jsonb), (73, $n${"f": "vive", "m": "vif"}$n$::jsonb), (74, $n${"f": "tolérante", "m": "tolérant"}$n$::jsonb), (75, $n${"f": "engagée", "m": "engagé"}$n$::jsonb), (76, $n${"f": "espiègle", "m": "espiègle"}$n$::jsonb), (77, $n${"f": "appliquée", "m": "appliqué"}$n$::jsonb), (78, $n${"f": "solidaire", "m": "solidaire"}$n$::jsonb), (79, $n${"f": "déterminée", "m": "déterminé"}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$portrait$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$portrait$n$ and idx >= 80;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$poster$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"Championnat de sieste"$n$::jsonb), (1, $n$"Festival des parapluies"$n$::jsonb), (2, $n$"Bal des chaussettes perdues"$n$::jsonb), (3, $n$"Course de tortues pressées"$n$::jsonb), (4, $n$"Exposition de nuages"$n$::jsonb), (5, $n$"Concours de mauvaises excuses"$n$::jsonb), (6, $n$"Marché des idées oubliées"$n$::jsonb), (7, $n$"Concert des casseroles"$n$::jsonb), (8, $n$"Salon des chats polis"$n$::jsonb), (9, $n$"Défilé des chapeaux géants"$n$::jsonb), (10, $n$"Tournoi des regards sérieux"$n$::jsonb), (11, $n$"Musée des petits ratés"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$poster$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$poster$n$ and idx >= 12;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$radio_briefs$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"Radio Chaussette : grève des réveils"$n$::jsonb), (1, $n$"Radio Tasse : festival de la dernière gorgée"$n$::jsonb), (2, $n$"Radio Nuage : concours de siestes"$n$::jsonb), (3, $n$"Radio Valise : départ d’un train immobile"$n$::jsonb), (4, $n$"Radio Parapluie : météo à l’envers"$n$::jsonb), (5, $n$"Radio Minuit : une lune trop bavarde"$n$::jsonb), (6, $n$"Radio Fourchette : le dessert se rebelle"$n$::jsonb), (7, $n$"Radio Jardin : championnat des escargots"$n$::jsonb), (8, $n$"Radio Palier : réunion des paillassons"$n$::jsonb), (9, $n$"Radio Plume : disparition des points finaux"$n$::jsonb), (10, $n$"Radio Soleil : panne de lunettes noires"$n$::jsonb), (11, $n$"Radio Poche : le trousseau mène l’enquête"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$radio_briefs$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$radio_briefs$n$ and idx >= 12;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$recipes$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"name": "sandwich", "steps": ["choisir le pain", "poser la salade", "ajouter la garniture", "étaler la sauce", "fermer le pain", "présenter"]}$n$::jsonb), (1, $n${"name": "salade de fruits", "steps": ["choisir le bol", "ajouter la pomme", "ajouter la banane", "ajouter l’orange", "mélanger", "présenter"]}$n$::jsonb), (2, $n${"name": "tartine", "steps": ["choisir le pain", "étaler le fromage", "poser la tomate", "ajouter les herbes", "couper en deux", "présenter"]}$n$::jsonb), (3, $n${"name": "bol de céréales", "steps": ["choisir le bol", "verser les céréales", "ajouter le lait", "ajouter la banane", "poser la cuillère", "présenter"]}$n$::jsonb), (4, $n${"name": "assiette composée", "steps": ["choisir l’assiette", "placer le riz", "ajouter les légumes", "ajouter la garniture", "poser les herbes", "présenter"]}$n$::jsonb), (5, $n${"name": "yaourt garni", "steps": ["choisir la coupe", "verser le yaourt", "ajouter les fruits", "ajouter les céréales", "poser la cuillère", "présenter"]}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$recipes$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$recipes$n$ and idx >= 6;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$rhymes$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"sound": "on", "words": ["ballon", "maison", "chanson", "citron", "savon", "bouton", "camion", "mouton"]}$n$::jsonb), (1, $n${"sound": "ette", "words": ["chaussette", "assiette", "serviette", "trompette", "noisette", "bicyclette", "recette", "casquette"]}$n$::jsonb), (2, $n${"sound": "eur", "words": ["fleur", "cœur", "couleur", "bonheur", "douceur", "chaleur", "peur", "danseur"]}$n$::jsonb), (3, $n${"sound": "age", "words": ["plage", "voyage", "nuage", "visage", "fromage", "bagage", "orage", "message"]}$n$::jsonb), (4, $n${"sound": "in", "words": ["matin", "jardin", "lapin", "chemin", "coussin", "voisin", "pain", "train"]}$n$::jsonb), (5, $n${"sound": "eau", "words": ["bateau", "chapeau", "cadeau", "rideau", "gâteau", "manteau", "oiseau", "tableau"]}$n$::jsonb), (6, $n${"sound": "i", "words": ["ami", "lit", "nuit", "bruit", "souris", "petit", "tapis", "gris"]}$n$::jsonb), (7, $n${"sound": "oir", "words": ["soir", "miroir", "tiroir", "espoir", "couloir", "noir", "devoir", "voir"]}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$rhymes$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$rhymes$n$ and idx >= 8;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$scenes$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"rater un train"$n$::jsonb), (1, $n$"chercher ses clés"$n$::jsonb), (2, $n$"renverser un café"$n$::jsonb), (3, $n$"ouvrir un cadeau"$n$::jsonb), (4, $n$"rentrer sous la pluie"$n$::jsonb), (5, $n$"préparer un pique-nique"$n$::jsonb), (6, $n$"réparer une lampe"$n$::jsonb), (7, $n$"perdre un chapeau"$n$::jsonb), (8, $n$"adopter une plante"$n$::jsonb), (9, $n$"faire une valise"$n$::jsonb), (10, $n$"attendre un appel"$n$::jsonb), (11, $n$"trouver une lettre"$n$::jsonb), (12, $n$"organiser une surprise"$n$::jsonb), (13, $n$"s’endormir devant un film"$n$::jsonb), (14, $n$"cuisiner sans recette"$n$::jsonb), (15, $n$"danser dans un salon"$n$::jsonb), (16, $n$"faire une photo de groupe"$n$::jsonb), (17, $n$"installer une tente"$n$::jsonb), (18, $n$"choisir un dessert"$n$::jsonb), (19, $n$"monter un meuble"$n$::jsonb), (20, $n$"retrouver un ami"$n$::jsonb), (21, $n$"suivre un chat"$n$::jsonb), (22, $n$"chercher un trésor"$n$::jsonb), (23, $n$"récupérer un ballon"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$scenes$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$scenes$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$sentences$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$["Le chat", "a choisi", "ma valise", "pour faire", "sa sieste."]$n$::jsonb), (1, $n$["Sous la pluie", "nous avons", "partagé", "un parapluie", "trop petit."]$n$::jsonb), (2, $n$["La tasse", "avait disparu", "derrière", "le plus gros", "livre."]$n$::jsonb), (3, $n$["Ce matin", "mon réveil", "a sonné", "pendant", "un rêve génial."]$n$::jsonb), (4, $n$["Dans le train", "une personne", "a oublié", "un bouquet", "sur le siège."]$n$::jsonb), (5, $n$["Mon voisin", "a adopté", "une plante", "qui dépasse", "déjà sa fenêtre."]$n$::jsonb), (6, $n$["Le dernier", "bout de gâteau", "a provoqué", "une négociation", "très sérieuse."]$n$::jsonb), (7, $n$["Cette photo", "me rappelle", "un dimanche", "où rien", "ne s’est passé comme prévu."]$n$::jsonb), (8, $n$["Le vent", "a emporté", "mon chapeau", "jusqu’à", "la terrasse du café."]$n$::jsonb), (9, $n$["Nous avons", "inventé", "une chanson", "pour retrouver", "les clés."]$n$::jsonb), (10, $n$["La lettre", "était cachée", "dans un livre", "acheté", "la veille."]$n$::jsonb), (11, $n$["Un ballon", "est entré", "par la fenêtre", "au milieu", "du repas."]$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$sentences$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$sentences$n$ and idx >= 12;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$small_topics$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"une petite réussite récente"$n$::jsonb), (1, $n$"un projet qui avance lentement"$n$::jsonb), (2, $n$"un objet que tu veux réparer"$n$::jsonb), (3, $n$"une journée chargée"$n$::jsonb), (4, $n$"un endroit qui te manque"$n$::jsonb), (5, $n$"une activité qui te repose"$n$::jsonb), (6, $n$"une nouveauté que tu essaies"$n$::jsonb), (7, $n$"un repas qui t’a marqué"$n$::jsonb), (8, $n$"une habitude que tu changes"$n$::jsonb), (9, $n$"un livre ou film que tu veux finir"$n$::jsonb), (10, $n$"une sortie que tu prépares"$n$::jsonb), (11, $n$"un problème pratique sans gravité"$n$::jsonb), (12, $n$"une chose apprise récemment"$n$::jsonb), (13, $n$"un petit imprévu"$n$::jsonb), (14, $n$"une bonne surprise"$n$::jsonb), (15, $n$"une envie de voyage"$n$::jsonb), (16, $n$"une tâche que tu repousses"$n$::jsonb), (17, $n$"un souvenir de fête"$n$::jsonb), (18, $n$"une idée créative"$n$::jsonb), (19, $n$"un moment calme"$n$::jsonb), (20, $n$"une amitié précieuse"$n$::jsonb), (21, $n$"un plaisir simple"$n$::jsonb), (22, $n$"un défi personnel léger"$n$::jsonb), (23, $n$"une découverte musicale"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$small_topics$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$small_topics$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$sorts$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"items": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24], "left": "pair", "right": "impair", "rule": "parité"}$n$::jsonb), (1, $n${"items": ["cercle", "carré", "cercle", "carré", "cercle", "carré", "cercle", "carré", "cercle", "carré", "cercle", "carré", "cercle", "carré", "cercle", "carré", "cercle", "carré", "cercle", "carré", "cercle", "carré", "cercle", "carré"], "left": "cercle", "right": "carré", "rule": "forme"}$n$::jsonb), (2, $n${"items": ["bleu", "corail", "bleu", "corail", "bleu", "corail", "bleu", "corail", "bleu", "corail", "bleu", "corail", "bleu", "corail", "bleu", "corail", "bleu", "corail", "bleu", "corail", "bleu", "corail", "bleu", "corail"], "left": "bleu", "right": "corail", "rule": "couleur"}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$sorts$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$sorts$n$ and idx >= 3;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$sounds$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"duration_ms": 100, "frequency": 800, "id": "goutte", "synth": "sine"}$n$::jsonb), (1, $n${"duration_ms": 350, "frequency": 1200, "id": "cloche", "synth": "sine"}$n$::jsonb), (2, $n${"duration_ms": 80, "frequency": 200, "id": "bois", "synth": "triangle"}$n$::jsonb), (3, $n${"duration_ms": 400, "frequency": 600, "id": "souffle", "synth": "noise_lowpass"}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$sounds$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$sounds$n$ and idx >= 4;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$stickers$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"œil rond"$n$::jsonb), (1, $n$"œil fermé"$n$::jsonb), (2, $n$"sourcil"$n$::jsonb), (3, $n$"bouche sourire"$n$::jsonb), (4, $n$"bouche surprise"$n$::jsonb), (5, $n$"moustache"$n$::jsonb), (6, $n$"cheveux bouclés"$n$::jsonb), (7, $n$"mèche"$n$::jsonb), (8, $n$"lunettes rondes"$n$::jsonb), (9, $n$"lunettes carrées"$n$::jsonb), (10, $n$"chapeau haut"$n$::jsonb), (11, $n$"casquette"$n$::jsonb), (12, $n$"nœud"$n$::jsonb), (13, $n$"étoile"$n$::jsonb), (14, $n$"cœur"$n$::jsonb), (15, $n$"tache de rousseur"$n$::jsonb), (16, $n$"oreille"$n$::jsonb), (17, $n$"nez rond"$n$::jsonb), (18, $n$"couronne"$n$::jsonb), (19, $n$"barbe"$n$::jsonb), (20, $n$"joue rose"$n$::jsonb), (21, $n$"boucle d’oreille"$n$::jsonb), (22, $n$"col"$n$::jsonb), (23, $n$"foulard"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$stickers$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$stickers$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$story_starts$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"Dans le train presque vide, une valise commence à vibrer."$n$::jsonb), (1, $n$"Un colis sans nom attend devant la porte."$n$::jsonb), (2, $n$"Le café du quartier affiche « Réservé aux gens qui ont oublié quelque chose »."$n$::jsonb), (3, $n$"Un chat entre avec une petite clé au collier."$n$::jsonb), (4, $n$"Une lettre arrive avec dix ans de retard."$n$::jsonb), (5, $n$"Le parapluie refuse de se fermer après la pluie."$n$::jsonb), (6, $n$"Une photo montre un détail que personne ne se rappelle."$n$::jsonb), (7, $n$"Dans un livre d’occasion, une carte indique votre rue."$n$::jsonb), (8, $n$"Le réveil sonne chaque jour une minute plus tôt."$n$::jsonb), (9, $n$"Une tasse change mystérieusement de place chaque matin."$n$::jsonb), (10, $n$"Le voisin prépare une surprise beaucoup trop bruyante."$n$::jsonb), (11, $n$"Un ballon transporte un message plié."$n$::jsonb), (12, $n$"La boutique vend uniquement des objets perdus."$n$::jsonb), (13, $n$"Une personne attend avec deux bouquets identiques."$n$::jsonb), (14, $n$"Le dernier bus s’arrête devant une maison inconnue."$n$::jsonb), (15, $n$"Un chapeau revient toujours à son propriétaire."$n$::jsonb), (16, $n$"Un jardin pousse au milieu d’un appartement."$n$::jsonb), (17, $n$"Une valise contient seulement des chaussettes gauches."$n$::jsonb), (18, $n$"Le menu du restaurant change quand on le regarde."$n$::jsonb), (19, $n$"Une horloge compte les compliments reçus."$n$::jsonb), (20, $n$"Un ascenseur ouvre sur une plage miniature."$n$::jsonb), (21, $n$"Une maison a une fenêtre de trop."$n$::jsonb), (22, $n$"Le facteur apporte une invitation pour hier."$n$::jsonb), (23, $n$"Une boussole pointe vers les desserts."$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$story_starts$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$story_starts$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$syllables$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"parts": ["pa", "ra", "pluie"], "word": "parapluie"}$n$::jsonb), (1, $n${"parts": ["va", "lise"], "word": "valise"}$n$::jsonb), (2, $n${"parts": ["cho", "co", "lat"], "word": "chocolat"}$n$::jsonb), (3, $n${"parts": ["ca", "rotte"], "word": "carotte"}$n$::jsonb), (4, $n${"parts": ["gi", "rafe"], "word": "girafe"}$n$::jsonb), (5, $n${"parts": ["ba", "teau"], "word": "bateau"}$n$::jsonb), (6, $n${"parts": ["cou", "ssin"], "word": "coussin"}$n$::jsonb), (7, $n${"parts": ["ba", "llon"], "word": "ballon"}$n$::jsonb), (8, $n${"parts": ["gui", "tare"], "word": "guitare"}$n$::jsonb), (9, $n${"parts": ["sa", "lade"], "word": "salade"}$n$::jsonb), (10, $n${"parts": ["to", "mate"], "word": "tomate"}$n$::jsonb), (11, $n${"parts": ["pa", "pi", "llon"], "word": "papillon"}$n$::jsonb), (12, $n${"parts": ["é", "toile"], "word": "étoile"}$n$::jsonb), (13, $n${"parts": ["che", "mise"], "word": "chemise"}$n$::jsonb), (14, $n${"parts": ["ca", "nard"], "word": "canard"}$n$::jsonb), (15, $n${"parts": ["mon", "tagne"], "word": "montagne"}$n$::jsonb), (16, $n${"parts": ["fe", "nêtre"], "word": "fenêtre"}$n$::jsonb), (17, $n${"parts": ["ri", "vière"], "word": "rivière"}$n$::jsonb), (18, $n${"parts": ["a", "mi", "tié"], "word": "amitié"}$n$::jsonb), (19, $n${"parts": ["sou", "ve", "nir"], "word": "souvenir"}$n$::jsonb), (20, $n${"parts": ["a", "ven", "ture"], "word": "aventure"}$n$::jsonb), (21, $n${"parts": ["ci", "tron"], "word": "citron"}$n$::jsonb), (22, $n${"parts": ["ba", "nane"], "word": "banane"}$n$::jsonb), (23, $n${"parts": ["o", "range"], "word": "orange"}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$syllables$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$syllables$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$taboo$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"forbidden": ["voyage", "bagage", "roulettes"], "target": "valise"}$n$::jsonb), (1, $n${"forbidden": ["café", "boire", "anse"], "target": "tasse"}$n$::jsonb), (2, $n${"forbidden": ["pluie", "mouillé", "abri"], "target": "parapluie"}$n$::jsonb), (3, $n${"forbidden": ["porte", "serrure", "ouvrir"], "target": "clé"}$n$::jsonb), (4, $n${"forbidden": ["reflet", "regarder", "glace"], "target": "miroir"}$n$::jsonb), (5, $n${"forbidden": ["lumière", "ampoule", "éclairer"], "target": "lampe"}$n$::jsonb), (6, $n${"forbidden": ["canapé", "doux", "oreiller"], "target": "coussin"}$n$::jsonb), (7, $n${"forbidden": ["heure", "poignet", "temps"], "target": "montre"}$n$::jsonb), (8, $n${"forbidden": ["rond", "gonfler", "football"], "target": "ballon"}$n$::jsonb), (9, $n${"forbidden": ["tête", "porter", "casquette"], "target": "chapeau"}$n$::jsonb), (10, $n${"forbidden": ["lire", "page", "histoire"], "target": "livre"}$n$::jsonb), (11, $n${"forbidden": ["pétale", "bouquet", "parfum"], "target": "fleur"}$n$::jsonb), (12, $n${"forbidden": ["image", "appareil", "souvenir"], "target": "photo"}$n$::jsonb), (13, $n${"forbidden": ["offrir", "surprise", "anniversaire"], "target": "cadeau"}$n$::jsonb), (14, $n${"forbidden": ["nord", "direction", "aiguille"], "target": "boussole"}$n$::jsonb), (15, $n${"forbidden": ["chaud", "jour", "ciel"], "target": "soleil"}$n$::jsonb), (16, $n${"forbidden": ["ciel", "pluie", "blanc"], "target": "nuage"}$n$::jsonb), (17, $n${"forbidden": ["eau", "nager", "nageoire"], "target": "poisson"}$n$::jsonb), (18, $n${"forbidden": ["feuille", "tronc", "branche"], "target": "arbre"}$n$::jsonb), (19, $n${"forbidden": ["habiter", "toit", "pièce"], "target": "maison"}$n$::jsonb), (20, $n${"forbidden": ["rail", "gare", "wagon"], "target": "train"}$n$::jsonb), (21, $n${"forbidden": ["corde", "musique", "instrument"], "target": "guitare"}$n$::jsonb), (22, $n${"forbidden": ["jaune", "acide", "fruit"], "target": "citron"}$n$::jsonb), (23, $n${"forbidden": ["pied", "lacet", "marcher"], "target": "chaussure"}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$taboo$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$taboo$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$taste_labels$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"chanter en cuisinant"$n$::jsonb), (1, $n$"les marchés du matin"$n$::jsonb), (2, $n$"les sorties improvisées"$n$::jsonb), (3, $n$"revoir un film aimé"$n$::jsonb), (4, $n$"les messages vocaux"$n$::jsonb), (5, $n$"les plats très épicés"$n$::jsonb), (6, $n$"les soirées calmes"$n$::jsonb), (7, $n$"danser sans savoir danser"$n$::jsonb), (8, $n$"les jeux de stratégie"$n$::jsonb), (9, $n$"les surprises"$n$::jsonb), (10, $n$"les balades sans but"$n$::jsonb), (11, $n$"les grasses matinées"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$taste_labels$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$taste_labels$n$ and idx >= 12;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$terrain$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"eau"$n$::jsonb), (1, $n$"plage"$n$::jsonb), (2, $n$"forêt"$n$::jsonb), (3, $n$"chemin droit"$n$::jsonb), (4, $n$"chemin courbe"$n$::jsonb), (5, $n$"carrefour"$n$::jsonb), (6, $n$"maison"$n$::jsonb), (7, $n$"prairie"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$terrain$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$terrain$n$ and idx >= 8;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$theatre_briefs$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"Le chat réclame une étoile"$n$::jsonb), (1, $n$"Le lapin a perdu son ombre"$n$::jsonb), (2, $n$"L’arbre veut partir en voyage"$n$::jsonb), (3, $n$"La lune demande un parapluie"$n$::jsonb), (4, $n$"L’oiseau ne veut plus chanter faux"$n$::jsonb), (5, $n$"La maison veut changer de quartier"$n$::jsonb), (6, $n$"Le chat garde une valise mystérieuse"$n$::jsonb), (7, $n$"Le lapin organise un bal sans musique"$n$::jsonb), (8, $n$"L’arbre collectionne les secrets du vent"$n$::jsonb), (9, $n$"La lune refuse de se coucher"$n$::jsonb), (10, $n$"L’oiseau vend un courant d’air"$n$::jsonb), (11, $n$"La maison a le hoquet"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$theatre_briefs$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$theatre_briefs$n$ and idx >= 12;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$trailer_briefs$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n${"genre": "comédie", "objects": ["valise", "montre", "parapluie"], "setting": "gare"}$n$::jsonb), (1, $n${"genre": "aventure", "objects": ["boussole", "enveloppe", "maison"], "setting": "île"}$n$::jsonb), (2, $n${"genre": "mystère", "objects": ["livre", "cle", "lampe"], "setting": "bibliothèque"}$n$::jsonb), (3, $n${"genre": "fantastique", "objects": ["fleur", "lune", "tasse"], "setting": "jardin"}$n$::jsonb), (4, $n${"genre": "comédie", "objects": ["tasse", "chapeau", "poisson"], "setting": "cuisine"}$n$::jsonb), (5, $n${"genre": "aventure", "objects": ["boussole", "soleil", "chaussure"], "setting": "désert"}$n$::jsonb), (6, $n${"genre": "mystère", "objects": ["valise", "cle", "montre"], "setting": "hôtel"}$n$::jsonb), (7, $n${"genre": "fantastique", "objects": ["nuage", "etoile", "parapluie"], "setting": "toit"}$n$::jsonb), (8, $n${"genre": "comédie", "objects": ["cadre", "enveloppe", "lunettes"], "setting": "musée"}$n$::jsonb), (9, $n${"genre": "aventure", "objects": ["poisson", "livre", "boussole"], "setting": "port"}$n$::jsonb), (10, $n${"genre": "mystère", "objects": ["chapeau", "montre", "cadeau"], "setting": "train"}$n$::jsonb), (11, $n${"genre": "fantastique", "objects": ["lampe", "fleur", "lune"], "setting": "atelier"}$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$trailer_briefs$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$trailer_briefs$n$ and idx >= 12;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$values$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"repos"$n$::jsonb), (1, $n$"amitié"$n$::jsonb), (2, $n$"liberté"$n$::jsonb), (3, $n$"créativité"$n$::jsonb), (4, $n$"stabilité"$n$::jsonb), (5, $n$"aventure"$n$::jsonb), (6, $n$"famille"$n$::jsonb), (7, $n$"apprentissage"$n$::jsonb), (8, $n$"santé"$n$::jsonb), (9, $n$"temps seul"$n$::jsonb), (10, $n$"générosité"$n$::jsonb), (11, $n$"travail"$n$::jsonb), (12, $n$"justice"$n$::jsonb), (13, $n$"tendresse"$n$::jsonb), (14, $n$"découverte"$n$::jsonb), (15, $n$"simplicité"$n$::jsonb), (16, $n$"confiance"$n$::jsonb), (17, $n$"humour"$n$::jsonb), (18, $n$"indépendance"$n$::jsonb), (19, $n$"solidarité"$n$::jsonb), (20, $n$"confort"$n$::jsonb), (21, $n$"nature"$n$::jsonb), (22, $n$"spiritualité"$n$::jsonb), (23, $n$"réussite"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$values$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$values$n$ and idx >= 24;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$words$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"plage"$n$::jsonb), (1, $n$"tasse"$n$::jsonb), (2, $n$"lampe"$n$::jsonb), (3, $n$"livre"$n$::jsonb), (4, $n$"arbre"$n$::jsonb), (5, $n$"fleur"$n$::jsonb), (6, $n$"porte"$n$::jsonb), (7, $n$"table"$n$::jsonb), (8, $n$"chaise"$n$::jsonb), (9, $n$"valise"$n$::jsonb), (10, $n$"soleil"$n$::jsonb), (11, $n$"nuage"$n$::jsonb), (12, $n$"étoile"$n$::jsonb), (13, $n$"sable"$n$::jsonb), (14, $n$"vague"$n$::jsonb), (15, $n$"forêt"$n$::jsonb), (16, $n$"route"$n$::jsonb), (17, $n$"train"$n$::jsonb), (18, $n$"avion"$n$::jsonb), (19, $n$"bateau"$n$::jsonb), (20, $n$"jardin"$n$::jsonb), (21, $n$"pierre"$n$::jsonb), (22, $n$"bougie"$n$::jsonb), (23, $n$"miroir"$n$::jsonb), (24, $n$"coussin"$n$::jsonb), (25, $n$"rideau"$n$::jsonb), (26, $n$"fenêtre"$n$::jsonb), (27, $n$"balcon"$n$::jsonb), (28, $n$"citron"$n$::jsonb), (29, $n$"banane"$n$::jsonb), (30, $n$"orange"$n$::jsonb), (31, $n$"tomate"$n$::jsonb), (32, $n$"carotte"$n$::jsonb), (33, $n$"salade"$n$::jsonb), (34, $n$"fromage"$n$::jsonb), (35, $n$"chocolat"$n$::jsonb), (36, $n$"musique"$n$::jsonb), (37, $n$"guitare"$n$::jsonb), (38, $n$"piano"$n$::jsonb), (39, $n$"tambour"$n$::jsonb), (40, $n$"photo"$n$::jsonb), (41, $n$"dessin"$n$::jsonb), (42, $n$"lettre"$n$::jsonb), (43, $n$"message"$n$::jsonb), (44, $n$"cadeau"$n$::jsonb), (45, $n$"ruban"$n$::jsonb), (46, $n$"ballon"$n$::jsonb), (47, $n$"montre"$n$::jsonb), (48, $n$"chapeau"$n$::jsonb), (49, $n$"lunette"$n$::jsonb), (50, $n$"chemise"$n$::jsonb), (51, $n$"veste"$n$::jsonb), (52, $n$"bague"$n$::jsonb), (53, $n$"collier"$n$::jsonb), (54, $n$"sourire"$n$::jsonb), (55, $n$"regard"$n$::jsonb), (56, $n$"silence"$n$::jsonb), (57, $n$"rire"$n$::jsonb), (58, $n$"danse"$n$::jsonb), (59, $n$"voyage"$n$::jsonb), (60, $n$"amitié"$n$::jsonb), (61, $n$"secret"$n$::jsonb), (62, $n$"surprise"$n$::jsonb), (63, $n$"souvenir"$n$::jsonb), (64, $n$"dimanche"$n$::jsonb), (65, $n$"matin"$n$::jsonb), (66, $n$"soirée"$n$::jsonb), (67, $n$"minute"$n$::jsonb), (68, $n$"hiver"$n$::jsonb), (69, $n$"été"$n$::jsonb), (70, $n$"neige"$n$::jsonb), (71, $n$"pluie"$n$::jsonb), (72, $n$"vent"$n$::jsonb), (73, $n$"orage"$n$::jsonb), (74, $n$"rivière"$n$::jsonb), (75, $n$"montagne"$n$::jsonb), (76, $n$"île"$n$::jsonb), (77, $n$"ville"$n$::jsonb), (78, $n$"maison"$n$::jsonb), (79, $n$"café"$n$::jsonb), (80, $n$"chat"$n$::jsonb), (81, $n$"chien"$n$::jsonb), (82, $n$"lapin"$n$::jsonb), (83, $n$"oiseau"$n$::jsonb), (84, $n$"poisson"$n$::jsonb), (85, $n$"renard"$n$::jsonb), (86, $n$"tigre"$n$::jsonb), (87, $n$"cheval"$n$::jsonb), (88, $n$"clé"$n$::jsonb), (89, $n$"dé"$n$::jsonb), (90, $n$"mer"$n$::jsonb), (91, $n$"lune"$n$::jsonb), (92, $n$"pont"$n$::jsonb), (93, $n$"port"$n$::jsonb), (94, $n$"fort"$n$::jsonb), (95, $n$"rose"$n$::jsonb), (96, $n$"robe"$n$::jsonb), (97, $n$"rame"$n$::jsonb), (98, $n$"rime"$n$::jsonb), (99, $n$"lime"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$words$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$words$n$ and idx >= 100;

with up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select $n$zine_themes$n$, v.idx, v.value, $n$2.1.0$n$ from (values (0, $n$"Nos petites victoires"$n$::jsonb), (1, $n$"Le jour où tout a dérapé"$n$::jsonb), (2, $n$"Une soirée parfaite, version simple"$n$::jsonb), (3, $n$"Les objets qui nous suivent"$n$::jsonb), (4, $n$"La vie en pyjama"$n$::jsonb), (5, $n$"Un dimanche sans programme"$n$::jsonb), (6, $n$"Les plats qu’on défend"$n$::jsonb), (7, $n$"Une ville imaginée"$n$::jsonb), (8, $n$"Un voyage minuscule"$n$::jsonb), (9, $n$"Nos talents inutiles"$n$::jsonb), (10, $n$"Le musée des détails"$n$::jsonb), (11, $n$"Demain, en plus drôle"$n$::jsonb)) as v(idx, value)
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value
  returning idx, (xmax = 0) as inserted
)
insert into import_log select 'bank', $n$zine_themes$n$ || ':' || idx, case when inserted then 'added' else 'updated' end from up;
delete from public.content_banks where bank = $n$zine_themes$n$ and idx >= 12;

-- La démo « Portrait en cinq mots » est remplacée par N2-005 (décision 3a) ; ses parties restent dans l'historique.
update public.games set status = 'archived' where id = 'portrait-en-cinq-mots' and status <> 'archived';
update public.game_categories set status = 'archived' where id = 'se-decouvrir' and status <> 'archived';
-- Favoris de l'ancienne démo reportés sur l'activité qui la remplace.
insert into public.game_favorites (user_id, game_id, created_at)
  select user_id, 'N2-005', created_at from public.game_favorites where game_id = 'portrait-en-cinq-mots'
  on conflict do nothing;

insert into public.catalogue_imports (content_version, report)
select $n$2.1.0$n$, jsonb_build_object(
  'jeux_ajoutes', count(*) filter (where kind = 'game' and action = 'added'),
  'jeux_mis_a_jour', count(*) filter (where kind = 'game' and action = 'updated'),
  'cartes_ajoutees', count(*) filter (where kind = 'card' and action = 'added'),
  'cartes_mises_a_jour', count(*) filter (where kind = 'card' and action = 'updated'),
  'banques_ajoutees', count(*) filter (where kind = 'bank' and action = 'added'),
  'banques_mises_a_jour', count(*) filter (where kind = 'bank' and action = 'updated'),
  'rejetes', $n$[]$n$::jsonb, 'jouables', 18)
from import_log;
drop table import_log;
