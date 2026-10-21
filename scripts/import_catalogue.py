#!/usr/bin/env python3
"""Import de l'édition enrichie 2.1.0 (144 activités) dans Noodeu.

Usage : python3 -I scripts/import_catalogue.py <dossier Noodeu_Jeux_144 décompressé>

Produit, sans rien envoyer nulle part :
  - supabase/migrations/20261022000200_catalogue_2_1_0_data.sql : import idempotent, versionné, transactionnel ;
  - public/assets/jeux/{vignettes,elements}/*.svg : images servies par l'application (aucun lien Drive) ;
  - src/game/elements.json : correspondance libellé → image d'élément ;
  - docs/import/rapport_import_2_1_0.json et docs/JEUX_144.md : rapport et tableau des 144 activités.

Les niveaux (data/niveaux) contiennent des solutions : ils seront importés côté serveur avec leurs moteurs,
jamais dans les fichiers publics.
"""
import hashlib
import json
import os
import re
import shutil
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from engines_family1 import ENGINES, feminine  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else None
if not KIT or not os.path.isfile(os.path.join(KIT, "data", "catalogue_144.json")):
    sys.exit("Dossier du kit introuvable (attendu : …/Noodeu_Jeux_144 contenant data/catalogue_144.json)")

FAMILY_SLUGS = {1: "complicite-confidences", 2: "mots-repartie", 3: "dessin-creation", 4: "memoire-observation",
                5: "logique-codes", 6: "plateaux-strategie", 7: "cooperation-missions", 8: "histoires-improvisation"}
SAFE_SVG = re.compile(r"<script|foreignObject|\son[a-z]+\s*=|href\s*=\s*\"(https?:|javascript:)", re.I)

errors, warnings = [], []


def load(rel):
    with open(os.path.join(KIT, rel), encoding="utf-8") as f:
        return json.load(f)


def slug(label):
    s = label.replace("œ", "oe").replace("’", "").replace("'", "")
    s = unicodedata.normalize("NFD", s)
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def q(value):
    """Littéral SQL sûr (dollar-quoting avec une étiquette absente du texte)."""
    text = value if isinstance(value, str) else json.dumps(value, ensure_ascii=False, sort_keys=True)
    tag = "n"
    while f"${tag}$" in text:
        tag += "x"
    return f"${tag}${text}${tag}$"


def jq(value):
    return q(json.dumps(value, ensure_ascii=False, sort_keys=True)) + "::jsonb"


catalogue = load("data/catalogue_144.json")
VERSION = catalogue["version"]
games = catalogue["games"]

# ---------------------------------------------------------------------------
# Contrôles de schéma : identifiants, familles, banques, cartes, ratios, illustrations
# ---------------------------------------------------------------------------
ids = [g["id"] for g in games]
if len(games) != 144 or len(set(ids)) != 144:
    errors.append(f"144 activités uniques attendues, {len(set(ids))} trouvées")
if sorted(ids) != [f"N2-{i:03d}" for i in range(1, 145)]:
    errors.append("identifiants N2-001 à N2-144 incomplets")
for fam in range(1, 9):
    n = sum(1 for g in games if g["family"] == fam)
    if n != 18:
        errors.append(f"famille {fam} : {n} activités au lieu de 18")

REQUIRED = ["id", "family", "name", "engine", "hook", "mode", "content_path", "illustration", "filters"]
rejected = []
for g in games:
    missing = [k for k in REQUIRED if k not in g]
    if missing:
        rejected.append({"id": g.get("id"), "raison": f"champs manquants : {missing}"})
    if g.get("mode") not in ("echange", "duel", "cooperation", "creation"):
        rejected.append({"id": g["id"], "raison": f"mode inconnu {g.get('mode')}"})
    if not os.path.isfile(os.path.join(KIT, g["content_path"])):
        rejected.append({"id": g["id"], "raison": f"banque absente {g['content_path']}"})
    vign = os.path.join(KIT, "svg", "vignettes", f"{g['id']}.svg")
    if not os.path.isfile(vign):
        rejected.append({"id": g["id"], "raison": "vignette absente"})
rejected_ids = {r["id"] for r in rejected}

decks = {}
for g in games:
    if g["bank_type"] != "DECK":
        continue
    cards = load(g["content_path"])
    adult = sum(1 for c in cards if c["adult"])
    if len(cards) != 80 or adult != 32:
        errors.append(f"{g['id']} : {len(cards)} cartes dont {adult} +18 (attendu 80 / 32)")
    if len({c["id"] for c in cards}) != len(cards):
        errors.append(f"{g['id']} : identifiants de cartes en double")
    for c in cards:
        if not c.get("text"):
            errors.append(f"{c['id']} : texte vide")
    decks[g["id"]] = cards

# Banques (hors decks et niveaux) référencées par les activités.
banks = {}
for g in games:
    path = g["content_path"]
    if path.startswith("data/banques/"):
        name = os.path.basename(path)[:-5]
        banks[name] = load(path)
# Banques supplémentaires utilisées par les moteurs de la famille 1.
for cfg in ENGINES.values():
    for lst in cfg["config"].get("draw", {}).get("lists", []):
        if lst["bank"] not in banks:
            banks[lst["bank"]] = load(f"data/banques/{lst['bank']}.json")

# Lexique Portrait : forme masculine du kit + forme féminine pour l'accord choisi dans le profil.
banks["portrait"] = [{"m": w, "f": feminine(w)} for w in banks["portrait"]]

# ---------------------------------------------------------------------------
# Images : vignettes et éléments copiés dans l'application (contrôle de sûreté des SVG)
# ---------------------------------------------------------------------------
pub = os.path.join(ROOT, "public", "assets", "jeux")
for sub in ("vignettes", "elements"):
    os.makedirs(os.path.join(pub, sub), exist_ok=True)
copied = 0
for sub in ("vignettes", "elements"):
    src_dir = os.path.join(KIT, "svg", sub)
    for name in sorted(os.listdir(src_dir)):
        if not name.endswith(".svg"):
            continue
        with open(os.path.join(src_dir, name), encoding="utf-8") as f:
            content = f.read()
        if SAFE_SVG.search(content):
            errors.append(f"SVG refusé (contenu actif) : {sub}/{name}")
            continue
        if 'viewBox="' not in content:
            warnings.append(f"SVG sans viewBox : {sub}/{name}")
        shutil.copyfile(os.path.join(src_dir, name), os.path.join(pub, sub, name))
        copied += 1

element_files = {n[:-4] for n in os.listdir(os.path.join(pub, "elements"))}
element_map = {}
for bank in ("objects", "decor", "stickers", "mood"):
    for label in load(f"data/banques/{bank}.json"):
        s = slug(label)
        if s in element_files:
            element_map[label] = f"/assets/jeux/elements/{s}.svg"
        elif bank != "mood":
            warnings.append(f"élément sans image ({bank}) : {label}")
with open(os.path.join(ROOT, "src", "game", "elements.json"), "w", encoding="utf-8") as f:
    json.dump(element_map, f, ensure_ascii=False, indent=1, sort_keys=True)

# ---------------------------------------------------------------------------
# Configurations des moteurs livrés
# ---------------------------------------------------------------------------
mood = load("data/banques/mood.json")
ENGINES["mood"]["config"]["draw"]["fixed"] = {"symbols": mood[:6], "energies": mood[6:14]}
playable = {g["id"] for g in games if g["engine"] in ENGINES and g["id"] not in rejected_ids}

# ---------------------------------------------------------------------------
# SQL : trois migrations compactes (JSON + jsonb_to_recordset), chacune autonome et idempotente.
# Chaque section est une seule instruction : ni table temporaire, ni suppression (les entrées disparues d'une
# banque sont marquées « retire »).
# ---------------------------------------------------------------------------
def compact(value):
    return q(json.dumps(value, ensure_ascii=False, separators=(",", ":"), sort_keys=True)) + "::jsonb"


def header(part):
    return (f"-- Import généré par scripts/import_catalogue.py — édition {VERSION} ({catalogue['date']}), partie {part}.\n"
            "-- Idempotent : relancer ne crée ni doublon ni nouvelle version si rien n'a changé. Les parties existantes\n"
            "-- gardent leur copie de cartes et leur version de règles. Ne pas modifier à la main.\n\n")


def report(part, section):
    return (f"insert into public.catalogue_imports (content_version, report)\n"
            f"select {q(VERSION)}, jsonb_build_object('partie', {q(part)}, 'section', {q(section)},\n"
            f"  'ajouts', count(*) filter (where inserted), 'mises_a_jour', count(*) filter (where not inserted)) from up;\n\n")


families = [{"id": FAMILY_SLUGS[int(k)], "title": v[0], "promise": v[1], "n": int(k)} for k, v in catalogue["families"].items()]
game_rows = []
for idx, g in enumerate(games):
    if g["id"] in rejected_ids:
        continue
    m = re.match(r"(\d+)\s*à\s*(\d+)", g.get("duration_hint", ""))
    dmin, dmax = (int(m.group(1)), int(m.group(2))) if m else (5, 15)
    game_rows.append({
        "id": g["id"], "cat": FAMILY_SLUGS[g["family"]], "mech": g["engine"], "title": g["name"], "hook": g["hook"],
        "style": g["mode"], "dmin": dmin, "dmax": dmax, "sort": idx + 1,
        "impl": "playable" if g["id"] in playable else "coming_soon", "adult": bool(g.get("adult_available")),
        "diffs": [d for d in g["filters"].get("difficulty", []) if d not in ("libre", "standard")],
        "thumb": f"/assets/jeux/vignettes/{g['id']}.svg",
        "meta": {"inputs": g.get("input", []), "duration_hint": g.get("duration_hint"),
                 "audio_optional": g["filters"].get("audio_optional", False), "level_count": g.get("level_count")},
    })
version_rows = [{"id": g["id"], "rules": ENGINES[g["engine"]]["rules"], "config": dict(ENGINES[g["engine"]]["config"], mechanic=g["engine"])}
                for g in games if g["id"] in playable]


part1 = header("1/3 activités") + f"""with src as (select * from jsonb_to_recordset({compact(families)}) as x(id text, title text, promise text, n int)),
up as (
  insert into public.game_categories (id, title, promise, sort, status, is_demo, family_no)
  select id, title, promise, n, 'published', false, n from src
  on conflict (id) do update set title = excluded.title, promise = excluded.promise, sort = excluded.sort,
    status = excluded.status, family_no = excluded.family_no
  where (game_categories.title, game_categories.promise, game_categories.sort, game_categories.status, game_categories.family_no)
    is distinct from (excluded.title, excluded.promise, excluded.sort, excluded.status, excluded.family_no)
  returning (xmax = 0) as inserted)
""" + report("1/3", "familles") + f"""with src as (select * from jsonb_to_recordset({compact(game_rows)}) as x(id text, cat text, mech text, title text, hook text,
  style text, dmin int, dmax int, sort int, impl text, adult boolean, diffs jsonb, thumb text, meta jsonb)),
up as (
  insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max,
    content_level, sort, status, is_demo, implementation, adult_available, mute_ok, difficulties, thumbnail, content_version, meta)
  select id, cat, mech, title, hook, hook, style, dmin, dmax, 'standard', sort, 'published', false, impl, adult, true,
    array(select jsonb_array_elements_text(diffs)), thumb, {q(VERSION)}, meta from src
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
  returning (xmax = 0) as inserted)
""" + report("1/3", "activités") + f"""-- Versions de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with src as (select * from jsonb_to_recordset({compact(version_rows)}) as x(id text, rules jsonb, config jsonb)),
changed as (
  select s.* from src s join public.games g on g.id = s.id
  where not exists (select 1 from public.game_versions v where v.game_id = s.id and v.version = g.current_version
                    and v.rules = s.rules and v.config = s.config)),
ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select c.id, coalesce((select max(version) from public.game_versions where game_id = c.id), 0) + 1, c.rules, c.config, now()
  from changed c returning game_id, version),
up as (update public.games g set current_version = ins.version from ins where g.id = ins.game_id returning true as inserted)
""" + report("1/3", "versions de règles") + """-- La démo « Portrait en cinq mots » est remplacée par N2-005 (décision 3a) ; ses parties restent dans l'historique.
update public.games set status = 'archived' where id = 'portrait-en-cinq-mots' and status <> 'archived';
update public.game_categories set status = 'archived' where id = 'se-decouvrir' and status <> 'archived';
insert into public.game_favorites (user_id, game_id, created_at)
  select user_id, 'N2-005', created_at from public.game_favorites where game_id = 'portrait-en-cinq-mots'
  on conflict do nothing;
"""

card_rows = []
for gid, cards in decks.items():
    if gid in rejected_ids:
        continue
    for i, c in enumerate(cards):
        card_rows.append({"id": c["id"], "g": gid, "c": {"text": c["text"], "choices": c.get("choices", []), "format": c.get("format")},
                          "a": bool(c["adult"]), "t": c.get("topic_tags", []), "th": c.get("theme") or "", "s": i})
part2 = header("2/3 cartes") + f"""with src as (select * from jsonb_to_recordset({compact(card_rows)}) as x(id text, g text, c jsonb, a boolean, t jsonb, th text, s int)),
up as (
  insert into public.game_cards (id, game_id, kind, content, content_level, adult, topic_tags, theme, sort, status, is_demo, content_version)
  select id, g, 'question', c, case when a then 'intime' else 'standard' end, a, array(select jsonb_array_elements_text(t)), th, s,
    'published', false, {q(VERSION)} from src
  on conflict (id) do update set content = excluded.content, content_level = excluded.content_level, adult = excluded.adult,
    topic_tags = excluded.topic_tags, theme = excluded.theme, sort = excluded.sort, status = 'published',
    content_version = excluded.content_version
  where (game_cards.content, game_cards.adult, game_cards.topic_tags, game_cards.theme, game_cards.sort, game_cards.status)
    is distinct from (excluded.content, excluded.adult, excluded.topic_tags, excluded.theme, excluded.sort, 'published')
  returning (xmax = 0) as inserted)
""" + report("2/3", "cartes")

bank_rows = {name: values for name, values in sorted(banks.items())}
part3 = header("3/3 banques") + f"""with src as (
  select b.key as bank, (e.ordinality - 1)::int as idx, e.value
  from jsonb_each({compact(bank_rows)}) b, jsonb_array_elements(b.value) with ordinality e),
retired as (
  update public.content_banks c set content_version = 'retire', updated_at = now()
  where c.bank in (select distinct bank from src) and c.content_version <> 'retire'
    and not exists (select 1 from src i where i.bank = c.bank and i.idx = c.idx)
  returning 1),
up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select bank, idx, value, {q(VERSION)} from src
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value or content_banks.content_version is distinct from excluded.content_version
  returning (xmax = 0) as inserted)
""" + report("3/3", "banques")


old = os.path.join(ROOT, "supabase", "migrations", "20261022000200_catalogue_2_1_0_data.sql")
if os.path.exists(old):
    os.remove(old)
sql = ""
for name, body in (("20261022000200_catalogue_2_1_0_activites.sql", part1), ("20261022000210_catalogue_2_1_0_cartes.sql", part2),
                   ("20261022000220_catalogue_2_1_0_banques.sql", part3)):
    with open(os.path.join(ROOT, "supabase", "migrations", name), "w", encoding="utf-8") as f:
        f.write(body)
    sql += body

# ---------------------------------------------------------------------------
# Rapport et tableau de suivi des 144 activités
# ---------------------------------------------------------------------------
report = {
    "version": VERSION, "date_kit": catalogue["date"],
    "activites": len(games), "rejetees": rejected, "erreurs_schema": errors, "avertissements": warnings,
    "cartes": {gid: {"total": len(c), "plus18": sum(1 for x in c if x["adult"])} for gid, c in decks.items()},
    "banques": {k: len(v) for k, v in sorted(banks.items())},
    "images_copiees": copied, "jouables": sorted(playable),
    "sql_sha256": hashlib.sha256(sql.encode()).hexdigest(),
}
os.makedirs(os.path.join(ROOT, "docs", "import"), exist_ok=True)
with open(os.path.join(ROOT, "docs", "import", "rapport_import_2_1_0.json"), "w", encoding="utf-8") as f:
    json.dump(report, f, ensure_ascii=False, indent=1)

lines = ["# Suivi des 144 activités (édition 2.1.0)", "",
         "Généré par `scripts/import_catalogue.py`. Colonnes : moteur livré, contenu importé, vignette, confidentialité "
         "(réponses cachées jusqu'à la révélation, vérifiée par tests SQL), reprise après coupure, tests.", "",
         "| ID | Activité | Famille | Mode | Moteur | Import | Visuel | Confidentialité | Reprise | Tests |",
         "|---|---|---|---|---|---|---|---|---|---|"]
for g in games:
    ok = g["id"] in playable
    lines.append(f"| {g['id']} | {g['name']} | {g['family']} | {g['mode']} | {'livré' if ok else 'à faire (« Bientôt »)'} | "
                 f"{'oui' if g['id'] not in rejected_ids else 'rejeté'} | oui | {'oui' if ok else '—'} | {'oui' if ok else '—'} | "
                 f"{'SQL' if ok else '—'} |")
with open(os.path.join(ROOT, "docs", "JEUX_144.md"), "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")

print(json.dumps({k: report[k] for k in ("activites", "images_copiees", "jouables")}, ensure_ascii=False))
print("rejetées:", len(rejected), "erreurs:", len(errors), "avertissements:", len(warnings))
for e in errors + [r["raison"] for r in rejected]:
    print(" !", e)
for w in warnings:
    print(" ~", w)
sys.exit(1 if errors else 0)
