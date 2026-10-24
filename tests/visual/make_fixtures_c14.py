#!/usr/bin/env python3
"""États RÉELS des packs (C01) et questionnaires (C02) pour la vérification visuelle.

Produits par les vraies fonctions d'une base locale où toutes les migrations sont appliquées
(base « nd2 » par défaut, ou NOODEU_DB). Maya (vue de l'écran) et Alex jouent ; tout est annulé à la fin.
"""
import json
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
end $$;
select line from fx_out order by n;
rollback;
"""

out = subprocess.run(PG, input=SQL, capture_output=True, text=True, check=True).stdout
os.makedirs(OUT, exist_ok=True)
index = {}
for line in out.splitlines():
    if not line.startswith("FX "):
        continue
    _, key, payload = line.split(" ", 2)
    state = json.loads(payload)
    with open(os.path.join(OUT, f"c14-{key}.json"), "w", encoding="utf8") as f:
        json.dump(state, f, ensure_ascii=False)
    index[key] = state["session"]["status"]
with open(os.path.join(OUT, "index_c14.json"), "w", encoding="utf8") as f:
    json.dump(index, f, ensure_ascii=False, indent=1)
print(index)
