#!/usr/bin/env python3
"""États RÉELS de la refonte rouge (salon à révision, G01 oral, G08 tour par tour, dé) pour la vérification visuelle.

Produits par les vraies fonctions d'une base locale jetable où toutes les migrations sont appliquées, y compris
20261030001200 (NOODEU_DB, « noodeu_server_audit » par défaut). Maya est la vue de l'écran ; tout est annulé à la fin.
"""
import json
import os
import subprocess

DB = os.environ.get("NOODEU_DB", "noodeu_server_audit")
PG = ["psql", "-h", "/var/tmp/noodeu-pg", "-p", "54329", "-U", "postgres", "-d", DB, "-At", "-v", "ON_ERROR_STOP=1"]
ME = "11111111-1111-4111-8111-111111111111"
PARTNER = "22222222-2222-4222-8222-222222222222"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")
STATEMENTS = ('[{"id": "s1", "text": "J\'\'ai déjà vécu six mois à l\'\'étranger."}, '
              '{"id": "s2", "text": "Je cuisine mieux salé que sucré."}, {"id": "s3", "text": "Je n\'\'ai jamais pris l\'\'avion."}]')

SQL = f"""
begin;
create schema fxr;
create function fxr.as_user(p uuid) returns void language plpgsql as $$
begin perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true); end $$;
create function fxr.seat_mv(s uuid, seat int, typ text, p jsonb default '{{}}') returns jsonb language plpgsql as $$
begin
  perform fxr.as_user((select user_id from public.session_players where session_id = s and session_players.seat = $2));
  return public.play_move(s, (select current_round from public.game_sessions where id = s), gen_random_uuid(), typ, p);
end $$;
create function fxr.out(k text, s uuid) returns text language plpgsql as $$
begin perform fxr.as_user('{ME}'); return 'FX ' || k || ' ' || public.get_session_state(s)::text; end $$;
create function fxr.rev(s uuid) returns int language sql as $$ select settings_rev from public.game_sessions where id = s $$;
create function fxr.lobby(gid text, host uuid) returns uuid language plpgsql as $$
begin
  update public.game_sessions set status = 'abandoned' where status in ('lobby','playing','paused','ended');
  perform fxr.as_user(host);
  return (public.create_session(gid) ->> 'session_id')::uuid;
end $$;
create function fxr.start(gid text) returns uuid language plpgsql as $$
declare s uuid := fxr.lobby(gid, '{ME}');
begin
  perform public.set_ready_rev(s, true, fxr.rev(s));
  perform fxr.as_user('{PARTNER}'); perform public.set_ready_rev(s, true, fxr.rev(s));
  perform fxr.as_user('{ME}'); perform public.launch_session(s, fxr.rev(s));
  return s;
end $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('{ME}', 'maya@exemple.invalid', '{{"display_name":"Maya"}}'),
  ('{PARTNER}', 'alex@exemple.invalid', '{{"display_name":"Alexandra-Marie de Montmorency"}}');
do $$ declare r jsonb; begin
  perform fxr.as_user('{ME}'); r := public.create_invitation();
  perform fxr.as_user('{PARTNER}'); perform public.claim_invitation(r ->> 'code');
  perform fxr.as_user('{ME}'); perform public.respond_to_claim((r ->> 'id')::uuid, true);
end $$;

create temp table fx_out (n serial, line text);
do $$ declare s uuid; begin
  -- Salon : préparer, Maya a validé, les deux ont validé (Maya hôte), puis Alex hôte.
  s := fxr.lobby('nd-deux-verites-mensonge', '{ME}');
  insert into fx_out (line) select fxr.out('salon-preparer', s);
  perform fxr.as_user('{ME}'); perform public.set_ready_rev(s, true, fxr.rev(s));
  insert into fx_out (line) select fxr.out('salon-attente', s);
  perform fxr.as_user('{PARTNER}'); perform public.set_ready_rev(s, true, fxr.rev(s));
  insert into fx_out (line) select fxr.out('salon-pret-hote', s);
  s := fxr.lobby('nd-action-verite', '{PARTNER}');
  perform public.set_ready_rev(s, true, fxr.rev(s));
  perform fxr.as_user('{ME}'); perform public.set_ready_rev(s, true, fxr.rev(s));
  insert into fx_out (line) select fxr.out('salon-pret-invite', s);
  s := fxr.lobby('N2-078', '{ME}');
  insert into fx_out (line) select fxr.out('salon-naval', s);

  -- G01 : choix, observation, vérité, action, c'est répondu.
  s := fxr.start('nd-action-verite');
  update public.session_rounds set card = card || '{{"active": 1, "first": 1}}' where session_id = s and round_no = 1;
  insert into fx_out (line) select fxr.out('g01-choix', s);
  perform fxr.seat_mv(s, 1, 'choose_kind', '{{"kind": "truth"}}');
  insert into fx_out (line) select fxr.out('g01-verite', s);
  perform fxr.seat_mv(s, 1, 'mark_done');
  insert into fx_out (line) select fxr.out('g01-repondu', s);
  s := fxr.start('nd-action-verite');
  update public.session_rounds set card = card || '{{"active": 2, "first": 2}}' where session_id = s and round_no = 1;
  insert into fx_out (line) select fxr.out('g01-observe', s);
  perform fxr.seat_mv(s, 2, 'choose_kind', '{{"kind": "dare"}}');
  insert into fx_out (line) select fxr.out('g01-action-observe', s);
  update public.session_rounds set card = card || '{{"active": 1}}' where session_id = s and round_no = 1;
  insert into fx_out (line) select fxr.out('g01-action', s);

  -- G08 : Maya écrit ; Alex écrit (Maya attend) ; Maya devine ; révélation.
  s := fxr.start('nd-deux-verites-mensonge');
  update public.session_rounds set card = card || '{{"author": 1, "guesser": 2, "first": 1}}' where session_id = s and round_no = 1;
  insert into fx_out (line) select fxr.out('g08-ecriture', s);
  perform fxr.seat_mv(s, 1, 'publish_three', ('{{"confirmed_truths": true, "lie_statement_id": "s2", "statements": {STATEMENTS}}}')::jsonb);
  insert into fx_out (line) select fxr.out('g08-auteur-attend', s);
  perform fxr.seat_mv(s, 2, 'lock_guess', '{{"statement_id": "s3"}}');
  insert into fx_out (line) select fxr.out('g08-revelation', s);
  s := fxr.start('nd-deux-verites-mensonge');
  update public.session_rounds set card = card || '{{"author": 2, "guesser": 1, "first": 2}}' where session_id = s and round_no = 1;
  insert into fx_out (line) select fxr.out('g08-attente', s);
  perform fxr.seat_mv(s, 2, 'publish_three', ('{{"confirmed_truths": true, "lie_statement_id": "s1", "statements": {STATEMENTS}}}')::jsonb);
  insert into fx_out (line) select fxr.out('g08-devine', s);
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
    with open(os.path.join(OUT, f"rouge-{key}.json"), "w", encoding="utf8") as f:
        json.dump(state, f, ensure_ascii=False)
    index[key] = state["session"]["status"]
with open(os.path.join(OUT, "index_rouge.json"), "w", encoding="utf8") as f:
    json.dump(index, f, ensure_ascii=False, indent=1)
print(index)
