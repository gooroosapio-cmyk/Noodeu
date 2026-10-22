#!/usr/bin/env python3
"""Fabrique des états de partie RÉELS pour la vérification visuelle des 18 activités de la famille 1.

Les états sont produits par les vraies fonctions de la base locale (migrations du dépôt) : tirage, validation,
révélation. Seuls les comptes sont fictifs (Maya et Alex). Usage : python3 tests/visual/make_fixtures.py
(base locale de test sur /var/tmp/noodeu-pg:54329, voir supabase/tests/README.md).
"""
import json
import os
import subprocess

PG = ["psql", "-h", "/var/tmp/noodeu-pg", "-p", "54329", "-U", "postgres", "-d", "noodeu", "-At", "-v", "ON_ERROR_STOP=1"]
ME = "11111111-1111-4111-8111-111111111111"
PARTNER = "22222222-2222-4222-8222-222222222222"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")
os.makedirs(OUT, exist_ok=True)


def sql(q):
    return subprocess.run(PG + ["-c", q], check=True, capture_output=True, text=True).stdout.strip()


def call(user, fn, *args):
    lit = ", ".join(args)
    q = (f"select set_config('request.jwt.claims', '{{\"sub\":\"{user}\",\"role\":\"authenticated\"}}', false);"
         f" set role authenticated; select public.{fn}({lit});")
    out = subprocess.run(PG + ["-c", q], check=True, capture_output=True, text=True).stdout.strip().split("\n")
    return json.loads(out[-1])


def j(v):
    return "'" + json.dumps(v, ensure_ascii=False).replace("'", "''") + "'::jsonb"


def s(v):
    return "'" + v + "'"


# Comptes et duo
sql(f"""delete from auth.users where id in ('{ME}', '{PARTNER}');
insert into auth.users (id, email, raw_user_meta_data) values
 ('{ME}', 'maya@exemple.invalid', '{{"display_name":"Maya"}}'), ('{PARTNER}', 'alex@exemple.invalid', '{{"display_name":"Alex"}}');
update public.profiles set display_name = 'Maya', word_form = 'f' where id = '{ME}';
update public.profiles set display_name = 'Alex', word_form = 'm' where id = '{PARTNER}';""")
inv = call(ME, "create_invitation")
call(PARTNER, "claim_invitation", s(inv["code"]))
call(ME, "respond_to_claim", s(inv["id"]) + "::uuid", "true")


def sample(kind, step, card, seat, state, round_no):
    prm = step.get("params", {})
    L = lambda k: card.get(k) or []
    if kind == "text":
        return {"text": "Une fois, j'ai raconté que ma voisine avait besoin d'aide pour éviter une soirée." if seat == 1 else "Je dis que je suis déjà en pyjama, ce qui est souvent vrai."}
    if kind == "choice":
        return {"choice": seat % max(len(card.get("choices") or [1]), 1), **({"comment": "Surtout le dimanche."} if prm.get("comment_max") else {})}
    if kind == "yes_no":
        return {"answer": "yes" if seat == 1 else "no"}
    if kind == "pick":
        n = int(prm["max"])
        return {"items": list(range(seat - 1, seat - 1 + n * 2, 2))[:n], **({"note": "C'est ce qui compte le plus cette année."} if prm.get("note_max") else {})}
    if kind == "objects":
        return {"items": [{"i": i, "caption": c} for i, c in zip([seat, seat + 3, seat + 6], ["Pour ouvrir les portes.", "Le matin avant tout.", "Toujours dans le sac."])], "bg": seat}
    if kind == "sky":
        return {"symbols": [0, 2] if seat == 1 else [1], "energy": seat + 1, "note": "Une semaine chargée mais douce."}
    if kind == "frise":
        return {"order": "chrono", "entries": [{"p": i, "title": t, "text": "Une phrase pour s'en souvenir."} for i, t in enumerate(["Le fou rire du train", "Le déménagement", "Le premier gâteau réussi"][:len(L("prompts"))])]}
    if kind == "gesture":
        return {"action": seat, "text": "Bravo pour la présentation de mardi, tu étais très claire.", "drawing": [{"c": 1, "w": 1, "p": [[0.2, 0.5], [0.5, 0.2], [0.8, 0.5], [0.5, 0.8], [0.2, 0.5]]}]}
    if kind == "buy":
        costs = [a["v"]["cost"] for a in L("activities")]
        pick, tot = [], 0
        for i, c in enumerate(costs[seat - 1:], start=seat - 1):
            if len(pick) < 3 and tot + c <= 12:
                pick.append(i); tot += c
        return {"items": pick}
    if kind == "place":
        xs = [0, 1, 2] if seat == 1 else [3, 4, 5]
        return {"objects": [{"i": seat * 3 + k, "x": xs[k], "y": k} for k in range(3)]}
    if kind == "light":
        return {"light": seat, "ambiance": seat}
    if kind == "gift":
        return {"paper": seat, "ribbon": seat, "object": seat + 2, "word": "Pour une pause qui tombe bien.", "drawing": [{"c": 2, "w": 2, "p": [[0.3, 0.3], [0.7, 0.7]]}]}
    if kind == "page":
        return {"text": "Notre plus petite victoire : arriver à l'heure.", "stickers": [{"s": 13, "x": 0.3, "y": 0.3}, {"s": 14, "x": 0.7, "y": 0.6}],
                "drawing": [{"c": 3, "w": 1, "p": [[0.1, 0.9], [0.9, 0.9]]}]}
    if kind == "cover_pick":
        return {"sticker": 13} if seat == 1 else {"text": "En pyjama, mais fiers"}
    if kind == "fields":
        return {"fields": [{"text": "Apprendre une chanson", "shared": True}, {"text": "Ranger le tiroir", "shared": seat == 1}, {"text": "Il fera beau", "shared": True}]}
    if kind == "share":
        return {"topic": 0, "text": "J'ai enfin réparé la lampe du salon. Il m'a fallu trois essais et une vidéo."}
    if kind == "confirm":
        return {"ok": True}
    if kind == "zones":
        return {"places": [{"i": i, "z": i % 3} for i in range(seat - 1, seat + 5)], "detail": {"i": seat - 1, "text": "Surtout le samedi."}}
    return None


playable = sql("select id from public.games where implementation = 'playable' and id like 'N2-%' order by sort").split("\n")
index = {}
for gid in playable:
    sql(f"update public.game_sessions set status = 'abandoned' where status in ('lobby','playing','paused','ended')")
    sess = call(ME, "create_session", s(gid))["session_id"]
    lobby = call(ME, "get_session_state", s(sess) + "::uuid")
    call(ME, "set_ready", s(sess) + "::uuid", "true")
    call(PARTNER, "set_ready", s(sess) + "::uuid", "true")
    play = call(ME, "get_session_state", s(sess) + "::uuid")
    cfg = play["game"]["config"]
    rnd = play["rounds"][0]
    # Réponses des deux, dans l'ordre et selon les rôles (écoute : récit → reformulation → confirmation).
    for _ in range(3):
        for st in cfg["steps"]:
            role_a = rnd["card"].get("role_a", 1)
            seats = {"a": [role_a], "b": [3 - role_a]}.get(st.get("who", "both"), [1, 2])
            for seat in seats:
                user = ME if seat == 1 else PARTNER
                payload = sample(st["kind"], st, rnd["card"], seat, play, 1)
                res = call(user, "submit_answer", s(sess) + "::uuid", "1", s(st["key"]), j(payload), "false")
    after = call(ME, "get_session_state", s(sess) + "::uuid")
    for name, data in (("lobby", lobby), ("play", play), ("reveal", after)):
        with open(os.path.join(OUT, f"{gid}-{name}.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False)
    statuses = [after["session"]["status"], after["rounds"][0]["revealed"]]
    index[gid] = {"title": play["game"]["title"], "status": statuses}
    print(gid, play["game"]["title"], statuses)

with open(os.path.join(OUT, "index.json"), "w", encoding="utf-8") as f:
    json.dump(index, f, ensure_ascii=False, indent=1)

# Catalogue réel (tel que le lit l'application) pour la bibliothèque et les fiches.
cat = sql("""select json_build_object(
  'categories', (select json_agg(json_build_object('id', id, 'title', title, 'promise', promise, 'sort', sort, 'is_demo', is_demo, 'family_no', family_no) order by sort)
                 from public.game_categories where status = 'published'),
  'games', (select json_agg(json_build_object('id', id, 'category_id', category_id, 'mechanic', mechanic, 'title', title, 'promise', promise,
                 'hook', hook, 'style', style, 'duration_min', duration_min, 'duration_max', duration_max, 'content_level', content_level,
                 'current_version', current_version, 'sort', sort, 'is_demo', is_demo, 'implementation', implementation,
                 'adult_available', adult_available, 'mute_ok', mute_ok, 'difficulties', difficulties, 'thumbnail', thumbnail) order by sort)
            from public.games where status = 'published'),
  'rules', (select json_object_agg(game_id, rules) from public.game_versions))""")
with open(os.path.join(OUT, "catalogue.json"), "w", encoding="utf-8") as f:
    f.write(cat)
