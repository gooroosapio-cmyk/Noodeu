-- Noodeu · CONTENU DE DÉMONSTRATION (is_demo = true)
-- Le manuel « Famille 01 · Se découvrir » n'a pas encore été fourni. Les règles ci-dessous sont
-- déduites des maquettes 09 à 20 et la liste de mots est provisoire : à remplacer par le contenu validé.

insert into public.game_categories (id, title, promise, sort, status, is_demo) values
  ('se-decouvrir', 'Se découvrir', 'Même après des années, il reste des surprises.', 1, 'published', true);

insert into public.games (id, category_id, mechanic, title, promise, style, duration_min, duration_max, sort, status, is_demo)
values ('portrait-en-cinq-mots', 'se-decouvrir', 'portrait_words', 'Portrait en cinq mots',
        'Se découvrir autrement, en quelques mots.', 'echange', 4, 6, 1, 'draft', true);

insert into public.game_versions (game_id, version, rules, config) values
('portrait-en-cinq-mots', 1,
 $json${
   "objective": "Te décrire en cinq mots, imaginer ceux de ton ou ta partenaire, puis découvrir vos deux portraits.",
   "how_to": [
     "Choisis cinq mots pour te décrire.",
     "Imagine les cinq mots que ton ou ta partenaire a choisis.",
     "Découvrez vos portraits ensemble."
   ],
   "details": [
     "Vous voyez tous les deux la même grille de mots.",
     "Ton choix reste caché jusqu'à ce que vous ayez terminé tous les deux.",
     "Tu peux passer une étape : ce n'est pas grave, la découverte aura simplement moins de mots.",
     "Il n'y a pas de note : les mots retrouvés servent juste à lancer la discussion.",
     "Personne n'est pressé : aucun chrono ne tourne, vous pouvez finir chacun à votre rythme."
   ],
   "privacy": "Vos réponses restent privées avant la révélation.",
   "step_texts": {
     "self":  {"title": "Mon portrait", "prompt": "Quels mots te ressemblent ?", "hint": "Choisis 5 mots pour te décrire.", "confirm": "Confirmer mes mots"},
     "guess": {"title": "Son portrait", "prompt": "Et {partner}, en cinq mots ?", "hint": "Imagine les mots que {partner} a choisis.", "confirm": "Confirmer mon portrait"}
   }
 }$json$::jsonb,
 $json${
   "mechanic": "portrait_words",
   "rounds": 1,
   "pick": 5,
   "steps": [
     {"key": "self",  "kind": "pick_words", "about": "self"},
     {"key": "guess", "kind": "pick_words", "about": "partner"}
   ],
   "reveal": "all_players_all_steps",
   "skip": "allowed_without_penalty",
   "score": "none",
   "settings": {"deck_size": {"label": "Mots proposés", "options": [12, 16], "default": 12}}
 }$json$::jsonb);

update public.game_versions set published_at = now() where game_id = 'portrait-en-cinq-mots' and version = 1;
update public.games set current_version = 1, status = 'published' where id = 'portrait-en-cinq-mots';

insert into public.game_cards (id, game_id, kind, content, sort, status, is_demo, source_note)
select 'portrait.' || w.id, 'portrait-en-cinq-mots', 'word', jsonb_build_object('f', w.f, 'm', w.m),
       w.n, 'published', true, 'Démo — liste provisoire à valider'
from (values
  ('curieux', 'Curieuse', 'Curieux', 1), ('calme', 'Calme', 'Calme', 2), ('fiable', 'Fiable', 'Fiable', 3),
  ('gourmand', 'Gourmande', 'Gourmand', 4), ('spontane', 'Spontanée', 'Spontané', 5),
  ('reveur', 'Rêveuse', 'Rêveur', 6), ('creatif', 'Créative', 'Créatif', 7), ('patient', 'Patiente', 'Patient', 8),
  ('sportif', 'Sportive', 'Sportif', 9), ('sociable', 'Sociable', 'Sociable', 10), ('drole', 'Drôle', 'Drôle', 11),
  ('reserve', 'Réservée', 'Réservé', 12), ('sensible', 'Sensible', 'Sensible', 13), ('fidele', 'Fidèle', 'Fidèle', 14),
  ('attentionne', 'Attentionnée', 'Attentionné', 15), ('organise', 'Organisée', 'Organisé', 16),
  ('aventureux', 'Aventureuse', 'Aventureux', 17), ('genereux', 'Généreuse', 'Généreux', 18),
  ('tetu', 'Têtue', 'Têtu', 19), ('optimiste', 'Optimiste', 'Optimiste', 20), ('pudique', 'Pudique', 'Pudique', 21),
  ('bavard', 'Bavarde', 'Bavard', 22), ('protecteur', 'Protectrice', 'Protecteur', 23),
  ('independant', 'Indépendante', 'Indépendant', 24), ('taquin', 'Taquine', 'Taquin', 25),
  ('casanier', 'Casanière', 'Casanier', 26), ('perfectionniste', 'Perfectionniste', 'Perfectionniste', 27),
  ('tendre', 'Tendre', 'Tendre', 28), ('energique', 'Énergique', 'Énergique', 29), ('ponctuel', 'Ponctuelle', 'Ponctuel', 30)
) as w(id, f, m, n);
