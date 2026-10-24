#!/usr/bin/env python3
"""Import du nouveau catalogue Noodeu : catégories 1 à 4 (cadrage du 24 octobre 2026).

Usage : python3 -I scripts/import_c1c4.py <dossier drive>
  <dossier drive> contient :
    x/Noodeu_C01_Complement_Documentaire_V6/Donnees/Banques_C01_V5_inchangees/*.json  (7 banques C01)
    x/Noodeu_C02_Kit_Documentaire_V5/Edition_documentaire_V5/C02/json/*.json            (7 banques C02)
    x/Noodeu_C02_Kit_Documentaire_V5/Edition_documentaire_V5/common/cotation/*.json     (clés de cotation C02)
    x/kit/Noodeu_C03_C04_V1/                                                            (kit C3/C4)
    files/C01|C02/02_Visuels_categories_et_packs/*.png                                  (visuels des packs)

Produit :
  - supabase/migrations/20261024000030_c1c4_catalogue.sql (idempotent) ;
  - public/assets/c14/*.webp (vignettes des packs et des jeux).
Aucun texte n'est reformulé : les items gardent leur identifiant, leur position source et leur content_version
d'origine (4.0.0 ou 5.0.0, jamais réécrit). Les banques vides du kit C3/C4 ne sont pas remplies.
"""
import json
import os
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
D = Path(sys.argv[1]) if len(sys.argv) > 1 else None
if not D or not (D / "x").is_dir():
    sys.exit("Usage : import_c1c4.py <dossier drive>")
C01 = D / "x/Noodeu_C01_Complement_Documentaire_V6/Donnees/Banques_C01_V5_inchangees"
C02 = D / "x/Noodeu_C02_Kit_Documentaire_V5/Edition_documentaire_V5/C02/json"
COT = D / "x/Noodeu_C02_Kit_Documentaire_V5/Edition_documentaire_V5/common/cotation"
KIT = D / "x/kit/Noodeu_C03_C04_V1"
VIS = D / "files"
THEME = D / "x/Noodeu_Cocon_Pastel_V5_Complet/Noodeu_Cocon_Pastel_V5/02_Assets/Illustrations"
OUT_IMG = ROOT / "public/assets/c14"
RELEASE = "c14-1.0.0"

AXES = {"purete": "Score du test de pureté", "extraversion": "Extraversion", "agreabilite": "Agréabilité",
        "conscience": "Conscienciosité", "stabilite_emotionnelle": "Stabilité émotionnelle",
        "intellect_imagination": "Intellect / imagination", "evitement": "Évitement", "anxiete": "Anxiété",
        "satisfaction_relation": "Satisfaction dans la relation", "attention": "Attention", "distraction": "Distraction",
        "satisfaction": "Satisfaction", "insatisfaction": "Insatisfaction", "positivite": "Positivité",
        "negativite": "Négativité", "total_optionnel": "Total facultatif"}

CATEGORIES = [
    ("nd-se-decouvrir", "Se découvrir", "Des conversations guidées sur vos goûts, souvenirs, valeurs et projets.", 10),
    ("nd-mieux-se-comprendre", "Mieux se comprendre", "Des questionnaires individuels, calculés pour toi, à partager si tu veux.", 20),
    ("nd-conversation-decouverte", "Conversation et découverte", "Huit jeux de conversation pour deux personnes.", 30),
    ("nd-mini-jeux-interactifs", "Mini-jeux interactifs", "Huit jeux de plateau, de mots et en appel.", 40),
]

# Packs C01 : ordre d'affichage, accroche (texte d'interface Noodeu) et durée indicative (estimation).
PACKS = {
    "P01": ("Trois séries de douze questions pour se rapprocher pas à pas.", 15, 45),
    "P03": ("Des questions ouvertes pour les conversations qu'on remet toujours à plus tard.", 10, 30),
    "P15": ("Des questions ouvertes pour se retrouver, à prendre dans l'ordre.", 10, 40),
    "P11": ("Vrai ou faux : les petits rituels qui comptent pour vous.", 5, 15),
    "P12": ("Vrai ou faux : la place de chacun dans le couple.", 5, 10),
    "P13": ("Vrai ou faux : les projets que vous construisez ensemble.", 5, 15),
    "P14": ("Vrai ou faux : ce qui compte vraiment pour vous deux.", 5, 20),
}
TESTS = {
    "011": ("Cent expériences, une case chacune : un indice ludique, sans jugement.", 10, 20, True),
    "012": ("Cinquante affirmations pour décrire tes cinq grands traits.", 8, 15, False),
    "021": ("Neuf affirmations sur ta façon de vivre l'attachement.", 3, 5, False),
    "022": ("Quatre questions sur ta satisfaction dans la relation.", 2, 3, False),
    "024": ("Huit affirmations sur l'attention portée à votre relation.", 2, 4, False),
    "025": ("Douze affirmations sur votre vie sexuelle.", 3, 5, True),
    "027": ("Seize adjectifs pour ton regard sur la sexualité.", 3, 5, True),
}
PRIVACY_C1 = ("Ta réponse reste privée. Tu choisis ensuite de la partager, de la garder pour toi ou de passer ; "
              "rien n'est révélé avant que vous ayez terminé tous les deux, et tu peux retirer un partage.")
PRIVACY_C2 = ("Tes réponses détaillées restent privées. Seul ton résultat peut être partagé, si tu le décides, "
              "et tu peux retirer ce partage.")


def q(value):
    text = value if isinstance(value, str) else json.dumps(value, ensure_ascii=False, sort_keys=True)
    tag = "n"
    while f"${tag}$" in text:
        tag += "x"
    return f"${tag}${text}${tag}$"


def rows(lst):
    return q("[\n" + ",\n".join(json.dumps(r, ensure_ascii=False, separators=(",", ":"), sort_keys=True) for r in lst) + "\n]") + "::jsonb"


def webp(src: Path, name: str, width=640):
    OUT_IMG.mkdir(parents=True, exist_ok=True)
    dest = OUT_IMG / f"{name}.webp"
    im = Image.open(src).convert("RGBA")
    if im.width > width:
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    im.save(dest, "WEBP", quality=80, method=6)
    return f"/assets/c14/{name}.webp"


def bank_name(instrument):
    """Nom de banque autorisé par la contrainte (minuscules et _) : ARON36 → q_aron, GOTTMAN_OPEN30 → q_gottman_open."""
    return "q_" + "".join(c for c in instrument.lower() if c.isalpha() or c == "_").strip("_")


def item_value(it, ambiguous_note):
    """Ce dont le moteur a besoin : texte d'origine, position source, type de réponse, échelle ; les choix ne sont
    recopiés que pour le vrai/faux (les échelles des tests sont dans la configuration de la version)."""
    v = {"id": it["id"], "source_position": it["source_position"], "text_fr": it["text_fr"], "kind": it.get("kind"),
         "response_type": it.get("response_type"), "scale_id": it.get("scale_id"), "section": it.get("set")}
    if it.get("response_type") == "true_false":
        v["options_ordered"] = it.get("options_ordered")
    if it.get("source_ambiguity"):
        v["source_ambiguity"] = True
        v["note"] = ambiguous_note
    return {k: x for k, x in v.items() if x is not None}


banks, games, versions = [], [], []
sort = 0

# ---------------------------------------------------------------- C01
c01 = {json.load(open(f))["id"]: json.load(open(f)) for f in sorted(C01.glob("*.json"))}
cat_img = webp(VIS / "C01/02_Visuels_categories_et_packs/C01_Se_decouvrir.png", "categorie-se-decouvrir", 960)
for code, (promise, dmin, dmax) in PACKS.items():
    b = c01[code]
    sort += 1
    bank = bank_name(b["instrument"])
    for i, it in enumerate(b["items"]):
        banks.append({"bank": bank, "idx": i, "value": item_value(it, ""), "cv": b["content_version"]})
    pic = VIS / f"C01/02_Visuels_categories_et_packs/{code}.png"
    thumb = webp(pic, code) if pic.exists() else cat_img
    tf = b["input_kind"] == "scale"
    games.append({"id": b["game_id"], "category_id": "nd-se-decouvrir", "mechanic": "pack_conversation", "title": b["name_fr"],
                  "promise": promise, "hook": promise, "style": "echange", "duration_min": dmin, "duration_max": dmax,
                  "content_level": "standard", "sort": sort, "thumbnail": thumb, "content_version": b["content_version"],
                  "meta": {"code": code, "instrument": b["instrument"], "items": b["expected_count"], "duration_is_estimate": code != "P01",
                           "rights_status": b.get("rights_status"), "editorial_release": b.get("editorial_release")}})
    source = b["items"][0]["source_ref"]
    versions.append({"id": b["game_id"], "config": {
        "engine": "board", "mechanic": "pack_conversation", "rounds": min(50, b["expected_count"]), "score": "none", "turn": "simultaneous",
        "bank": bank, "pack": {"code": code, "instrument": b["instrument"], "count": b["expected_count"],
                               "response": "true_false" if tf else "open", "set_size": 12 if code == "P01" else None,
                               "scales": b["scales"], "content_version": b["content_version"],
                               "editorial_release": b.get("editorial_release")}},
        "rules": {"objective": b["name_fr"], "how_to": [
            "Vous voyez la même carte, dans l'ordre de la source.",
            "Chacun répond en privé" + (" par Vrai ou Faux, avec un commentaire facultatif." if tf else ", par écrit."),
            "Puis tu choisis : partager, garder pour toi, ou passer. Rien n'est révélé avant que vous ayez terminé tous les deux.",
            "Échangez si vous voulez, puis passez à la carte suivante ; la prochaine séance reprend là où vous vous êtes arrêtés."],
            "details": [b["instruction"], "Repère : " + b["period"], b["translation"] if "translation" in b else "",
                        "Source : " + ", ".join(source.get("authors") or []) + " — " + (source.get("title") or "") + ".",
                        "Aucun score, aucune bonne réponse, aucune compatibilité.",
                        "Phase de test : " + (b.get("rights_status") or "droits commerciaux à confirmer.")],
            "privacy": PRIVACY_C1, "step_texts": {}}})
    versions[-1]["rules"]["details"] = [x for x in versions[-1]["rules"]["details"] if x]

# ---------------------------------------------------------------- C02
c02 = {json.load(open(f))["id"]: json.load(open(f)) for f in sorted(C02.glob("*.json"))}
webp(VIS / "C02/02_Visuels_categories_et_packs/C02_Mieux_se_comprendre.png", "categorie-mieux-se-comprendre", 960)
for code, (promise, dmin, dmax, intimate) in TESTS.items():
    b = c02[code]
    cot = json.load(open(COT / f"{b['instrument']}.json"))
    sort += 1
    bank = bank_name(b["instrument"])
    note = "Item source ambigu : le texte d'origine est « ? ». Il est conservé tel quel ; s'il est passé, l'indice n'est pas calculé."
    for i, it in enumerate(b["items"]):
        banks.append({"bank": bank, "idx": i, "value": item_value(it, note), "cv": b["content_version"]})
    thumb = webp(VIS / f"C02/02_Visuels_categories_et_packs/{code}.png", code)
    reserves = []
    if b["instrument"] == "RICE100":
        reserves.append(note)
    if b["instrument"] == "CSI4":
        reserves.append("Aucun seuil n'est appliqué : le seuil de recherche documenté n'est pas utilisé comme diagnostic.")
    games.append({"id": b["game_id"], "category_id": "nd-mieux-se-comprendre", "mechanic": "test_form", "title": b["name_fr"],
                  "promise": promise, "hook": promise, "style": "echange", "duration_min": dmin, "duration_max": dmax,
                  "content_level": "intime" if intimate else "standard", "sort": sort, "thumbnail": thumb,
                  "content_version": b["content_version"],
                  "meta": {"code": code, "instrument": b["instrument"], "items": b["expected_count"], "duration_is_estimate": True,
                           "rights_status": b.get("rights_status"), "editorial_release": b.get("editorial_release"),
                           "adult_space": intimate}})
    source = b["items"][0]["source_ref"]
    versions.append({"id": b["game_id"], "config": {
        "engine": "board", "mechanic": "test_form", "rounds": 1, "score": "none", "turn": "simultaneous", "bank": bank,
        "test": {"code": code, "instrument": b["instrument"], "count": b["expected_count"], "input": b["input_kind"],
                 "scales": b["scales"], "raw_range": cot["raw_value_range"], "outputs": cot["outputs"],
                 "page_size": 10 if b["input_kind"] == "checkbox" else 5, "axes": {k: AXES[k] for k in AXES
                 if any(o["name"] == k for o in cot["outputs"])}, "reserves": reserves,
                 "content_version": b["content_version"], "editorial_release": b.get("editorial_release")}},
        "rules": {"objective": b["name_fr"], "how_to": [
            "Chacun répond seul, à son rythme, dans l'ordre de la source.",
            "Tu peux passer une question : elle reste sans réponse (jamais comptée comme zéro).",
            "Le calcul est fait sur le serveur quand toutes les réponses sont données ; sinon, pas de résultat.",
            "Tu décides ensuite de partager ton résultat ou de le garder pour toi."],
            "details": [b["instruction"], "Période : " + b["period"],
                        "Source : " + ", ".join(source.get("authors") or []) + " — " + (source.get("title") or "") + ".",
                        "Résultat individuel, par dimension : ni diagnostic, ni comparaison, ni compatibilité.",
                        "Traduction française de travail, non validée.",
                        "Phase de test : " + (b.get("rights_status") or "droits commerciaux à confirmer.")] + reserves,
            "privacy": PRIVACY_C2, "step_texts": {}}})

# ---------------------------------------------------------------- C3/C4 (Bientôt tant que les banques ou moteurs manquent)
props = json.load(open(KIT / "09_Integration/propositions_catalogue.json"))
for p in props:
    sort += 1
    code = p["meta"]["reference_code"]
    ill = KIT / f"06_Assets/{code}/illustration.png"
    games.append({"id": p["id"], "category_id": p["category_id"], "mechanic": p["mechanic"][:40], "title": p["title"],
                  "promise": p["promise"], "hook": p["promise"], "style": p["style"], "duration_min": p["duration_min"],
                  "duration_max": p["duration_max"], "content_level": p["content_level"], "sort": sort,
                  "thumbnail": webp(ill, code, 512) if ill.exists() else None, "content_version": RELEASE,
                  "implementation": "coming_soon", "meta": p["meta"]})

for g in games:
    g.setdefault("implementation", "playable")
    g["adult_available"] = g["content_level"] == "intime"  # accord adulte demandé dans le salon

# ---------------------------------------------------------------- SQL
sql = f"""-- Import généré par scripts/import_c1c4.py — nouveau catalogue (catégories 1 à 4). Idempotent ; ne pas modifier à la main.
-- Les anciennes familles restent en base, archivées. Les items gardent leur content_version d'origine.

-- Catégories : les quatre nouvelles publiées, les anciennes familles archivées (aucune ligne effacée).
update public.game_categories set status = 'archived', updated_at = now()
  where id not in ({", ".join(q(c[0]) for c in CATEGORIES)}) and status <> 'archived';
insert into public.game_categories (id, title, promise, sort, status, is_demo)
select x.id, x.title, x.promise, x.sort, 'published', false
from jsonb_to_recordset({rows([{"id": c[0], "title": c[1], "promise": c[2], "sort": c[3]} for c in CATEGORIES])})
  as x(id text, title text, promise text, sort int)
on conflict (id) do update set title = excluded.title, promise = excluded.promise, sort = excluded.sort,
  status = 'published', updated_at = now();

-- Banques (côté serveur uniquement).
insert into public.content_banks (bank, idx, value, content_version)
select x.bank, x.idx, x.value, x.cv from jsonb_to_recordset({rows(banks)}) as x(bank text, idx int, value jsonb, cv text)
on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value or content_banks.content_version is distinct from excluded.content_version;

-- Activités.
insert into public.games (id, category_id, mechanic, title, promise, hook, style, duration_min, duration_max, content_level,
                          sort, status, is_demo, implementation, adult_available, solo_allowed, mute_ok, difficulties,
                          thumbnail, content_version, meta)
select x.id, x.category_id, x.mechanic, x.title, x.promise, x.hook, x.style, x.duration_min, x.duration_max, x.content_level,
       x.sort, 'published', false, x.implementation, x.adult_available, false, true, '{{}}', x.thumbnail, x.content_version, x.meta
from jsonb_to_recordset({rows(games)})
  as x(id text, category_id text, mechanic text, title text, promise text, hook text, style text, duration_min int,
       duration_max int, content_level text, sort int, implementation text, adult_available boolean, thumbnail text, content_version text, meta jsonb)
on conflict (id) do update set category_id = excluded.category_id, mechanic = excluded.mechanic, title = excluded.title,
  promise = excluded.promise, hook = excluded.hook, style = excluded.style, duration_min = excluded.duration_min,
  duration_max = excluded.duration_max, content_level = excluded.content_level, sort = excluded.sort, status = 'published',
  implementation = excluded.implementation, adult_available = excluded.adult_available, thumbnail = excluded.thumbnail, content_version = excluded.content_version,
  meta = excluded.meta, updated_at = now();

-- Versions de règles : une nouvelle version seulement si règles ou configuration changent.
with src as (select * from jsonb_to_recordset({rows(versions)}) as x(id text, rules jsonb, config jsonb)),
changed as (
  select s.* from src s join public.games g on g.id = s.id
  where not exists (select 1 from public.game_versions v where v.game_id = s.id and v.version = g.current_version
                    and v.rules = s.rules and v.config = s.config)),
ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select c.id, coalesce((select max(version) from public.game_versions where game_id = c.id), 0) + 1, c.rules, c.config, now()
  from changed c returning game_id, version)
update public.games g set current_version = ins.version from ins where g.id = ins.game_id;

insert into public.catalogue_imports (content_version, report)
values ({q(RELEASE)}, jsonb_build_object('partie', 'catégories 1 à 4', 'activites', {len(games)},
        'jouables', {sum(1 for g in games if g['implementation'] == 'playable')}, 'items', {len(banks)}));
"""
name = "20261024000030_c1c4_catalogue.sql"
(ROOT / "supabase/migrations" / name).write_text(sql, encoding="utf-8")
print(name, "—", len(games), "activités dont", sum(1 for g in games if g["implementation"] == "playable"), "jouables,", len(banks), "items")
