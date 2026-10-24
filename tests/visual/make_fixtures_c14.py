#!/usr/bin/env python3
"""États RÉELS des packs (C01) et questionnaires (C02) pour la vérification visuelle.

Produits par les vraies fonctions d'une base locale où toutes les migrations sont appliquées
(base « nd2 » par défaut, ou NOODEU_DB). Maya (vue de l'écran) et Alex jouent ; tout est annulé à la fin.
"""
import json
from datetime import datetime
import os
import subprocess

DB = os.environ.get("NOODEU_DB", "nd2")
PG = ["psql", "-h", "/var/tmp/noodeu-pg", "-p", "54329", "-U", "postgres", "-d", DB, "-At", "-v", "ON_ERROR_STOP=1"]
ME = "11111111-1111-4111-8111-111111111111"
PARTNER = "22222222-2222-4222-8222-222222222222"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")

SQL = f"""
begin;
create schema fx7;
create function fx7.as_user(p uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true); end $$;
create function fx7.mv(s uuid, typ text, p jsonb default '{{}}') returns jsonb language sql as $$
  select public.play_move(s, (select current_round from public.game_sessions where id = s), gen_random_uuid(), typ, p) $$;
create function fx7.out(k text, s uuid) returns text language plpgsql as $$
begin perform fx7.as_user('{ME}'); return 'FX ' || k || ' ' || public.get_session_state(s)::text; end $$;
create function fx7.start(gid text, adult boolean default false) returns uuid language plpgsql as $$
declare s uuid;
begin
  update public.game_sessions set status = 'abandoned' where status in ('lobby','playing','paused','ended');
  perform fx7.as_user('{ME}');
  s := (public.create_session(gid) ->> 'session_id')::uuid;
  -- Accords « À huis clos » d'abord : un changement de préférences annule les « prêt ».
  if adult then
    perform public.set_session_prefs(s, true, '{{}}');
    perform fx7.as_user('{PARTNER}'); perform public.set_session_prefs(s, true, '{{}}');
    perform fx7.as_user('{ME}');
  end if;
  perform public.set_ready(s, true);
  perform fx7.as_user('{PARTNER}');
  perform public.set_ready(s, true);
  perform fx7.as_user('{ME}');
  return s;
end $$;
-- Réponses complètes d'un test : première valeur de l'échelle (ou case cochée une fois sur trois).
-- Coup d'un siège donné (null : celui dont c'est le tour).
create function fx7.seat_mv(s uuid, seat int, typ text, p jsonb default '{{}}') returns jsonb language plpgsql as $$
declare st int := coalesce(seat, (select (card ->> 'turn')::int from public.session_rounds r join public.game_sessions g
                                  on g.id = r.session_id and r.round_no = g.current_round where g.id = s));
begin
  perform fx7.as_user((select user_id from public.session_players where session_id = s and session_players.seat = st));
  return fx7.mv(s, typ, p);
end $$;
create function fx7.all_answers(gid text) returns jsonb language sql as $$
  select jsonb_object_agg(i ->> 'id', case when i ->> 'response_type' = 'checkbox' then to_jsonb((i ->> 'source_position')::int % 3 = 0)
    else (v.config -> 'test' -> 'scales' -> (i ->> 'scale_id') -> 1 -> 'value') end)
  from public.games g join public.game_versions v on v.game_id = g.id and v.version = g.current_version,
       jsonb_array_elements(private.bank_items(v.config ->> 'bank')) i where g.id = gid $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('{ME}', 'maya@exemple.invalid', '{{"display_name":"Maya"}}'),
  ('{PARTNER}', 'alex@exemple.invalid', '{{"display_name":"Alex"}}');
update public.profiles set intimate_opt_in = true where id in ('{ME}', '{PARTNER}');
do $$ declare r jsonb; begin
  perform fx7.as_user('{ME}'); r := public.create_invitation();
  perform fx7.as_user('{PARTNER}'); perform public.claim_invitation(r ->> 'code');
  perform fx7.as_user('{ME}'); perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

create temp table fx_out (n serial, line text);
do $$ declare s uuid; i int; begin
  -- Pack vrai/faux : carte 1, personne n'a répondu.
  s := fx7.start('ND-Q-P11');
  insert into fx_out (line) select fx7.out('pack-vf-jeu', s);
  -- Pack ouvert (Aron) : Maya a répondu et attend.
  s := fx7.start('ND-Q-P01');
  perform fx7.mv(s, 'answer', '{{"choice":"private","text":"Plutôt quelqu''un qui m''inspire au quotidien."}}');
  insert into fx_out (line) select fx7.out('pack-attente', s);
  -- Révélation : Alex partage, Maya garde pour elle.
  perform fx7.as_user('{PARTNER}');
  perform fx7.mv(s, 'answer', '{{"choice":"share","text":"Quelqu''un de drôle, sans hésiter. Et toi ?"}}');
  insert into fx_out (line) select fx7.out('pack-revelation', s);
  perform public.end_pack_session(s);
  insert into fx_out (line) select fx7.out('pack-fin', s);
  -- Questionnaire à échelle : première page.
  s := fx7.start('ND-Q-012');
  insert into fx_out (line) select fx7.out('test-jeu', s);
  -- Rice (À huis clos) : page avec l'item 69 ambigu.
  s := fx7.start('ND-Q-011', true);
  perform fx7.mv(s, 'save', jsonb_build_object('answers', '{{}}'::jsonb, 'page', 6));
  insert into fx_out (line) select fx7.out('test-rice', s);
  -- ECR : Maya termine et partage ; Alex en cours.
  s := fx7.start('ND-Q-021');
  perform fx7.mv(s, 'complete', jsonb_build_object('answers', fx7.all_answers('ND-Q-021'), 'page', 1, 'share', true));
  insert into fx_out (line) select fx7.out('test-resultat', s);
  -- Fin : Alex termine et partage aussi.
  perform fx7.as_user('{PARTNER}');
  perform fx7.mv(s, 'complete', jsonb_build_object('answers', fx7.all_answers('ND-Q-021'), 'page', 1, 'share', true));
  insert into fx_out (line) select fx7.out('test-fin', s);
  -- Salon d'une activité À huis clos, avant l'accord.
  update public.game_sessions set status = 'abandoned' where status in ('lobby','playing','paused','ended');
  perform fx7.as_user('{ME}');
  s := (public.create_session('ND-Q-025') ->> 'session_id')::uuid;
  insert into fx_out (line) select fx7.out('salon-huis-clos', s);

  -- Mini-jeux (lot 2) : coups joués par les deux sièges.
  s := fx7.start('N2-076');
  perform fx7.seat_mv(s, null, 'place', '{{"cell": 4}}');
  perform fx7.seat_mv(s, null, 'place', '{{"cell": 0}}');
  perform fx7.seat_mv(s, null, 'place', '{{"cell": 2}}');
  insert into fx_out (line) select fx7.out('mini-morpion-jeu', s);
  perform fx7.seat_mv(s, null, 'place', '{{"cell": 1}}');
  perform fx7.seat_mv(s, null, 'place', '{{"cell": 6}}');
  insert into fx_out (line) select fx7.out('mini-morpion-fin', s);

  s := fx7.start('N2-079');
  perform fx7.seat_mv(s, null, 'draw_edge', jsonb_build_object('edge_id', e))
    from unnest(array['h:0:0', 'h:1:0', 'v:0:0', 'h:2:2', 'v:3:4', 'h:0:1', 'h:1:1', 'v:0:2']) e;
  perform fx7.seat_mv(s, null, 'draw_edge', '{{"edge_id": "v:0:1"}}');
  insert into fx_out (line) select fx7.out('mini-points-jeu', s);

  s := fx7.start('N2-083');
  perform fx7.seat_mv(s, 1, 'lock_gesture', '{{"gesture": "paper"}}');
  insert into fx_out (line) select fx7.out('mini-pfc-verrouille', s);
  perform fx7.seat_mv(s, 2, 'lock_gesture', '{{"gesture": "rock"}}');
  insert into fx_out (line) select fx7.out('mini-pfc-revelation', s);

  s := fx7.start('nd-de-chanceux');
  update public.session_rounds set card = card || '{{"banked": {{"1": 34, "2": 21}}, "turn_total": 9, "rolls": [4, 5], "die": 5, "turn": 1}}'
    where session_id = s and round_no = 1;
  insert into fx_out (line) select fx7.out('mini-de-jeu', s);

  s := fx7.start('N2-078');
  perform fx7.seat_mv(s, 1, 'random_fleet');
  insert into fx_out (line) select fx7.out('mini-naval-placement', s);
  perform fx7.seat_mv(s, 1, 'lock_fleet');
  perform fx7.seat_mv(s, 2, 'random_fleet');
  perform fx7.seat_mv(s, 2, 'lock_fleet');
  for i in 1..14 loop
    perform fx7.seat_mv(s, (select (card ->> 'turn')::int from public.session_rounds where session_id = s and round_no = 1),
      (private.board_bot6('battleship', (select card from public.session_rounds where session_id = s and round_no = 1), '{{}}',
        (select (card ->> 'turn')::int from public.session_rounds where session_id = s and round_no = 1))) ->> 'type',
      (private.board_bot6('battleship', (select card from public.session_rounds where session_id = s and round_no = 1), '{{}}',
        (select (card ->> 'turn')::int from public.session_rounds where session_id = s and round_no = 1))) -> 'payload');
  end loop;
  insert into fx_out (line) select fx7.out('mini-naval-tirs', s);

  -- Jeux de conversation (lot 3).
  s := fx7.start('N2-003');
  perform fx7.seat_mv(s, 1, 'lock', '{{"choice": "experienced"}}');
  insert into fx_out (line) select fx7.out('conv-jamais-attente', s);
  perform fx7.seat_mv(s, 2, 'lock', '{{"choice": "never"}}');
  insert into fx_out (line) select fx7.out('conv-jamais-revelation', s);

  s := fx7.start('N2-002');
  insert into fx_out (line) select fx7.out('conv-preferes-jeu', s);

  s := fx7.start('nd-qui-de-nous-deux');
  perform fx7.seat_mv(s, 1, 'lock', '{{"seat": 2}}');
  perform fx7.seat_mv(s, 2, 'lock', '{{"seat": 2}}');
  insert into fx_out (line) select fx7.out('conv-qui-revelation', s);

  s := fx7.start('N2-004');
  update public.session_rounds set card = card || '{{"subject": 1, "predictor": 2}}' where session_id = s and round_no = 1;
  perform fx7.seat_mv(s, 1, 'lock', '{{"text": "Un risotto aux champignons, sans hésiter."}}');
  perform fx7.seat_mv(s, 2, 'lock', '{{"text": "Des pâtes au pesto."}}');
  insert into fx_out (line) select fx7.out('conv-devine-verdict', s);

  s := fx7.start('nd-complete-phrase');
  insert into fx_out (line) select fx7.out('conv-phrase-jeu', s);

  s := fx7.start('nd-accord-desaccord');
  perform fx7.seat_mv(s, 2, 'lock', '{{"choice": "agree"}}');
  insert into fx_out (line) select fx7.out('conv-accord-jeu', s);

  s := fx7.start('nd-action-verite');
  update public.session_rounds set card = card || '{{"active": 1, "first": 1}}' where session_id = s and round_no = 1;
  insert into fx_out (line) select fx7.out('conv-av-choix', s);
  perform fx7.seat_mv(s, 1, 'choose_kind', '{{"kind": "truth"}}');
  insert into fx_out (line) select fx7.out('conv-av-verite', s);

  s := fx7.start('nd-deux-verites-mensonge');
  update public.session_rounds set card = card || '{{"author": 1, "guesser": 2, "first": 1}}' where session_id = s and round_no = 1;
  insert into fx_out (line) select fx7.out('conv-dvm-ecriture', s);
  perform fx7.seat_mv(s, 1, 'publish_three', '{{"confirmed_truths": true, "lie_statement_id": "s2", "statements": [{{"id": "s1", "text": "J''ai déjà vu une baleine depuis un bateau."}}, {{"id": "s2", "text": "Je parle couramment japonais."}}, {{"id": "s3", "text": "J''ai appris à nager à 25 ans."}}]}}');
  perform fx7.seat_mv(s, 2, 'lock_guess', '{{"statement_id": "s3"}}');
  insert into fx_out (line) select fx7.out('conv-dvm-revelation', s);


  -- Lot 4 : Pendu, Petit bac, Cite trois (échéances relatives, recalées à l'heure du rendu).
  s := fx7.start('N2-023');
  update public.session_rounds set card = card || '{{"giver": 1, "guesser": 2, "first": 1}}' where session_id = s and round_no = 1;
  update private.round_secrets set secret = jsonb_build_object('seats', jsonb_build_object('1', jsonb_build_object('choices',
    (select jsonb_agg(jsonb_build_object('id', value ->> 'id', 'text', value ->> 'text')) from (select value from public.content_banks
       where bank = 'hangman_words' and (value ->> 'difficulty' = 'standard' or value ->> 'text' = 'fenêtre')
       order by value ->> 'text' = 'fenêtre' desc, idx limit 8) x)))) where session_id = s and round_no = 1;
  insert into fx_out (line) select fx7.out('mot-pendu-choix', s);
  perform fx7.seat_mv(s, 1, 'choose_word', jsonb_build_object('word_id', (select value ->> 'id' from public.content_banks where bank = 'hangman_words' and value ->> 'text' = 'fenêtre')));
  perform fx7.seat_mv(s, 2, 'guess_letter', '{{"letter": "E"}}');
  perform fx7.seat_mv(s, 2, 'guess_letter', '{{"letter": "S"}}');
  perform fx7.seat_mv(s, 2, 'guess_letter', '{{"letter": "T"}}');
  perform fx7.seat_mv(s, 2, 'guess_letter', '{{"letter": "A"}}');
  insert into fx_out (line) select fx7.out('mot-pendu-donneur', s);
  update public.session_rounds set card = card || '{{"giver": 2, "guesser": 1}}' where session_id = s and round_no = 1;
  insert into fx_out (line) select fx7.out('mot-pendu-devineur', s);
  update public.session_rounds set card = card || '{{"giver": 1, "guesser": 2}}' where session_id = s and round_no = 1;
  perform fx7.seat_mv(s, 2, 'guess_letter', '{{"letter": "F"}}');
  perform fx7.seat_mv(s, 2, 'guess_letter', '{{"letter": "N"}}');
  perform fx7.seat_mv(s, 2, 'guess_letter', '{{"letter": "R"}}');
  insert into fx_out (line) select fx7.out('mot-pendu-fin', s);

  s := fx7.start('N2-018');
  perform fx7.seat_mv(s, 1, 'round_loaded');
  perform fx7.seat_mv(s, 2, 'round_loaded');
  update public.session_rounds set card = card || '{{"letter": "C"}}' where session_id = s and round_no = 1;
  perform fx7.seat_mv(s, 1, 'save_field', '{{"category_id": "animal", "text": "Chat", "draft_revision": 1}}');
  perform fx7.seat_mv(s, 1, 'save_field', '{{"category_id": "ville", "text": "Copenhague", "draft_revision": 1}}');
  update public.session_rounds set card = card || jsonb_build_object('deadline_at', now() + interval '87 seconds', 'stop_after', now() - interval '1 second') where session_id = s and round_no = 1;
  insert into fx_out (line) select fx7.out('mot-bac-saisie', s);
  perform fx7.seat_mv(s, 2, 'save_field', '{{"category_id": "animal", "text": "chat", "draft_revision": 1}}');
  perform fx7.seat_mv(s, 2, 'save_field', '{{"category_id": "objet", "text": "Cafetière", "draft_revision": 1}}');
  perform fx7.seat_mv(s, 2, 'save_field', '{{"category_id": "pays", "text": "Chili", "draft_revision": 1}}');
  perform fx7.seat_mv(s, 1, 'stop', '{{"drafts": {{"objet": {{"text": "Crayon", "draft_revision": 1}}, "pays": {{"text": "Canada", "draft_revision": 1}}}}}}');
  insert into fx_out (line) select fx7.out('mot-bac-arbitrage', s);
  perform fx7.seat_mv(s, 1, 'confirm_validation');
  perform fx7.seat_mv(s, 2, 'confirm_validation');
  insert into fx_out (line) select fx7.out('mot-bac-resultat', s);

  s := fx7.start('nd-cite-trois');
  insert into fx_out (line) select fx7.out('mot-cite-appel', s);
  perform fx7.seat_mv(s, 1, 'round_loaded', '{{"call": true}}');
  perform fx7.seat_mv(s, 2, 'round_loaded', '{{"call": true}}');
  update public.session_rounds set card = card || jsonb_build_object('starts_at', now() - interval '200 milliseconds', 'deadline_at', now() + interval '7 seconds') where session_id = s and round_no = 1;
  update private.round_secrets set secret = secret || '{{"respondent": 2}}' where session_id = s and round_no = 1;
  perform fx7.seat_mv(s, 1, 'prompt_received');
  perform fx7.seat_mv(s, 2, 'prompt_received');
  insert into fx_out (line) select fx7.out('mot-cite-juge', s);
  perform fx7.seat_mv(s, 1, 'verdict', '{{"success": true}}');
  perform fx7.as_user('{PARTNER}');
  perform public.round_after(s, 1, 'correction_request', '{{}}');
  insert into fx_out (line) select fx7.out('mot-cite-correction', s);

  update public.game_sessions set status = 'abandoned' where status in ('lobby','playing','paused','ended');
  perform fx7.as_user('{ME}');
  s := (public.create_session('N2-002') ->> 'session_id')::uuid;
  insert into fx_out (line) select fx7.out('conv-salon', s);
end $$;
select 'NOW ' || to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.US+00:00');
select line from fx_out order by n;
rollback;
"""

out = subprocess.run(PG, input=SQL, capture_output=True, text=True, check=True).stdout
# Heure de la transaction (now() y est figée) : référence des échéances relatives.
NOW = next((datetime.fromisoformat(l.split(" ", 1)[1]) for l in out.splitlines() if l.startswith("NOW ")), None)
os.makedirs(OUT, exist_ok=True)
index = {}
for line in out.splitlines():
    if not line.startswith("FX "):
        continue
    _, key, payload = line.split(" ", 2)
    state = json.loads(payload)
    gen = state.get("server_now")
    for r in state.get("rounds", []):
        card = r.get("card") or {}
        for k in ("starts_at", "deadline_at", "stop_after", "validation_deadline", "started_at", "frozen_at", "judged_at"):
            if isinstance(card.get(k), str) and NOW:
                card[k] = {"__rel": (datetime.fromisoformat(card[k]) - NOW).total_seconds()}
    with open(os.path.join(OUT, f"c14-{key}.json"), "w", encoding="utf8") as f:
        json.dump(state, f, ensure_ascii=False)
    index[key] = state["session"]["status"]
with open(os.path.join(OUT, "index_c14.json"), "w", encoding="utf8") as f:
    json.dump(index, f, ensure_ascii=False, indent=1)
print(index)
