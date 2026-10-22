#!/usr/bin/env python3
"""États RÉELS des 18 activités d'une famille du moteur plateau (2 par défaut) pour la vérification visuelle.

Produits par les vraies fonctions de la base locale (tirage, coups validés, secrets) : Maya joue,
Alex est le partenaire automatique de test. À lancer après make_fixtures.py, sur une base fraîche.
Pour chaque activité : début de manche (b0), après un coup de Maya (b1), manche finie (b2), partie finie (b3).
"""
import json
import os
import subprocess
import sys

FAMILY = int(sys.argv[1]) if len(sys.argv) > 1 else 2

PG = ["psql", "-h", "/var/tmp/noodeu-pg", "-p", "54329", "-U", "postgres", "-d", "noodeu", "-At", "-v", "ON_ERROR_STOP=1"]
ME = "11111111-1111-4111-8111-111111111111"
PARTNER = "22222222-2222-4222-8222-222222222222"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")


def sql(q):
    return subprocess.run(PG + ["-c", q], check=True, capture_output=True, text=True).stdout.strip()


def as_me(q):
    out = sql(f"select set_config('request.jwt.claims', '{{\"sub\":\"{ME}\",\"role\":\"authenticated\"}}', false); {q}")
    return out.split("\n")[-1]


# Coup « humain » valide (stratégie du robot ; solution directe pour les jeux libres où le robot attend).
sql("""create schema if not exists fx;
create or replace function fx.solve(m text, c jsonb, sec jsonb, seat int) returns jsonb language plpgsql as $$
declare sol jsonb := sec -> 'solution'; mv jsonb;
begin
  if (c ->> 'done')::boolean then return null; end if;
  case m
  when 'anagram' then return jsonb_build_object('type', 'propose', 'payload', jsonb_build_object('word', sol -> 'accepted' ->> 0));
  when 'syllables' then return jsonb_build_object('type', 'submit', 'payload', jsonb_build_object('order', sol -> 'order'));
  when 'rebus' then return jsonb_build_object('type', 'propose', 'payload', jsonb_build_object('text', sol ->> 'answer'));
  when 'convergence' then
    if c -> 'submitted' ? seat::text then return null; end if;
    return jsonb_build_object('type', 'submit', 'payload', '{"word": "lien"}'::jsonb);
  else
    mv := private.board_bot_any(m, c || jsonb_build_object('last', jsonb_build_object('seat', 3 - seat)), sec, seat);
    if mv is null and m in ('pixel_art', 'emblem', 'flipbook', 'weaving', 'split_memory') and not coalesce(c -> 'validated' ? seat::text, false)
       and (m <> 'emblem' or (c -> 'slots' ? '1' and c -> 'slots' ? '2')) then
      mv := '{"type": "validate"}';
    end if;
    return mv;
  end case;
end $$;
create or replace function fx.step(s uuid) returns boolean language plpgsql as $$
declare g public.game_sessions; c jsonb; mv jsonb; r jsonb;
begin
  select * into g from public.game_sessions where id = s;
  if g.status <> 'playing' then return false; end if;
  select card into c from public.session_rounds where session_id = s and round_no = g.current_round;
  if (c ->> 'done')::boolean then perform public.next_round(s, g.current_round); return true; end if;
  mv := fx.solve(private.version_config(g) ->> 'mechanic', c,
                 (select secret from private.round_secrets where session_id = s and round_no = g.current_round), 1);
  if mv is null then return false; end if;
  r := public.play_move(s, g.current_round, gen_random_uuid(), mv ->> 'type', coalesce(mv -> 'payload', '{}'));
  if r ->> 'error' = 'wait' then perform pg_sleep(1.25); return true; end if;
  return coalesce((r ->> 'ok')::boolean, false);
end $$;""")
sql(f"insert into private.test_autoplayers (user_id) values ('{PARTNER}') on conflict do nothing")

games = sql(f"""select g.id from public.games g join public.game_categories gc on gc.id = g.category_id
               where g.implementation = 'playable' and gc.family_no = {FAMILY} order by g.sort""").split("\n")
index = {}
for gid in games:
    sql("update public.game_sessions set status = 'abandoned' where status in ('lobby','playing','paused','ended')")
    sess = json.loads(as_me(f"select public.create_session('{gid}')"))["session_id"]
    as_me(f"select public.set_ready('{sess}', true)")
    state = lambda: json.loads(as_me(f"select public.get_session_state('{sess}')"))  # noqa: E731
    shots = {"b0": state()}
    as_me(f"select fx.step('{sess}')")
    shots["b1"] = state()
    for _ in range(40):
        st = state()
        if st["rounds"][0]["card"].get("done"):
            break
        as_me(f"select fx.step('{sess}')")
    shots["b2"] = state()
    for _ in range(600):
        if as_me(f"select fx.step('{sess}')") != "t":
            break
    shots["b3"] = state()
    for name, data in shots.items():
        with open(os.path.join(OUT, f"{gid}-{name}.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False)
    index[gid] = {"title": shots["b0"]["game"]["title"], "status": shots["b3"]["session"]["status"]}
    print(gid, index[gid])

sql(f"delete from private.test_autoplayers where user_id = '{PARTNER}'")
with open(os.path.join(OUT, "index_board.json" if FAMILY == 2 else f"index_board{FAMILY}.json"), "w", encoding="utf-8") as f:
    json.dump(index, f, ensure_ascii=False, indent=1)
