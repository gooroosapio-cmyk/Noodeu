#!/usr/bin/env python3
"""Import du catalogue éditorial final (24/10/2026) et des packs G05, G08, G09, G10 : écrasement des anciennes questions.

Usage : python3 scripts/import_catalogue_final.py CATALOGUE.json SORTIE.sql
  CATALOGUE.json : sortie de scripts/parse_catalogue_final.py.
Lit la configuration actuelle des activités dans la base locale (nd2 ou NOODEU_DB) pour n'en changer que ce qui est
nécessaire (nombre d'items, grilles), puis écrit une migration :
  - banques remplacées (anciens items supprimés), identifiants stables du catalogue (C1-01-001…) ;
  - nouvelles banques et nouveaux packs (séries, compléments, conversations libres, À huis clos) ;
  - questionnaires sur les grilles du catalogue, positions conservées pour le calcul ; test de pureté sans score ;
  - deux questionnaires aléatoires (Se découvrir, À huis clos) ;
  - rubriques : « Mieux se comprendre » rejoint « Se découvrir » ; cinq grands traits retiré.
Aucun texte n'est réécrit. Les entrées G05/G08/G09/G10, sans badge dans leur PDF, sont classées +18 par une liste
explicite (un doute = +18 et « à relire »).
"""
import json
import os
import subprocess
import sys

src, out = sys.argv[1:3]
DB = os.environ.get("NOODEU_DB", "nd2")
PG = ["psql", "-h", "/var/tmp/noodeu-pg", "-p", "54329", "-U", "postgres", "-d", DB, "-At", "-v", "ON_ERROR_STOP=1"]
CV = "final-2026-10-24"

d = json.load(open(src))
E = {e["id"]: e for e in d["entries"]}
SEC = {}
for e in d["entries"]:
    SEC.setdefault(e["section"], []).append(e)
INTRO = {s["title"]: s["intro"] for s in d["sections"]}


def section(prefix):
    return [e for e in d["entries"] if e["id"].startswith(prefix + "-")]


def q(s):
    return "$n$" + s + "$n$"


def current(game_id):
    out_ = subprocess.run(PG + ["-c", f"select jsonb_build_object('config', v.config, 'rules', v.rules) from games g "
                                      f"join game_versions v on v.game_id = g.id and v.version = g.current_version where g.id = '{game_id}'"],
                          capture_output=True, text=True, check=True).stdout.strip()
    return json.loads(out_)


def opts(labels):
    return [{"value": i + 1, "label_fr": l} for i, l in enumerate(labels)]


TF2 = [{"value": 1, "label_fr": "Vrai", "label_source": "True (T)"}, {"value": 0, "label_fr": "Faux", "label_source": "False (F)"}]

# ---------------------------------------------------------------------------
# Banques de packs (questions libres ou Vrai / Faux)
# ---------------------------------------------------------------------------
banks = {}


def pack_items(entries, theme=None, aron=False):
    rows = []
    for i, e in enumerate(entries, 1):
        tf = e["answers"] == ["Vrai", "Faux"]
        it = {"id": e["id"], "kind": "statement" if tf else "question", "text_fr": e["text"],
              "response_type": "true_false" if tf else "open", "source_position": i, "adult": e["adult"],
              "theme": theme or e["section"], "source": e["source"]}
        if tf:
            it["scale_id"] = "TF2"
            it["options_ordered"] = TF2
        elif e["choices"]:
            it["options_ordered"] = opts(e["choices"])
        if aron:
            it["section"] = (i - 1) // 12 + 1
        rows.append(it)
    return rows


banks["q_aron"] = pack_items(section("C1-01"), "36 questions pour se rapprocher", aron=True)
banks["q_gottman_rituals"] = pack_items(section("C1-02"), "Nos petits rituels")
banks["q_gottman_roles"] = pack_items(section("C1-03"), "Notre place dans le couple")
banks["q_gottman_goals"] = pack_items(section("C1-04"), "Nos projets communs")
banks["q_gottman_values"] = pack_items(section("C1-05"), "Ce qui compte pour nous")
banks["q_gottman_open"] = pack_items(section("C1-06"), "Conversations à prendre le temps d'avoir")
banks["q_usu_roadtrip"] = pack_items(section("C1-07"), "Se retrouver")
series = []
for k in range(8, 15):
    series += [dict(e) for e in section(f"C1-{k:02d}")]
banks["q_series"] = pack_items(series)
banks["q_complicite"] = pack_items(section("C1-15") + section("C3-06"), "Découverte et complicité")
banks["q_recul"] = pack_items(section("C1-16"), "Recul et quotidien")
banks["q_emotions"] = pack_items(section("C2-07"), "Émotions, sécurité et intimité")
banks["q_reconfort"] = pack_items(section("C2-08"), "Réconfort, confiance et vie à deux")
HC = [("C5-01", "q_hc_envies", "ND-Q-H01", "Mes envies et mes limites"),
      ("C5-02", "q_hc_parler", "ND-Q-H02", "Parler de sexualité à deux"),
      ("C5-03", "q_hc_corps", "ND-Q-H03", "Comprendre mon corps et mes réactions"),
      ("C5-04", "q_hc_protection", "ND-Q-H04", "Protection et décisions partagées"),
      ("C5-05", "q_hc_plaisir", "ND-Q-H05", "Plaisir : idées reçues et connaissances"),
      ("C5-06", "q_hc_envies_plus", "ND-Q-H06", "Envies et limites : questions complémentaires"),
      ("C5-07", "q_hc_intimite_plus", "ND-Q-H07", "Intimité et communication : questions complémentaires")]
for pre, bank, _, title in HC:
    banks[bank] = pack_items(section(pre), title)
banks["q_hc_complements"] = pack_items(section("C3-07") + section("C3-08") + section("C3-09"))

# ---------------------------------------------------------------------------
# Questionnaires : grilles du catalogue, positions conservées
# ---------------------------------------------------------------------------
GRID_SCALE = {"ECR7": "ECR7", "AAIRS6": "AAIRS6", "QSI6": "QSI6", "SPN6": "SPN6",
              "CSI-H": "CSI_HAPPY7", "CSI-V": "CSI_TRUE6", "CSI-D": "CSI_DEGREE6", "ON": "OUI_NON"}
TESTS = {"ND-Q-011": ("C2-01", "q_rice"), "ND-Q-021": ("C2-02", "q_ecrrs"), "ND-Q-022": ("C2-03", "q_csi"),
         "ND-Q-024": ("C2-04", "q_aairs"), "ND-Q-025": ("C2-05", "q_qsi"), "ND-Q-027": ("C2-06", "q_spn")}


def label(s):
    # « 3 - Heureux·se » → valeur 3, libellé « Heureux·se » ; « 2 » → libellé « 2 ».
    v, _, l = s.partition(" - ")
    return int(v), (l or v)


test_versions = {}
for gid, (pre, bank) in TESTS.items():
    cur = current(gid)
    cfg, rules = cur["config"], cur["rules"]
    entries = section(pre)
    scales = {}
    rows = []
    # Positions de la clé de cotation : celles des items actuels, dans le même ordre (vérifié texte à texte).
    old = subprocess.run(PG + ["-c", f"select value ->> 'source_position' from public.content_banks where bank = '{bank}' order by idx"],
                         capture_output=True, text=True, check=True).stdout.split()
    positions = [int(x) for x in old] if len(old) == len(entries) else list(range(1, len(entries) + 1))
    for i, e in enumerate(entries, 1):
        sid = GRID_SCALE[e["grid"]]
        if e["answers"]:
            scale = [{"value": label(a)[0], "label_fr": label(a)[1]} for a in e["answers"]] if sid != "OUI_NON" else \
                [{"value": 1, "label_fr": "Oui"}, {"value": 0, "label_fr": "Non"}]
        else:
            g = d["grids"][e["grid"]]["options"]
            scale = [{"value": o["value"], "label_fr": o["label"] or str(o["value"])} for o in g]
        scales[sid] = scale
        rows.append({"id": e["id"], "kind": "adjective_stimulus" if pre == "C2-06" else "statement", "text_fr": e["text"],
                     "scale_id": sid, "response_type": "ordered_scale", "source_position": positions[i - 1], "adult": e["adult"],
                     "source": e["source"]})
    banks[bank] = rows
    t = dict(cfg["test"])
    t["count"] = len(rows)
    t["scales"] = scales
    t["input"] = "scale"
    t["content_version"] = CV
    if gid == "ND-Q-011":
        # Version allégée de 72 items : réponses Oui / Non, aucun score sur 100 (consigne du catalogue).
        t["instrument"] = "PURETE72"
        t["outputs"] = []
        t["axes"] = {}
        t["reserves"] = ["Version allégée et reformulée de 72 items : ce n'est pas le test de pureté original intégral.",
                         "Aucun score n'est calculé : tes réponses restent privées."]
        rules = dict(rules)
        rules["details"] = [INTRO[entries[0]["section"]], "Aucun score, ni diagnostic, ni comparaison.",
                            "Source : catalogue éditorial consolidé Noodeu du 24/10/2026 (D07, D08)."]
        rules["how_to"] = ["Chacun répond seul, à son rythme, par Oui ou Non.", "Tu peux passer une question.",
                           "Aucun score n'est calculé ; tes réponses détaillées restent privées."]
    else:
        known = {r["source_position"] for r in rows}
        assert all(set(o["positions"]) <= known for o in t["outputs"]), gid
    cfg = dict(cfg)
    cfg["test"] = t
    test_versions[gid] = (cfg, rules)

# ---------------------------------------------------------------------------
# Jeux de conversation et mini-jeu
# ---------------------------------------------------------------------------
PK = d["packs"]
# Classement +18 des packs G05/G08/G09/G10 (relu à la main ; « R » = doute, classé +18 et à relire).
G05_ADULT = {13, 17, 18, 19, 22, 24, 25, 26, 27, 29, 30}
G05_REVIEW = {10, 20, 23}
G09_SAFE = {1, 4, 8, 13, 18, 20, 21}
G09_REVIEW = {2, 6, 12, 16, 23, 25, 28, 29}


def conv(eid, text, adult, theme=None, review=False, source=None, **kw):
    it = {"id": eid, "text": text, "adult": adult}
    if theme:
        it["theme"] = theme
    if review:
        it["review"] = True
    if source:
        it["source"] = source
    it.update(kw)
    return it


banks["conv_truth_dare"] = [conv(e["id"], e["text"], e["adult"], source=e["source"], kind="truth") for e in section("C3-01")] + \
                           [conv(e["id"], e["text"], e["adult"], source=e["source"], kind="dare") for e in section("C3-02")]
banks["conv_never"] = [conv(e["id"], e["text"], e["adult"], source=e["source"],
                            options=[{"id": "experienced", "text": "Déjà fait"}, {"id": "never", "text": "Jamais"}]) for e in section("C3-03")]


def dilemma(e):
    a, b = e["answers"]
    t = e["text"]
    i = t.find(a)
    prompt = (t[:i].rstrip() + "…") if i > 0 else "Tu préfères…"
    cap = lambda s: s[:1].upper() + s[1:]
    return conv(e["id"], t, e["adult"], source=e["source"], prompt=prompt,
                options=[{"id": e["id"] + "-A", "text": cap(a)}, {"id": e["id"] + "-B", "text": cap(b.rstrip(" ?"))}])


banks["conv_dilemma"] = [dilemma(e) for e in section("C3-04")]
banks["conv_target"] = [conv(e["id"], e["text"], e["adult"], source=e["source"]) for e in section("C3-05")]
banks["conv_predict"] = [conv(f"PK-G05-{i:03d}", t, i in G05_ADULT or i in G05_REVIEW, review=i in G05_REVIEW,
                              source="Packs G05, G08, G09, G10 (PDF)") for i, t in enumerate(PK["G05"]["items"], 1)]
banks["conv_sentence"] = [conv(f"PK-G09-{i:03d}", t, i not in G09_SAFE, review=i in G09_REVIEW, source="Packs G05, G08, G09, G10 (PDF)",
                               prefix=t.rstrip("…").rstrip()) for i, t in enumerate(PK["G09"]["items"], 1)]
banks["conv_opinion"] = [conv(f"PK-G10-{i:03d}", t, True, source="Packs G05, G08, G09, G10 (PDF)",
                              options=[{"id": "agree", "text": "D’accord"}, {"id": "disagree", "text": "Pas d’accord"}])
                         for i, t in enumerate(PK["G10"]["items"], 1)]
# Deux vérités et un mensonge : les joueurs écrivent leurs affirmations ; ces amorces ne sont que des idées.
banks["conv_two_truths_ideas"] = [conv(f"PK-G08-{i:03d}", t, i not in {14}, source="Packs G05, G08, G09, G10 (PDF)")
                                  for i, t in enumerate(PK["G08"]["items"], 1)]
banks["cite_trois"] = [conv(e["id"], e["text"], e["adult"], source=e["source"]) for e in section("C4-01")]

# ---------------------------------------------------------------------------
# Activités : packs existants mis à jour, nouveaux packs, questionnaires aléatoires
# ---------------------------------------------------------------------------
P_EXIST = {"ND-Q-P01": "q_aron", "ND-Q-P11": "q_gottman_rituals", "ND-Q-P12": "q_gottman_roles", "ND-Q-P13": "q_gottman_goals",
           "ND-Q-P14": "q_gottman_values", "ND-Q-P03": "q_gottman_open", "ND-Q-P15": "q_usu_roadtrip"}
versions = dict(test_versions)
for gid, bank in P_EXIST.items():
    cur = current(gid)
    cfg = dict(cur["config"])
    p = dict(cfg["pack"])
    p["count"] = len(banks[bank])
    p["content_version"] = CV
    cfg["pack"] = p
    cfg["rounds"] = min(50, len(banks[bank]))
    versions[gid] = (cfg, cur["rules"])

base_rules = current("ND-Q-P03")["rules"]
games = []


def new_pack(gid, bank, title, hook, sort, intime, set_size=None, code=None, dmin=10, dmax=30):
    items = banks[bank]
    tf = all(i["response_type"] == "true_false" for i in items)
    cfg = {"bank": bank, "engine": "board", "mechanic": "pack_conversation", "rounds": min(50, len(items)), "score": "none",
           "turn": "simultaneous",
           "pack": {"code": code or gid[-3:], "content_version": CV, "count": len(items), "editorial_release": CV,
                    "instrument": bank.upper(), "response": "true_false" if tf else "open",
                    "scales": {"TF2": TF2} if tf else {}, "set_size": set_size}}
    secs = []
    for i in items:
        s = E[i["id"]]["section"]
        if s not in secs:
            secs.append(s)
    rules = dict(base_rules)
    rules["objective"] = title
    rules["details"] = [INTRO.get(s, "") for s in secs if INTRO.get(s)] + [
        "Aucun score, aucune bonne réponse, aucune compatibilité.",
        "Source : catalogue éditorial consolidé Noodeu du 24/10/2026 (" + ", ".join(secs) + ")."]
    if any(i["adult"] for i in items) and not intime:
        rules["details"].insert(0, "Les cartes +18 ne sont proposées que si vous les avez activées tous les deux, dans Réglages et dans le salon.")
    games.append({"id": gid, "category_id": "nd-se-decouvrir", "mechanic": "pack_conversation", "title": title, "promise": hook,
                  "hook": hook, "style": "echange", "duration_min": dmin, "duration_max": dmax,
                  "content_level": "intime" if intime else "standard", "sort": sort, "implementation": "playable",
                  "adult_available": any(i["adult"] for i in items), "thumbnail": "/assets/c14/categorie-se-decouvrir.webp",
                  "content_version": CV, "meta": {"code": cfg["pack"]["code"], "items": len(items), "duration_is_estimate": True,
                                                   "editorial_release": CV}})
    versions[gid] = (cfg, rules)


new_pack("ND-Q-P20", "q_series", "35 questions en séries de cinq", "Sept petites séries de cinq questions, de la plus légère à la plus intime.", 20, False, set_size=5, code="P20", dmin=5, dmax=15)
new_pack("ND-Q-P21", "q_complicite", "Découverte et complicité", "Des questions pour rire, se découvrir et se rapprocher.", 21, False, code="P21")
new_pack("ND-Q-P22", "q_recul", "Recul et quotidien", "Prendre un peu de recul sur votre vie à deux et votre quotidien.", 22, False, code="P22")
new_pack("ND-Q-P23", "q_emotions", "Émotions, sécurité et intimité", "Parler de ce qui vous rassure, vous touche et vous rapproche.", 23, False, code="P23")
new_pack("ND-Q-P24", "q_reconfort", "Réconfort, confiance et vie à deux", "Ce qui vous fait du bien, ce qui vous rassure et ce qui compte au quotidien.", 24, False, code="P24")
for n, (pre, bank, gid, title) in enumerate(HC):
    new_pack(gid, bank, title, INTRO.get(E[banks[bank][0]["id"]]["section"], title)[:160] or title, 60 + n, True, code=gid[-3:])
new_pack("ND-Q-H08", "q_hc_complements", "Scénarios, personnages et défis absurdes", "Le pire scénario, vos personnages et des défis absurdes, pour rire entre adultes.", 68, True, code="H08", dmin=5, dmax=20)

# Questionnaires aléatoires : questions libres de la rubrique, 5, 10 ou 20, jamais un test standardisé ni le protocole d'Aron.
POOL_DEC = ["q_gottman_open", "q_usu_roadtrip", "q_series", "q_complicite", "q_recul", "q_emotions", "q_reconfort"]
POOL_HC = [b for _, b, _, _ in HC] + ["q_hc_complements"]
for gid, title, pool, intime, sort in [("ND-Q-RND1", "Questionnaire aléatoire", POOL_DEC, False, 0),
                                       ("ND-Q-RND2", "Questionnaire aléatoire À huis clos", POOL_HC, True, 59)]:
    cfg = {"bank": None, "engine": "board", "mechanic": "pack_conversation", "rounds": 20, "score": "none", "turn": "simultaneous",
           "settings": {"questions": {"label": "Nombre de questions", "default": 10, "options": [5, 10, 20]}},
           "pack": {"code": gid[-4:], "content_version": CV, "count": 20, "editorial_release": CV, "instrument": "ALEATOIRE",
                    "response": "open", "scales": {}, "set_size": None, "random": True, "pool": pool}}
    rules = dict(base_rules)
    rules["objective"] = title
    rules["how_to"] = ["Choisissez le nombre de questions dans le salon : 5, 10 ou 20.",
                       "Les questions sont tirées au hasard parmi les questions libres de la rubrique, selon vos réglages d'intensité et de +18.",
                       "Chacun répond en privé, puis choisit de partager, de garder pour soi ou de passer ; rien n'est révélé avant que vous ayez terminé tous les deux."]
    rules["details"] = ["Les questionnaires structurés (36 questions, tests) gardent leur ordre et ne sont jamais mélangés ici.",
                        "Aucun score, aucune bonne réponse, aucune compatibilité."]
    games.append({"id": gid, "category_id": "nd-se-decouvrir", "mechanic": "pack_conversation", "title": title,
                  "promise": "Un questionnaire tiré au hasard, de 5, 10 ou 20 questions.", "hook": "Un questionnaire tiré au hasard, de 5, 10 ou 20 questions.",
                  "style": "echange", "duration_min": 5, "duration_max": 40, "content_level": "intime" if intime else "standard",
                  "sort": sort, "implementation": "playable", "adult_available": True,
                  "thumbnail": "/assets/c14/categorie-se-decouvrir.webp", "content_version": CV,
                  "meta": {"code": gid[-4:], "random": True, "duration_is_estimate": True, "editorial_release": CV}})
    versions[gid] = (cfg, rules)

# Les packs existants qui contiennent désormais des cartes +18 le signalent (accord des deux dans le salon).
ADULT_EXIST = [gid for gid, b in P_EXIST.items() if any(i["adult"] for i in banks[b])]

# ---------------------------------------------------------------------------
# Écriture
# ---------------------------------------------------------------------------
CLASS = {"ND-Q-P20": "soft", "ND-Q-P21": "moyen", "ND-Q-P22": "soft", "ND-Q-P23": "moyen", "ND-Q-P24": "soft", "ND-Q-RND1": "soft",
         "ND-Q-RND2": "hot", "nd-accord-desaccord": "hot", "nd-complete-phrase": "hot"}
CLASS.update({g: "hot" for _, _, g, _ in HC})
CLASS["ND-Q-H08"] = "hot"
GAME_CLASS = ", ".join(
    f"('{g}', '{i}', array[{', '.join(repr(x) for x in (['duo', 'jeu'] if g.startswith('nd-') else ['duo', 'solo']))}], "
    f"'{'rapide' if g.startswith('nd-') else 'discussion'}')" for g, i in CLASS.items())
REPLACED = sorted(banks)
rows = [{"bank": b, "idx": i, "value": v, "cv": CV} for b in REPLACED for i, v in enumerate(banks[b])]
sql = [f"""-- Généré par scripts/import_catalogue_final.py — catalogue éditorial final du 24/10/2026 et packs G05, G08, G09, G10.
-- Écrasement des anciennes questions (décision du 26/10/2026) : chaque banque listée est vidée puis remplie à nouveau.
-- Les parties passées gardent le texte de leurs cartes (copié dans la partie) ; favoris, « Plus tard », avis et cartes du
-- jour qui visaient une question disparue sont effacés ; la progression des packs réécrits repart de zéro.

-- Rubriques : « Mieux se comprendre » rejoint « Se découvrir » ; « Cinq grands traits » retiré (absent du catalogue final).
update public.games set category_id = 'nd-se-decouvrir', updated_at = now() where category_id = 'nd-mieux-se-comprendre';
update public.game_categories set status = 'archived', updated_at = now() where id = 'nd-mieux-se-comprendre';
update public.games set status = 'archived', updated_at = now() where id = 'ND-Q-012';

-- Banques.
delete from public.content_banks where bank in ({", ".join("'" + b + "'" for b in REPLACED)});
insert into public.content_banks (bank, idx, value, content_version)
select x.bank, x.idx, x.value, x.cv from jsonb_to_recordset({q(json.dumps(rows, ensure_ascii=False, separators=(",", ":")))}::jsonb)
  as x(bank text, idx int, value jsonb, cv text);

-- Nouvelles activités.
insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max, content_level,
                          sort, status, is_demo, implementation, adult_available, solo_allowed, mute_ok, difficulties,
                          thumbnail, content_version, meta)
select x.id, x.category_id, x.mechanic, x.title, x.promise, x.hook, x.style, x.duration_min, x.duration_max, x.content_level,
       x.sort, 'published', false, x.implementation, x.adult_available, false, true, '{{}}', x.thumbnail, x.content_version, x.meta
from jsonb_to_recordset({q(json.dumps(games, ensure_ascii=False, separators=(",", ":")))}::jsonb)
  as x(id text, category_id text, mechanic text, title text, promise text, hook text, style text, duration_min int,
       duration_max int, content_level text, sort int, implementation text, adult_available boolean, thumbnail text, content_version text, meta jsonb)
on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
  promise = excluded.promise, hook = excluded.hook, duration_min = excluded.duration_min, duration_max = excluded.duration_max,
  content_level = excluded.content_level, sort = excluded.sort, status = 'published', implementation = excluded.implementation,
  adult_available = excluded.adult_available, content_version = excluded.content_version, meta = excluded.meta, updated_at = now();
update public.games set adult_available = true, updated_at = now() where id in ({", ".join("'" + g + "'" for g in ADULT_EXIST) or "''"});
update public.games set meta = meta || jsonb_build_object('items', x.n), content_version = {q(CV)}, updated_at = now()
from (values {", ".join(f"('{g}', {len(banks[b])})" for g, b in list(P_EXIST.items()) + [(g, TESTS[g][1]) for g in TESTS])}) as x(id, n)
where games.id = x.id;
-- D'accord ou pas et Complète la phrase : banques G10 et G09 presque entièrement +18 → rubrique À huis clos
-- (accord des deux obligatoire dans le salon).
update public.games set content_level = 'intime', adult_available = true, updated_at = now()
  where id in ('nd-accord-desaccord', 'nd-complete-phrase');
-- Classement des activités nouvelles ou déplacées (intensité, formats, durée).
update public.games g set intensity = x.i, formats = x.f, duration_kind = x.d, updated_at = now()
from (values {GAME_CLASS}) as x(id, i, f, d) where g.id = x.id;
-- Cite trois : seules les 24 consignes du catalogue restent.
update public.games set meta = meta || '{{"items": {len(banks["cite_trois"])}}}', updated_at = now() where id = 'nd-cite-trois';

-- Versions de règles : une nouvelle version seulement si règles ou configuration changent.
with src as (select * from jsonb_to_recordset({q(json.dumps([{"id": g, "config": c, "rules": r} for g, (c, r) in versions.items()], ensure_ascii=False, separators=(",", ":")))}::jsonb)
  as x(id text, config jsonb, rules jsonb)),
changed as (
  select s.* from src s join public.games g on g.id = s.id
  where not exists (select 1 from public.game_versions v where v.game_id = s.id and v.version = g.current_version
                    and v.rules = s.rules and v.config = s.config)),
ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select c.id, coalesce((select max(version) from public.game_versions where game_id = c.id), 0) + 1, c.rules, c.config, now()
  from changed c returning game_id, version)
update public.games g set current_version = ins.version from ins where g.id = ins.game_id;

-- Données personnelles qui visaient une question disparue, et progression des packs réécrits.
delete from public.later_items l where not exists (select 1 from public.content_banks cb where cb.bank = l.bank and cb.value ->> 'id' = l.item_id);
delete from public.item_favorites f where f.kind = 'question'
  and not exists (select 1 from public.content_banks cb where cb.bank = f.bank and cb.value ->> 'id' = f.item_id);
delete from public.item_feedback f where not exists (select 1 from public.content_banks cb where cb.bank = f.bank and cb.value ->> 'id' = f.item_id);
delete from public.daily_cards dc where not exists (select 1 from public.content_banks cb where cb.bank = dc.bank and cb.value ->> 'id' = dc.item_id);
delete from public.content_meta m where not exists (select 1 from public.content_banks cb where cb.bank = m.bank and cb.value ->> 'id' = m.item_id);
delete from private.pack_progress where game_id in ({", ".join("'" + g + "'" for g in P_EXIST)});

insert into public.catalogue_imports (content_version, report)
values ({q(CV)}, {q(json.dumps({"partie": "catalogue final", "banques": {b: len(v) for b, v in banks.items()},
                               "nouvelles_activites": [g["id"] for g in games]}, ensure_ascii=False))}::jsonb);
"""]
open(out, "w").write("\n".join(sql))
print("banques :", {b: len(v) for b, v in banks.items()})
print("activités nouvelles :", [g["id"] for g in games], "| versions :", len(versions), "| +18 dans packs existants :", ADULT_EXIST)
