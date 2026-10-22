-- Tests de la famille 1 (édition 2.1.0) : moteur de manches, confidentialité, +18 à double accord,
-- thèmes à éviter, rôles, ordre des étapes, idempotence, capsule, effacement différé.
-- Transaction annulée à la fin : aucune donnée ne reste.
begin;

create schema t;
grant usage on schema t to authenticated;

create function t.login(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;
create function t.logout() returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
end $$;
create function t.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if;
end $$;
create function t.err(res jsonb, expected text, msg text) returns void language plpgsql as $$
begin
  if res ->> 'error' is distinct from expected then
    raise exception 'ÉCHEC : % (attendu %, obtenu %)', msg, expected, res;
  end if;
end $$;
create function t.okr(res jsonb, msg text) returns void language plpgsql as $$
begin
  if coalesce((res ->> 'ok')::boolean, false) is not true then raise exception 'ÉCHEC : % (%)', msg, res; end if;
end $$;
-- Lectures techniques hors droits joueurs.
create function t.n_answers(p uuid) returns int language sql security definer as $$
  select count(*)::int from public.session_answers where session_id = p $$;
create function t.round_card(p uuid, n int) returns jsonb language sql security definer as $$
  select card from public.session_rounds where session_id = p and round_no = n $$;
create function t.state(p uuid) returns jsonb language sql as $$ select public.get_session_state(p) $$;
-- Réponse visible de l'autre pour l'étape donnée (null si cachée).
create function t.other_payload(p uuid, n int, step text) returns jsonb language sql as $$
  select nullif(a -> 'payload', 'null'::jsonb) from jsonb_array_elements(public.get_session_state(p) -> 'rounds') r,
         jsonb_array_elements(r -> 'answers') a
  where (r ->> 'round_no')::int = n and a ->> 'step' = step
    and (a ->> 'seat')::int <> (public.get_session_state(p) ->> 'my_seat')::int $$;
grant execute on all functions in schema t to authenticated;
create table t.ids (k text primary key, v text);
grant all on t.ids to authenticated;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-00000000000a', 'test-a@noodeu.invalid', '{"display_name":"Test A"}'),
  ('00000000-0000-4000-a000-00000000000b', 'test-b@noodeu.invalid', '{"display_name":"Test B"}'),
  ('00000000-0000-4000-a000-00000000000c', 'test-c@noodeu.invalid', '{"display_name":"Test C"}');

-- Duo A–B.
do $$
declare r jsonb; code text;
begin
  perform t.login('00000000-0000-4000-a000-00000000000a');
  r := public.create_invitation(); code := r ->> 'code';
  insert into t.ids values ('inv', r ->> 'id');
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform t.okr(public.claim_invitation(code), 'B rejoint');
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform t.okr(public.respond_to_claim((select v::uuid from t.ids where k = 'inv'), true), 'A accepte');
  perform t.logout();
end $$;

-- ===== 1. Catalogue ============================================================
do $$
begin
  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform t.ok((select count(*) from public.games where status = 'published' and id like 'N2-%') = 144, '144 activités publiées');
  perform t.ok((select count(*) from public.games g join public.game_categories gc on gc.id = g.category_id where g.implementation = 'playable' and gc.family_no = 1) = 18, '18 activités jouables (famille 1)');
  perform t.ok((select count(distinct category_id) from public.games where id like 'N2-%') = 8, '8 familles');
  perform t.ok(not exists (select 1 from public.games where id = 'portrait-en-cinq-mots'), 'ancienne démo retirée du catalogue public');
  perform t.err(public.create_session('N2-061'), 'game_unavailable', 'une activité « Bientôt » ne se lance pas');
  perform t.ok((select count(*) from public.game_cards) = 0, 'cartes illisibles en direct');
  perform t.ok((select count(*) from public.content_banks) = 0, 'banques illisibles en direct');
  perform t.logout();
end $$;

-- ===== 2. N2-001 : préférences privées, tirage filtré, réponses cachées ===========
do $$
declare s uuid; r jsonb; st jsonb; card jsonb;
begin
  perform t.login('00000000-0000-4000-a000-00000000000a');
  r := public.create_session('N2-001'); s := (r ->> 'session_id')::uuid;
  insert into t.ids values ('s1', s::text);
  perform t.err(public.set_session_prefs(s, true, '{}'), 'content_not_enabled', '+18 refusé sans l''accord des Réglages');
  perform t.okr(public.update_session_settings(s, '{"cartes": 4}'), '4 cartes');
  perform t.okr(public.set_session_prefs(s, false, array['desir', 'inconnu']), 'A évite le thème désir');
  st := t.state(s);
  perform t.ok(st -> 'my_prefs' -> 'excluded_topics' = '["desir"]', 'thème inconnu ignoré, préférence enregistrée');
  perform t.okr(public.set_ready(s, true), 'A prêt');
  perform t.logout();

  perform t.login('00000000-0000-4000-a000-00000000000b');
  st := t.state(s);
  perform t.ok(st -> 'my_prefs' -> 'excluded_topics' = '[]', 'B ne voit que ses propres préférences');
  perform t.ok((select count(*) from public.session_prefs) = 1, 'B ne lit pas les préférences de A');
  perform t.ok((public.set_ready(s, true) ->> 'status') = 'playing', 'la partie démarre');
  perform t.ok((t.state(s) -> 'session' ->> 'total_rounds')::int = 4, '4 manches');
  card := t.round_card(s, 1);
  perform t.ok(not (card ->> 'adult')::boolean, 'pas de carte +18 sans double accord');
  perform t.okr(public.submit_answer(s, 1, 'answer', '{"text": "  Ma réponse secrète  "}'), 'B répond');
  perform t.okr(public.submit_answer(s, 1, 'answer', '{"text": "Ma réponse secrète"}'), 'même réponse renvoyée : sans effet');
  perform t.err(public.submit_answer(s, 1, 'answer', '{"text": "autre"}'), 'already_submitted', 'réponse modifiée refusée');
  perform t.err(public.submit_answer(s, 1, 'answer', jsonb_build_object('text', repeat('x', 601))), 'invalid_answer', 'texte trop long');
  perform t.err(public.submit_answer(s, 1, 'reaction', '{"text": "tôt"}'), 'not_revealed', 'pas de réaction avant la révélation');
  perform t.logout();

  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform t.ok(t.other_payload(s, 1, 'answer') is null, 'A ne voit pas la réponse de B avant de répondre');
  perform t.ok(t.state(s)::text not like '%secrète%', 'aucune trace de la réponse de B dans l''état de A');
  perform t.okr(public.submit_answer(s, 1, 'answer', null, true), 'A passe');
  perform t.ok(t.other_payload(s, 1, 'answer') ->> 'text' = 'Ma réponse secrète', 'révélation : A voit la réponse nettoyée');
  perform t.okr(public.submit_answer(s, 1, 'reaction', '{"text": "Merci !"}'), 'réaction après révélation');
  perform t.okr(public.next_round(s, 1), 'carte suivante');
  perform t.okr(public.next_round(s, 1), 'double clic : sans effet');
  perform t.ok((t.state(s) -> 'session' ->> 'current_round')::int = 2, 'une seule manche ajoutée');
  perform t.ok(t.round_card(s, 2) ->> 'id' <> t.round_card(s, 1) ->> 'id', 'pas de carte répétée');
  perform t.okr(public.submit_answer(s, 2, 'answer', '{"text": "pas encore révélée"}'), 'A répond à la carte 2');
  perform t.okr(public.finish_session(s), 'sortie commune');
  st := t.state(s);
  perform t.ok(st -> 'session' ->> 'status' = 'ended' and (st -> 'session' ->> 'total_rounds')::int = 1, 'fin : seule la carte révélée reste');
  perform t.ok(st::text not like '%pas encore révélée%', 'la réponse non révélée n''apparaît pas');
  perform t.logout();
end $$;

-- Aucune carte avec un thème exclu, sur plusieurs parties.
do $$
declare s uuid; i int; bad int := 0;
begin
  for i in 1..3 loop
    perform t.login('00000000-0000-4000-a000-00000000000a');
    s := (public.create_session('N2-001') ->> 'session_id')::uuid;
    perform public.update_session_settings(s, '{"cartes": 12}');
    perform public.set_ready(s, true);
    perform t.logout();
    perform t.login('00000000-0000-4000-a000-00000000000b');
    perform public.set_session_prefs(s, false, array['desir', 'passe']);
    perform public.set_ready(s, true);
    perform t.logout();
    perform t.login('00000000-0000-4000-a000-00000000000a');
    perform t.ok((t.state(s) -> 'session' ->> 'status') = 'lobby', 'préférence modifiée : il faut reconfirmer');
    perform public.set_ready(s, true);
    perform t.logout();
    perform t.login('00000000-0000-4000-a000-00000000000b');
    perform public.set_ready(s, true);
    perform t.logout();
    select count(*) into bad from public.session_rounds r join public.game_cards c on c.id = r.card ->> 'id'
      where r.session_id = s and c.topic_tags && array['desir', 'passe', 'ancienne_relation'];
    perform t.ok(bad = 0, 'exclusions réunies : aucun thème exclu tiré');
    update public.game_sessions set status = 'abandoned' where id = s;
  end loop;
end $$;

-- ===== 3. +18 : double accord, retrait immédiat d'une carte intime non révélée ====
update public.profiles set intimate_opt_in = true
  where id in ('00000000-0000-4000-a000-00000000000a', '00000000-0000-4000-a000-00000000000b');
-- Toutes les cartes non intimes déjà « vues » : la seule carte disponible sera intime.
do $$
declare s uuid; c jsonb;
begin
  perform t.login('00000000-0000-4000-a000-00000000000a');
  s := (public.create_session('N2-002') ->> 'session_id')::uuid;
  perform t.okr(public.set_session_prefs(s, true, '{}'), 'A active le +18');
  perform public.set_ready(s, true);
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform t.okr(public.set_session_prefs(s, true, '{}'), 'B active le +18');
  perform public.set_ready(s, true);
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform public.set_ready(s, true);
  perform t.logout();
  -- Pour le test, on force une carte +18 en manche 1.
  update public.session_rounds set card = card || jsonb_build_object('id', (select id from public.game_cards where game_id = 'N2-002' and adult limit 1), 'adult', true)
    where session_id = s and round_no = 1;
  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform t.okr(public.submit_answer(s, 1, 'choice', '{"choice": 0}'), 'B répond à la carte +18');
  perform t.okr(public.set_session_prefs(s, false, '{}'), 'B retire le +18 en cours de partie');
  c := t.round_card(s, 1);
  perform t.ok(not (c ->> 'adult')::boolean, 'la carte intime non révélée est remplacée aussitôt');
  perform t.ok(t.n_answers(s) = 0, 'sa réponse est effacée, rien n''est révélé');
  perform t.err(public.submit_answer(s, 1, 'choice', '{"choice": 5}'), 'invalid_answer', 'choix hors liste');
  perform t.okr(public.submit_answer(s, 1, 'choice', '{"choice": "depends", "comment": "selon le jour"}'), '« Ça dépend » accepté');
  perform t.err(public.submit_answer(s, 1, 'choice', '{"choice": 1}'), 'already_submitted', 'pas de second choix');
  perform t.logout();
  update public.game_sessions set status = 'abandoned' where id = s;
end $$;
update public.profiles set intimate_opt_in = false
  where id in ('00000000-0000-4000-a000-00000000000a', '00000000-0000-4000-a000-00000000000b');

-- ===== 4. N2-004 : rôles alternés, score sur cartes ordinaires seulement ===========
do $$
declare s uuid; card jsonb;
begin
  perform t.login('00000000-0000-4000-a000-00000000000a');
  s := (public.create_session('N2-004') ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform public.set_ready(s, true);
  perform t.err(public.submit_answer(s, 1, 'choice', '{"choice": 1}'), 'not_your_turn', 'manche 1 : B prédit, il ne choisit pas');
  perform t.okr(public.submit_answer(s, 1, 'guess', '{"choice": 1}'), 'B prédit');
  perform t.err(public.submit_answer(s, 1, 'guess', '{"choice": 2}'), 'already_submitted', 'une seule prédiction');
  perform t.err(public.submit_answer(s, 1, 'guess', '{"choice": "other"}'), 'invalid_answer', '« autre » réservé à la personne ciblée');
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform t.ok(t.other_payload(s, 1, 'guess') is null, 'la prédiction reste cachée');
  perform t.okr(public.submit_answer(s, 1, 'choice', '{"choice": 1}'), 'A choisit');
  perform public.next_round(s, 1);
  card := t.round_card(s, 2);
  perform t.ok((card ->> 'role_a')::int = 2, 'manche 2 : les rôles s''inversent');
  perform t.okr(public.finish_session(s), 'fin');
  perform t.ok((t.state(s) -> 'session' -> 'result' -> 'points' ->> '2')::int = 1, 'B marque 1 point');
  perform t.logout();
end $$;

-- ===== 5. N2-005 : portrait, relance unique, mot qui surprend ======================
do $$
declare s uuid; card jsonb;
begin
  perform t.login('00000000-0000-4000-a000-00000000000a');
  s := (public.create_session('N2-005') ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform public.set_ready(s, true);
  card := t.round_card(s, 1);
  perform t.ok(jsonb_array_length(card -> 'words') = 20 and card #>> '{words,0,v,f}' is not null, '20 mots avec forme féminine');
  perform t.okr(public.reroll_round(s, 1), 'relance');
  perform t.err(public.reroll_round(s, 1), 'not_allowed', 'une seule relance');
  perform t.err(public.submit_answer(s, 1, 'pick', '{"items": [0, 1, 2, 3]}'), 'invalid_answer', '4 mots : refusé');
  perform t.err(public.submit_answer(s, 1, 'pick', '{"items": [0, 0, 1, 2, 3]}'), 'invalid_answer', 'mot en double : refusé');
  perform t.err(public.submit_answer(s, 1, 'pick', '{"items": [0, 1, 2, 3], "custom": ["a", "b"]}'), 'invalid_answer', 'deux mots personnels : refusé');
  perform t.okr(public.submit_answer(s, 1, 'pick', '{"items": [0, 1, 2, 3], "custom": ["rieuse"]}'), 'B : 4 mots + 1 personnel');
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform t.err(public.reroll_round(s, 1), 'not_allowed', 'pas de relance après une réponse');
  perform t.okr(public.submit_answer(s, 1, 'pick', '{"items": [5, 6, 7, 8, 9]}'), 'A : 5 mots');
  perform t.err(public.submit_answer(s, 1, 'surprise', '{"i": 9}'), 'invalid_answer', 'entourer un mot absent du portrait de B');
  perform t.okr(public.submit_answer(s, 1, 'surprise', '{"c": 0}'), 'A entoure le mot personnel de B');
  perform t.ok(t.state(s) -> 'session' ->> 'status' = 'ended', 'partie terminée après la révélation');
  perform t.logout();
end $$;

-- ===== 6. N2-010 : écoute, visibilité immédiate et ordre ============================
do $$
declare s uuid;
begin
  perform t.login('00000000-0000-4000-a000-00000000000a');
  s := (public.create_session('N2-010') ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform public.set_ready(s, true);
  perform t.err(public.submit_answer(s, 1, 'reformulate', '{"text": "trop tôt"}'), 'previous_step_missing', 'reformuler avant le récit : refusé');
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform t.okr(public.submit_answer(s, 1, 'share', '{"topic": 0, "text": "Mon récit"}'), 'A raconte');
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform t.ok(t.other_payload(s, 1, 'share') ->> 'text' = 'Mon récit', 'B lit le récit tout de suite');
  perform t.okr(public.submit_answer(s, 1, 'reformulate', '{"text": "Tu dis que…"}'), 'B reformule');
  perform t.err(public.submit_answer(s, 1, 'confirm', '{"ok": true}'), 'not_your_turn', 'seul l''auteur confirme');
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform t.okr(public.submit_answer(s, 1, 'confirm', '{"ok": false, "nuance": "presque"}'), 'A précise une nuance');
  perform t.okr(public.next_round(s, 1), 'tour suivant');
  perform t.ok((t.round_card(s, 2) ->> 'role_a')::int = 2, 'B raconte au tour 2');
  perform t.logout();
  update public.game_sessions set status = 'abandoned' where id = s;
end $$;

-- ===== 7. N2-012 : capsule, champs non partagés, date de réouverture ================
do $$
declare s uuid;
begin
  perform t.login('00000000-0000-4000-a000-00000000000a');
  s := (public.create_session('N2-012') ->> 'session_id')::uuid;
  insert into t.ids values ('capsule', s::text);
  perform t.okr(public.update_session_settings(s, '{"delai": 7}'), 'réouverture dans 7 jours');
  perform public.set_ready(s, true);
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform public.set_ready(s, true);
  perform t.okr(public.submit_answer(s, 1, 'capsule',
    '{"fields": [{"text": "partagé", "shared": true}, {"text": "gardé pour moi", "shared": false}, {"text": "", "shared": true}]}'), 'B ferme sa capsule');
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform t.okr(public.submit_answer(s, 1, 'capsule', '{"fields": [{"text": "x", "shared": true}, {}, {}]}'), 'A ferme sa capsule');
  perform t.ok(t.other_payload(s, 1, 'capsule') is null, 'rien de visible avant la date');
  perform t.ok((t.state(s) -> 'rounds' -> 0 ->> 'reveal_at') is not null, 'la date de réouverture est annoncée');
  perform t.okr(public.close_session(s), 'rangée');
  perform t.logout();
  -- Sept jours plus tard.
  update public.session_rounds set revealed_at = now() - interval '1 minute' where session_id = s;
  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform t.ok(t.other_payload(s, 1, 'capsule') #>> '{fields,0,text}' = 'partagé', 'le champ partagé s''ouvre');
  perform t.ok(t.state(s)::text not like '%gardé pour moi%', 'le champ gardé pour soi n''est jamais montré');
  perform t.logout();
end $$;

-- ===== 8. N2-013 et N2-014 : budget, combinaison commune, moitié de scène ============
do $$
declare s uuid; acts jsonb; cheap int[];
begin
  perform t.login('00000000-0000-4000-a000-00000000000a');
  s := (public.create_session('N2-013') ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform public.set_ready(s, true);
  acts := t.round_card(s, 1) -> 'activities';
  -- Les quatre activités les plus chères dépassent 12 jetons.
  select array_agg(i - 1 order by (v -> 'v' ->> 'cost')::int desc) into cheap from jsonb_array_elements(acts) with ordinality x(v, i);
  perform t.ok((select sum((acts -> k -> 'v' ->> 'cost')::int) from unnest(cheap[1:4]) k) > 12, 'jeu de test : plus de 12 jetons');
  perform t.err(public.submit_answer(s, 1, 'buy', jsonb_build_object('items', to_jsonb(cheap[1:4]))), 'invalid_answer', 'plus de 12 jetons : refusé');
  perform t.err(public.submit_answer(s, 1, 'buy', jsonb_build_object('items', to_jsonb(cheap[1:5]))), 'invalid_answer', 'plus de 4 activités : refusé');
  perform t.okr(public.submit_answer(s, 1, 'buy', '{"items": [0, 1]}'), 'B achète');
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000a');
  perform t.okr(public.submit_answer(s, 1, 'buy', '{"items": [2]}'), 'A achète');
  perform t.err(public.submit_answer(s, 1, 'common', '{"items": [5]}'), 'invalid_answer', 'combinaison hors des choix : refusée');
  perform t.okr(public.submit_answer(s, 1, 'common', '{"items": [0, 2]}'), 'proposition commune');
  perform t.okr(public.submit_answer(s, 1, 'common', '{"items": [2]}'), 'une révision');
  perform t.err(public.submit_answer(s, 1, 'common', '{"items": [0]}'), 'already_submitted', 'pas de deuxième révision');
  perform t.logout();

  perform t.login('00000000-0000-4000-a000-00000000000a');
  s := (public.create_session('N2-014') ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform public.set_ready(s, true);
  -- B est au siège 2 : colonnes 3 à 5.
  perform t.err(public.submit_answer(s, 1, 'place', '{"objects": [{"i":0,"x":0,"y":0},{"i":1,"x":4,"y":0},{"i":2,"x":5,"y":0}]}'), 'invalid_answer', 'objet hors de sa moitié');
  perform t.err(public.submit_answer(s, 1, 'place', '{"objects": [{"i":0,"x":3,"y":0},{"i":1,"x":3,"y":0},{"i":2,"x":5,"y":0}]}'), 'invalid_answer', 'deux objets sur la même case');
  perform t.okr(public.submit_answer(s, 1, 'place', '{"objects": [{"i":0,"x":3,"y":0},{"i":1,"x":4,"y":1},{"i":2,"x":5,"y":3}]}'), 'B place ses objets');
  perform t.err(public.submit_answer(s, 1, 'agree', '{"pick": 1}'), 'not_revealed', 'accord impossible avant la révélation');
  perform t.logout();
  update public.game_sessions set status = 'abandoned' where id = s;
end $$;

-- ===== 9. Dessin : format contrôlé côté serveur ======================================
do $$
declare s uuid;
begin
  perform t.login('00000000-0000-4000-a000-00000000000a');
  s := (public.create_session('N2-015') ->> 'session_id')::uuid;
  perform public.set_ready(s, true);
  perform t.logout();
  perform t.login('00000000-0000-4000-a000-00000000000b');
  perform public.set_ready(s, true);
  perform t.err(public.submit_answer(s, 1, 'gesture', '{"action": 0, "drawing": [{"c": 0, "w": 1, "p": [[1.5, 0]]}]}'), 'invalid_answer', 'point hors du cadre');
  perform t.err(public.submit_answer(s, 1, 'gesture', '{"action": 0}'), 'invalid_answer', 'ni texte ni dessin');
  perform t.okr(public.submit_answer(s, 1, 'gesture', '{"action": 3, "drawing": [{"c": 2, "w": 1, "p": [[0.1, 0.2], [0.3333333, 0.4]]}]}'), 'dessin accepté');
  perform t.ok(t.n_answers(s) = 1, 'une réponse');
  perform t.logout();
end $$;

-- ===== 10. Effacement différé (24 h) ; un compte extérieur ne voit rien ==============
do $$
declare s uuid := (select v::uuid from t.ids where k = 's1'); blocked boolean := false;
begin
  perform t.login('00000000-0000-4000-a000-00000000000c');
  perform t.err(public.get_session_state(s), 'session_not_found', 'C ne voit pas la partie');
  begin
    perform public.submit_answer(s, 1, 'reaction', '{"text": "x"}');
  exception when others then
    blocked := sqlerrm = 'session_not_found';
  end;
  perform t.ok(blocked, 'C ne peut pas agir sur la partie');
  perform t.logout();
end $$;

do $$
declare s uuid := (select v::uuid from t.ids where k = 's1'); cap uuid := (select v::uuid from t.ids where k = 'capsule');
begin
  update public.game_sessions set ended_at = now() - interval '25 hours' where id in (s, cap);
  perform private.purge_expired_sessions();
  perform t.ok(t.n_answers(s) = 0, '24 h après la fin : réponses effacées');
  perform t.ok((select status from public.game_sessions where id = s) = 'closed', 'partie rangée, titre et date conservés');
  perform t.ok(t.n_answers(cap) = 2, 'la capsule garde son contenu');
end $$;

select 'TOUS LES TESTS FAMILLE 1 SONT PASSÉS' as resultat;
rollback;
