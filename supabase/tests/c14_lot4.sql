-- Tests du lot 4 : Le Pendu, Petit bac, Cite trois en 10 secondes. L'heure est figée dans la transaction :
-- les échéances sont déplacées à la main pour simuler le temps qui passe. Transaction annulée à la fin.
begin;

create schema t10;
create function t10.as_user(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
create function t10.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is distinct from true then raise exception 'ÉCHEC : %', msg; end if;
end $$;
create function t10.err(res jsonb, expected text, msg text) returns void language plpgsql as $$
begin
  if res ->> 'error' is distinct from expected then raise exception 'ÉCHEC : % (attendu %, obtenu %)', msg, expected, res; end if;
end $$;
create function t10.card(s uuid) returns jsonb language sql as $$
  select card from public.session_rounds r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
create function t10.sec(s uuid) returns jsonb language sql as $$
  select secret from private.round_secrets r join public.game_sessions g on g.id = r.session_id and r.round_no = g.current_round where g.id = s $$;
create function t10.patch(s uuid, p jsonb) returns void language sql as $$
  update public.session_rounds r set card = card || p from public.game_sessions g
  where g.id = s and r.session_id = s and r.round_no = g.current_round $$;
create function t10.uid(s uuid, seat int) returns uuid language sql as $$
  select user_id from public.session_players where session_id = s and seat = $2 $$;
create function t10.mv(s uuid, seat int, typ text, p jsonb default '{}') returns jsonb language plpgsql as $$
begin
  perform t10.as_user(t10.uid(s, seat));
  return public.play_move(s, (select current_round from public.game_sessions where id = s), gen_random_uuid(), typ, p);
end $$;
create function t10.after(s uuid, seat int, typ text, p jsonb default '{}') returns jsonb language plpgsql as $$
begin
  perform t10.as_user(t10.uid(s, seat));
  return public.round_after(s, (select current_round from public.game_sessions where id = s), typ, p);
end $$;
create function t10.state(s uuid, seat int) returns jsonb language plpgsql as $$
begin
  perform t10.as_user(t10.uid(s, seat));
  return public.get_session_state(s);
end $$;
create function t10.both_continue(s uuid) returns void language plpgsql as $$
begin
  perform t10.after(s, 1, 'continue');
  perform t10.after(s, 2, 'continue');
end $$;
create function t10.start(gid text, settings jsonb default null, adult boolean default false) returns uuid language plpgsql as $$
declare s uuid;
begin
  update public.game_sessions set status = 'abandoned' where status in ('lobby', 'playing', 'paused', 'ended');
  perform t10.as_user('00000000-0000-4000-a000-0000000000aa');
  s := (public.create_session(gid) ->> 'session_id')::uuid;
  if settings is not null then perform public.update_session_settings(s, settings); end if;
  if adult then
    perform public.set_session_prefs(s, true, '{}');
    perform t10.as_user('00000000-0000-4000-a000-0000000000bb');
    perform public.set_session_prefs(s, true, '{}');
    perform t10.as_user('00000000-0000-4000-a000-0000000000aa');
  end if;
  perform public.set_ready(s, true);
  perform t10.as_user('00000000-0000-4000-a000-0000000000bb');
  perform public.set_ready(s, true);
  return s;
end $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-a000-0000000000aa', 'joueur-aa@noodeu.invalid', '{"display_name":"A"}'),
  ('00000000-0000-4000-a000-0000000000bb', 'joueur-bb@noodeu.invalid', '{"display_name":"B"}');
do $$
declare r jsonb;
begin
  perform t10.as_user('00000000-0000-4000-a000-0000000000aa');
  r := public.create_invitation();
  perform t10.as_user('00000000-0000-4000-a000-0000000000bb');
  perform public.claim_invitation(r ->> 'code');
  perform t10.as_user('00000000-0000-4000-a000-0000000000aa');
  perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

-- ===== Catalogue =====================================================================
do $$ begin
  perform t10.ok((select count(*) from public.games where id in ('N2-023', 'N2-018', 'nd-cite-trois') and implementation = 'playable') = 3,
                 '3 jeux jouables');
  perform t10.ok((select count(*) from public.content_banks where bank = 'hangman_words') = 288, '288 mots relus');
  perform t10.ok((select count(*) from public.content_banks where bank = 'petit_bac') = 134, 'index Petit bac de 134 entrées');
  perform t10.ok((select count(*) from public.content_banks where bank = 'cite_trois') = 24
                 and (select count(*) from public.content_banks where bank = 'cite_trois' and (value ->> 'adult')::boolean) = 14,
                 '24 consignes du catalogue final dont 14 +18');
  perform t10.ok(not exists (select 1 from public.content_banks where bank = 'cite_trois'
                             and (value ? 'editorial_examples_not_for_runtime' or value ? 'judge_note_fr' or value::text ilike '%exemple%')),
                 'aucun exemple éditorial ni note de jugement importé');
  perform t10.ok(private.nd_norm('  Côte d’Ivoire ') = 'COTE D''IVOIRE' and private.nd_norm('cœur') = 'COEUR', 'normalisation');
end $$;

-- ===== Pendu : donneur seul, accents, lettre répétée, six erreurs, mot banni =====
do $$
declare s uuid; c jsonb; st jsonb; giver int; guesser int; w jsonb; word_id text; ids text[]; i int; l text;
begin
  s := t10.start('N2-023', '{"cartes": 4}');
  c := t10.card(s);
  giver := (c ->> 'giver')::int; guesser := 3 - giver;
  perform t10.ok(c ->> 'phase' = 'choose' and (c ->> 'guesser')::int = guesser, 'rôles donneur / devineur');
  st := t10.state(s, guesser);
  perform t10.ok(coalesce(st #> '{rounds,0,private}', 'null') = 'null', 'le devineur ne voit pas la liste');
  st := t10.state(s, giver);
  perform t10.ok(jsonb_array_length(st #> '{rounds,0,private,choices}') between 1 and 8, 'liste privée du donneur');
  perform t10.err(t10.mv(s, guesser, 'choose_word', jsonb_build_object('word_id', st #>> '{rounds,0,private,choices,0,id}')), 'not_your_turn', 'devineur ne choisit pas');
  perform t10.err(t10.mv(s, giver, 'choose_word', '{"word_id": "inconnu"}'), 'invalid_move', 'mot hors liste refusé');
  -- Mot « école » imposé pour vérifier les accents (proposé dans la liste du donneur).
  select value into w from public.content_banks where bank = 'hangman_words' and value ->> 'text' = 'école';
  perform t10.ok(w is not null, 'école dans le lot relu');
  update private.round_secrets set secret = jsonb_set(secret, array['seats', giver::text, 'choices'],
    jsonb_build_array(jsonb_build_object('id', w ->> 'id', 'text', w ->> 'text'))) where session_id = s and round_no = 1;
  perform t10.mv(s, giver, 'choose_word', jsonb_build_object('word_id', w ->> 'id'));
  c := t10.card(s);
  perform t10.ok(c ->> 'phase' = 'guess' and (c ->> 'length')::int = 5 and c -> 'mask' = '[null, null, null, null, null]', 'masque de 5 cases');
  st := t10.state(s, guesser);
  perform t10.ok(position('école' in st::text) = 0 and position('ECOLE' in st::text) = 0, 'mot jamais transmis au devineur');
  perform t10.ok(t10.state(s, giver) #>> '{rounds,0,private,word,text}' = 'école', 'le donneur voit son mot');
  perform t10.err(t10.mv(s, giver, 'guess_letter', '{"letter": "E"}'), 'not_your_turn', 'donneur ne devine pas');
  perform t10.mv(s, guesser, 'guess_letter', '{"letter": "e"}');
  c := t10.card(s);
  perform t10.ok(c -> 'mask' = '["é", null, null, null, "e"]' and (c ->> 'errors')::int = 0, 'E révèle é et e, forme d''origine');
  perform t10.err(t10.mv(s, guesser, 'guess_letter', '{"letter": "E"}'), 'repeated', 'lettre répétée refusée');
  perform t10.ok((t10.card(s) ->> 'errors')::int = 0, 'sans erreur supplémentaire');
  foreach l in array array['Z', 'X', 'W', 'K', 'Q'] loop perform t10.mv(s, guesser, 'guess_letter', jsonb_build_object('letter', l)); end loop;
  c := t10.card(s);
  perform t10.ok((c ->> 'errors')::int = 5 and not (c ->> 'done')::boolean, 'cinq erreurs, manche ouverte');
  perform t10.mv(s, guesser, 'guess_letter', '{"letter": "Y"}');
  c := t10.card(s);
  perform t10.ok((c ->> 'done')::boolean and not (c ->> 'found')::boolean and c ->> 'text' = 'école'
                 and (c #>> array['scores', guesser::text])::int = 0, 'sixième erreur : mot révélé, 0 point');
  perform t10.both_continue(s);
  c := t10.card(s);
  perform t10.ok((c ->> 'giver')::int = guesser, 'rôles inversés');
  perform t10.ok(not exists (select 1 from jsonb_array_elements(t10.sec(s) #> array['seats', guesser::text, 'choices']) x where x ->> 'id' = w ->> 'id'),
                 'mot déjà joué jamais reproposé');
  -- Mot trouvé : 1 point au devineur.
  word_id := t10.sec(s) #>> array['seats', guesser::text, 'choices', '0', 'id'];
  perform t10.mv(s, guesser, 'choose_word', jsonb_build_object('word_id', word_id));
  for l in select distinct u from jsonb_array_elements_text(t10.sec(s) #> '{word,units}') u loop
    perform t10.mv(s, giver, 'guess_letter', jsonb_build_object('letter', l));
  end loop;
  c := t10.card(s);
  perform t10.ok((c ->> 'found')::boolean and (c #>> array['scores', giver::text])::int = 1, 'mot trouvé : 1 point');
end $$;

-- ===== Petit bac : lettre secrète jusqu'au chargement, Stop, index par catégorie, arbitrage, barème =====
do $$
declare s uuid; c jsonb; st jsonb; letter text; r jsonb;
begin
  s := t10.start('N2-018');
  c := t10.card(s);
  perform t10.ok(c ->> 'phase' = 'loaded' and not (c ? 'letter') and coalesce(t10.state(s, 1) #> '{rounds,0,private}', 'null') = 'null',
                 'lettre retenue au serveur');
  perform t10.mv(s, 1, 'round_loaded');
  perform t10.ok(t10.card(s) ->> 'phase' = 'loaded', 'un seul chargement : pas de départ');
  perform t10.mv(s, 2, 'round_loaded');
  c := t10.card(s);
  perform t10.ok(c ->> 'phase' = 'write' and c ->> 'letter' in ('B', 'C', 'R', 'T'), 'départ commun, lettre couverte');
  -- Lettre imposée « C » : chat (animal), Copenhague (ville), Chili (pays).
  perform t10.patch(s, '{"letter": "C"}');
  perform t10.mv(s, 1, 'save_field', '{"category_id": "animal", "text": "Chat", "draft_revision": 1}');
  perform t10.err(t10.mv(s, 1, 'save_field', '{"category_id": "animal", "text": "Chien", "draft_revision": 1}'), 'stale_draft', 'révision non croissante refusée');
  perform t10.mv(s, 1, 'save_field', '{"category_id": "ville", "text": "chat", "draft_revision": 1}');
  perform t10.mv(s, 2, 'save_field', '{"category_id": "animal", "text": "chat", "draft_revision": 1}');
  perform t10.mv(s, 2, 'save_field', '{"category_id": "pays", "text": "Chili", "draft_revision": 1}');
  perform t10.mv(s, 2, 'save_field', '{"category_id": "objet", "text": "Cafetiere en or", "draft_revision": 1}');
  st := t10.state(s, 2);
  perform t10.ok(position('Chat' in st::text) = 0, 'brouillons de A invisibles pour B');
  perform t10.err(t10.mv(s, 1, 'stop', '{"drafts": {}}'), 'too_early', 'Stop indisponible avant 10 s');
  perform t10.patch(s, jsonb_build_object('stop_after', now() - interval '1 second'));
  perform t10.err(t10.mv(s, 1, 'stop', '{"drafts": {}}'), 'fields_missing', 'Stop exige quatre cases remplies');
  perform t10.mv(s, 1, 'stop', '{"drafts": {"objet": {"text": "Crayon", "draft_revision": 1}, "pays": {"text": "Chili", "draft_revision": 1}}}');
  c := t10.card(s);
  perform t10.ok(c ->> 'phase' = 'validation' and (c ->> 'stopped_by')::int = 1, 'Stop gèle la manche');
  perform t10.err(t10.mv(s, 2, 'save_field', '{"category_id": "ville", "text": "Copenhague", "draft_revision": 1}'), 'phase', 'plus de saisie après Stop');
  perform t10.ok(c #>> '{answers,1,animal,status}' = 'valid' and c #>> '{answers,1,ville,status}' = 'unknown'
                 and c #>> '{answers,2,ville,status}' = 'empty' and c #>> '{answers,2,objet,status}' = 'unknown',
                 'chat refusé comme ville par l''index (inconnu, à arbitrer), case vide');
  -- Arbitrage : ville de A rejetée par les deux, objet de B : votes opposés -> non tranché.
  perform t10.mv(s, 1, 'judge_entry', '{"seat": 1, "category_id": "ville", "verdict": "reject"}');
  perform t10.mv(s, 2, 'judge_entry', '{"seat": 1, "category_id": "ville", "verdict": "reject"}');
  perform t10.mv(s, 1, 'judge_entry', '{"seat": 2, "category_id": "objet", "verdict": "reject"}');
  perform t10.mv(s, 2, 'judge_entry', '{"seat": 2, "category_id": "objet", "verdict": "accept"}');
  perform t10.ok(position('reject' in (t10.state(s, 2) #>> '{rounds,0,card}')) = 0, 'votes privés avant clôture');
  perform t10.mv(s, 1, 'confirm_validation');
  perform t10.mv(s, 2, 'confirm_validation');
  c := t10.card(s);
  perform t10.ok((c ->> 'done')::boolean, 'deux confirmations : résultat');
  perform t10.ok((c #>> '{answers,1,animal,points}')::int = 5 and (c #>> '{answers,2,animal,points}')::int = 5, 'même animal : 5 chacun');
  perform t10.ok((c #>> '{answers,1,pays,points}')::int = 5, 'même pays : 5 chacun');
  perform t10.ok(c #>> '{answers,2,objet,final}' = 'contested' and (c #>> '{answers,1,objet,points}')::int = 15
                 and (c #>> '{answers,2,objet,points}')::int = 0, 'objet non tranché : 0, l''unique valide prend 15');
  perform t10.ok(c #>> '{answers,1,ville,final}' = 'rejected' and (c #>> '{answers,1,ville,points}')::int = 0, 'ville rejetée par les deux');
  perform t10.ok((c #>> '{scores,1}')::int = 25 and (c #>> '{scores,2}')::int = 10, 'totaux de manche');
  -- Manche 2 : échéance sans Stop, deux réponses inconnues différentes jugées « différentes ».
  perform t10.both_continue(s);
  c := t10.card(s);
  perform t10.ok(c ->> 'phase' = 'loaded', 'nouvelle manche');
  perform t10.mv(s, 1, 'round_loaded'); perform t10.mv(s, 2, 'round_loaded');
  letter := t10.card(s) ->> 'letter';
  perform t10.ok(letter <> (select secret ->> 'letter' from private.round_secrets where session_id = s and round_no = 1), 'lettre sans remise');
  perform t10.mv(s, 1, 'save_field', jsonb_build_object('category_id', 'animal', 'text', letter || 'zzanimal', 'draft_revision', 1));
  perform t10.mv(s, 2, 'save_field', jsonb_build_object('category_id', 'animal', 'text', letter || 'yyanimal', 'draft_revision', 1));
  perform t10.err(t10.mv(s, 1, 'expire'), 'too_early', 'pas d''expiration anticipée');
  perform t10.patch(s, jsonb_build_object('deadline_at', now()));
  perform t10.err(t10.mv(s, 2, 'save_field', '{"category_id": "pays", "text": "x", "draft_revision": 1}'), 'time_up', 'saisie refusée à l''échéance');
  perform t10.mv(s, 2, 'expire');
  c := t10.card(s);
  perform t10.ok(c ->> 'phase' = 'validation' and c ->> 'stopped_by' is null, 'échéance : gel');
  perform t10.mv(s, 1, 'judge_entry', '{"seat": 1, "category_id": "animal", "verdict": "accept"}');
  perform t10.mv(s, 2, 'judge_entry', '{"seat": 1, "category_id": "animal", "verdict": "accept"}');
  perform t10.mv(s, 1, 'judge_entry', '{"seat": 2, "category_id": "animal", "verdict": "accept"}');
  perform t10.mv(s, 2, 'judge_entry', '{"seat": 2, "category_id": "animal", "verdict": "accept"}');
  perform t10.mv(s, 1, 'judge_identity', '{"category_id": "animal", "same": false}');
  perform t10.mv(s, 2, 'judge_identity', '{"category_id": "animal", "same": false}');
  -- Clôture à 60 s sans confirmation.
  perform t10.patch(s, jsonb_build_object('validation_deadline', now()));
  perform t10.mv(s, 1, 'expire');
  c := t10.card(s);
  perform t10.ok((c ->> 'done')::boolean and (c #>> '{answers,1,animal,points}')::int = 10 and (c #>> '{answers,2,animal,points}')::int = 10,
                 'deux réponses acceptées et différentes : 10 chacun');
end $$;

-- ===== Cite trois : chargement des deux, consigne retenue, accusés, juge seul, corrections, 30 points =====
do $$
declare s uuid; c jsonb; resp int; judge int; st jsonb; r jsonb; i int;
begin
  s := t10.start('nd-cite-trois');
  c := t10.card(s);
  perform t10.ok(c ->> 'phase' = 'loading' and not (c ? 'text') and not (c ? 'respondent'), 'consigne et répondant retenus');
  perform t10.ok(position(t10.sec(s) ->> 'text' in t10.state(s, 1)::text) = 0, 'consigne jamais transmise avant le départ');
  perform t10.err(t10.mv(s, 1, 'round_loaded'), 'call_required', 'appel externe à confirmer');
  perform t10.mv(s, 1, 'round_loaded', '{"call": true}');
  perform t10.ok(t10.card(s) ->> 'phase' = 'loading', 'un seul chargement : aucun départ');
  perform t10.mv(s, 2, 'round_loaded', '{"call": true}');
  c := t10.card(s);
  perform t10.ok(c ->> 'phase' = 'live' and (c ->> 'starts_at')::timestamptz = now() + interval '1500 milliseconds'
                 and (c ->> 'deadline_at')::timestamptz = (c ->> 'starts_at')::timestamptz + interval '10 seconds', 'départ à +1,5 s, échéance +10 s');
  perform t10.err(t10.mv(s, 1, 'prompt_received'), 'too_early', 'consigne refusée avant le départ');
  perform t10.patch(s, jsonb_build_object('starts_at', now() - interval '100 milliseconds', 'deadline_at', now() + interval '9900 milliseconds'));
  perform t10.mv(s, 1, 'prompt_received');
  c := t10.card(s);
  resp := (c ->> 'respondent')::int; judge := (c ->> 'judge')::int;
  perform t10.ok(c ->> 'text' = t10.sec(s) ->> 'text' and judge = 3 - resp, 'consigne et rôles délivrés au départ');
  perform t10.err(t10.mv(s, judge, 'verdict', '{"success": true}'), 'waiting_ack', 'pas de verdict avant les deux accusés');
  perform t10.mv(s, 2, 'prompt_received');
  perform t10.err(t10.mv(s, resp, 'verdict', '{"success": true}'), 'not_your_turn', 'le répondant ne juge pas');
  -- À zéro : pas de résultat automatique, le juge peut encore valider.
  perform t10.patch(s, jsonb_build_object('deadline_at', now() - interval '200 milliseconds'));
  perform t10.ok(not (t10.card(s) ->> 'done')::boolean, 'zéro sans verdict : aucune attribution');
  perform t10.mv(s, judge, 'verdict', '{"success": true}');
  c := t10.card(s);
  perform t10.ok((c ->> 'done')::boolean and (c #>> array['scores', resp::text])::int = 3, 'Réussi : +3 au répondant');
  -- Correction : bloque Continuer, appliquée une fois avec les deux accords.
  perform t10.after(s, judge, 'correction_request');
  perform t10.err(t10.after(s, resp, 'continue'), 'correction_pending', 'Continuer bloqué pendant la correction');
  perform t10.after(s, resp, 'correction_vote', '{"accept": true}');
  c := t10.card(s);
  perform t10.ok(not (c ? 'correction') and (c #>> array['scores', resp::text])::int = 0 and (c ->> 'corrected')::boolean, 'correction +3 vers 0');
  perform t10.after(s, resp, 'correction_vote', '{"accept": true}');
  perform t10.ok((t10.card(s) #>> array['scores', resp::text])::int = 0, 'delta appliqué une seule fois');
  perform t10.both_continue(s);
  -- Manche 2 : accusé manquant après 750 ms, manche annulée.
  c := t10.card(s);
  perform t10.ok(c ->> 'phase' = 'loading' and not (c ->> 'need_call')::boolean, 'nouvelle manche sans reconfirmer l''appel');
  perform t10.mv(s, 1, 'round_loaded'); perform t10.mv(s, 2, 'round_loaded');
  perform t10.patch(s, jsonb_build_object('starts_at', now() - interval '100 milliseconds'));
  perform t10.mv(s, 1, 'prompt_received');
  perform t10.patch(s, jsonb_build_object('starts_at', now() - interval '900 milliseconds'));
  perform t10.mv(s, 1, 'tick');
  c := t10.card(s);
  perform t10.ok((c ->> 'done')::boolean and c ->> 'void' = 'loading' and not (c ? 'scores') and not (c ? 'text'), 'accusé manquant : manche annulée sans point');
  perform t10.both_continue(s);
  -- Manche 3 : passage avant verdict, zéro point.
  perform t10.mv(s, 2, 'pass_round');
  perform t10.ok((t10.card(s) ->> 'skipped')::boolean and not (t10.card(s) ? 'scores'), 'Passer : zéro point');
  perform t10.both_continue(s);
  -- 27 points puis réussite : bilan à 30, fin après les deux confirmations.
  update public.session_rounds set card = card || '{"scores": {"1": 27, "2": 0}}' where session_id = s and round_no = 1;
  perform t10.mv(s, 1, 'round_loaded'); perform t10.mv(s, 2, 'round_loaded');
  perform t10.patch(s, jsonb_build_object('starts_at', now(), 'respondent', 1, 'judge', 2));
  update private.round_secrets set secret = secret || '{"respondent": 1}' where session_id = s and round_no = (select current_round from public.game_sessions where id = s);
  perform t10.mv(s, 1, 'prompt_received'); perform t10.mv(s, 2, 'prompt_received');
  perform t10.mv(s, 2, 'verdict', '{"success": true}');
  perform t10.after(s, 1, 'continue');
  perform t10.ok((select status from public.game_sessions where id = s) = 'playing', 'bilan provisoire : une confirmation ne suffit pas');
  perform t10.after(s, 2, 'continue');
  perform t10.ok((select status from public.game_sessions where id = s) = 'ended'
                 and (select (result ->> 'target_reached')::boolean and (result #>> '{points,1}')::int = 30 from public.game_sessions where id = s),
                 '30 points confirmés : fin avec vainqueur');
end $$;

-- ===== Cite trois +18 : retrait pendant une manche non jugée =====
do $$
declare s uuid; c jsonb; adult_item jsonb;
begin
  update public.profiles set intimate_opt_in = true, adult_confirmed_at = now(), max_intensity = 'hot' where id in ('00000000-0000-4000-a000-0000000000aa', '00000000-0000-4000-a000-0000000000bb');
  s := t10.start('nd-cite-trois', null, true);
  select value into adult_item from public.content_banks where bank = 'cite_trois' and (value ->> 'adult')::boolean limit 1;
  perform t10.patch(s, jsonb_build_object('adult', true, 'card_id', adult_item ->> 'id'));
  update private.round_secrets set secret = secret || jsonb_build_object('text', adult_item ->> 'text') where session_id = s and round_no = 1;
  perform t10.mv(s, 1, 'round_loaded', '{"call": true}'); perform t10.mv(s, 2, 'round_loaded', '{"call": true}');
  perform t10.patch(s, jsonb_build_object('starts_at', now()));
  perform t10.mv(s, 1, 'prompt_received');
  perform t10.as_user(t10.uid(s, 2));
  perform public.set_session_prefs(s, false, '{}');
  c := t10.card(s);
  perform t10.ok((c ->> 'redacted')::boolean and (c ->> 'done')::boolean and not (c ? 'text') and not (c ? 'scores'),
                 'retrait : manche adulte interrompue sans point, consigne retirée');
  perform t10.ok(position(adult_item ->> 'text' in t10.state(s, 1)::text) = 0, 'aucune projection adulte restante');
  update public.profiles set intimate_opt_in = false where id in ('00000000-0000-4000-a000-0000000000aa', '00000000-0000-4000-a000-0000000000bb');
end $$;

-- ===== Partenaire automatique : chaque jeu mené à son terme (le temps est avancé quand plus rien ne bouge) =====
do $$
declare s uuid; m text; seat int; n int; done boolean; c jsonb;
begin
  foreach m in array array['N2-023', 'N2-018', 'nd-cite-trois'] loop
    s := t10.start(m);
    n := 0;
    while (select status from public.game_sessions where id = s) = 'playing' and n < 600 loop
      done := false;
      foreach seat in array array[1, 2] loop
        perform t10.as_user(t10.uid(s, seat));
        if private.bot_step(s, seat) then done := true; exit; end if;
      end loop;
      if not done then
        c := t10.card(s);
        if c ->> 'phase' = 'write' then
          perform t10.patch(s, jsonb_build_object('deadline_at', now()));
          done := coalesce((t10.mv(s, 1, 'expire') ->> 'ok')::boolean, false);
        elsif c ->> 'phase' = 'live' and not (c -> 'acks' ? '1' or c -> 'acks' ? '2') then
          perform t10.patch(s, jsonb_build_object('starts_at', now()));
          done := true;
        end if;
      end if;
      perform t10.ok(done, format('le robot avance (%s, phase %s)', m, t10.card(s) ->> 'phase'));
      n := n + 1;
    end loop;
    perform t10.ok((select status from public.game_sessions where id = s) = 'ended', format('robot : partie %s menée à son terme', m));
  end loop;
end $$;

select 'TOUS LES TESTS DU LOT 4 SONT PASSÉS';
rollback;
