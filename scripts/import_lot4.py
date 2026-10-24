#!/usr/bin/env python3
"""Lot 4 : Le Pendu (M09), Petit bac (M16), Cite trois en 10 secondes (G07).

Usage : python3 scripts/import_lot4.py <dossier Noodeu_C03_C04_V1 (10_Lexiques, 03_Categorie_4/M09, M16)> <dossier G07 courant>
Écrit supabase/migrations/20261025000310_lot4_catalogue.sql : banques côté serveur (mots relus du Pendu, index du Petit bac,
consignes de Cite trois sans exemples éditoriaux ni notes de jugement), versions de règles et passage en jouable.
Les mots, l'index et les consignes sont ceux du kit, sans modification ; seules les clés de normalisation sont calculées.
"""
import json
import sys
import unicodedata
from pathlib import Path

KIT = Path(sys.argv[1])
G07 = Path(sys.argv[2])
OUT = Path(__file__).resolve().parent.parent / "supabase/migrations/20261025000310_lot4_catalogue.sql"

LEXIQUE = ("Mots issus de Lexique 4.10 (Boris New, Christophe Pallier et contributeurs de Lexique, https://www.lexique.org/) ; "
           "sélection, classement et normalisation : Noodeu. Données dérivées sous licence CC BY-SA 4.0 "
           "(https://creativecommons.org/licenses/by-sa/4.0/).")
WIKIDATA = ("Certaines entrées géographiques proviennent des données structurées de Wikidata (https://www.wikidata.org/), sous CC0 "
            "(https://creativecommons.org/publicdomain/zero/1.0/). L'index de Noodeu est limité et versionné : "
            "un mot absent peut être arbitré par vous deux.")
ADULT = "Consignes +18 désactivées par défaut : elles n'apparaissent que si vous les activez tous les deux. Retirer ton accord est immédiat."


def norm(s: str) -> str:
    s = s.lower().replace("œ", "oe").replace("æ", "ae").replace("’", "'")
    s = "".join(ch for ch in unicodedata.normalize("NFD", s) if unicodedata.category(ch) != "Mn")
    return " ".join(s.split()).upper()


def units_display(text: str):
    units, display = [], []
    for ch in text:
        n = norm(ch)
        for letter in n:
            units.append(letter)
            display.append(ch if len(n) == 1 else letter)
    return units, display


banks = []

# Pendu : seul le lot relu est tirable (les candidats ne sont pas importés).
words = [json.loads(line) for line in open(KIT / "10_Lexiques/pendu_publie.jsonl", encoding="utf8")]
for idx, w in enumerate(words):
    assert w["status"] == "prêt à intégrer"
    units, display = units_display(w["text_fr"])
    assert "".join(units) == w["normalized"], w
    banks.append({"bank": "hangman_words", "idx": idx, "cv": "pendu-lex410-2026-10-24",
                  "value": {"id": w["id"], "text": w["text_fr"], "units": units, "display": display, "difficulty": w["difficulty"]}})

# Petit bac : index local versionné ; une réponse n'est valide que dans sa catégorie.
pb = json.load(open(KIT / "10_Lexiques/petit_bac_index.json", encoding="utf8"))
cats = json.load(open(KIT / "10_Lexiques/petit_bac_categories.json", encoding="utf8"))["categories"]
for idx, it in enumerate(pb["items"]):
    assert it["status"] == "prêt à intégrer"
    aliases = it["normalized_aliases"]
    assert norm(it["text_fr"]) in aliases, it["text_fr"]
    banks.append({"bank": "petit_bac", "idx": idx, "cv": pb["version"],
                  "value": {"id": it["id"], "acc": it["acceptance_id"], "cat": it["category_id"], "text": it["text_fr"], "aliases": aliases}})
letters = sorted(set.intersection(*[{a[0] for b in banks if b["bank"] == "petit_bac" and b["value"]["cat"] == c["category_id"]
                                     for a in b["value"]["aliases"]} for c in cats]))

# Cite trois : métadonnée adulte absente ou carte non jouable à distance = carte exclue ; exemples et notes jamais importés.
g07 = json.load(open(G07 / "banque_A.json", encoding="utf8"))
for idx, it in enumerate(g07["items"]):
    md = it.get("metadata", {})
    comp = it.get("compatibility", {})
    if "adult_only" not in md or not comp.get("distance") or comp.get("physical_copresence"):
        continue
    banks.append({"bank": "cite_trois", "idx": idx, "cv": g07["bank_version"],
                  "value": {"id": it["id"], "text": it["text_fr"], "adult": bool(md["adult_only"]), "theme": md.get("theme_label_fr")}})


def refs(path: Path):
    return [f"Référence de mécanique : {r['title']} — {r['publisher']}" + (f" ({r['url']})." if str(r.get("url", "")).startswith("http") else ".")
            for r in json.load(open(path, encoding="utf8"))["references"]]


m09 = json.load(open(KIT / "03_Categorie_4/M09/specification.json", encoding="utf8"))
m16 = json.load(open(KIT / "03_Categorie_4/M16/specification.json", encoding="utf8"))
g07s = json.load(open(G07 / "specification.json", encoding="utf8"))
pb_rounds = [r for r in m16["parameters"]["rounds"] if r <= len(letters)]

versions = [
    {"id": m09["internal_id"],
     "config": {"engine": "board", "mechanic": "nd_hangman", "bank": "hangman_words", "code": "M09", "rounds": m09["parameters"]["default_rounds"],
                "rounds_setting": "cartes", "score": "duel", "turn": "alternate", "max_errors": m09["parameters"]["errors_max"],
                "settings": {"cartes": {"label": "Nombre de manches", "options": m09["parameters"]["rounds"], "default": m09["parameters"]["default_rounds"]},
                             "difficulte": {"label": "Difficulté des mots", "options": m09["parameters"]["difficulty"],
                                            "default": m09["parameters"]["default_difficulty"]}},
                "version": m09["version"], "bank_version": "pendu-lex410-2026-10-24"},
     "rules": {"objective": m09["summary"],
               "how_to": ["Le premier donneur est tiré au sort ; les rôles s'inversent à chaque manche, avec un nouveau mot.",
                          "Le donneur choisit un mot dans une liste que lui seul voit. L'autre ne voit que le nombre de lettres.",
                          "Le devineur propose une lettre à la fois : elle révèle toutes ses places, sinon la fleur perd un pétale. Une lettre déjà proposée est refusée sans pénalité.",
                          "Accents ignorés pour deviner (E découvre aussi É, È, Ê). Mot trouvé avant le sixième pétale : 1 point au devineur ; sinon aucun point.",
                          "Le mot est révélé à la fin de sa manche et ne revient plus dans la partie. Égalité possible."],
               "details": [f"Score : {m09['score']}"] + [f"Adaptation Noodeu : {a}" for a in m09["adaptations"]]
                          + refs(KIT / "03_Categorie_4/M09/references_B.json") + [LEXIQUE, "Règles rédigées par Noodeu."],
               "privacy": "Seul le donneur voit le mot et sa liste ; le serveur vérifie chaque lettre.", "step_texts": {}}},
    {"id": m16["internal_id"],
     "config": {"engine": "board", "mechanic": "nd_categories_stop", "bank": "petit_bac", "code": "M16", "rounds": pb_rounds[0],
                "rounds_setting": "cartes", "score": "duel", "turn": "simultaneous",
                "categories": [c["category_id"] for c in cats],
                "category_labels": {c["category_id"]: c["text_fr"] for c in cats},
                "timer_seconds": m16["parameters"]["timer_seconds"], "stop_min_elapsed_seconds": m16["parameters"]["stop_min_elapsed_seconds"],
                **({"settings": {"cartes": {"label": "Nombre de manches", "options": pb_rounds, "default": pb_rounds[0]}}} if len(pb_rounds) > 1 else {}),
                "version": m16["version"], "bank_version": pb["version"]},
     "rules": {"objective": m16["summary"],
               "how_to": ["Une lettre commune est tirée par le serveur ; chacun écrit en secret un animal, un objet, une ville et un pays qui commencent par cette lettre.",
                          "Vous avez 120 secondes. « Stop » s'ouvre après 10 secondes, une fois tes quatre cases remplies, et arrête la manche pour vous deux.",
                          "Les réponses sont révélées ensemble. Une réponse présente dans l'index de sa catégorie est valide ; une réponse inconnue est arbitrée par vous deux en 60 secondes : sans accord, elle reste « non tranchée » et vaut 0.",
                          "Par catégorie : même réponse valide, 5 points chacun ; deux réponses valides différentes, 10 chacun ; une seule réponse valide, 15 points.",
                          "Le plus grand total après les manches l'emporte ; égalité possible."],
               "details": [f"Score : {m16['score']}"] + [f"Adaptation Noodeu : {a}" for a in m16["adaptations"]]
                          + [f"Catégorie {c['text_fr']} : {c['metadata']['definition']}" for c in cats]
                          + ["Accents, majuscules, apostrophes et espaces ignorés ; un pluriel n'est accepté que s'il figure dans l'index ; l'article compte pour l'initiale (Le Caire commence par L).",
                             f"Lot de départ : {len(letters)} lettres couvrent les quatre catégories ({', '.join(letters)}) ; d'où {pb_rounds[0]} manches."]
                          + refs(KIT / "03_Categorie_4/M16/references_B.json") + [LEXIQUE, WIKIDATA, "Règles rédigées par Noodeu."],
               "privacy": "Tes réponses restent privées jusqu'au Stop ou à la fin du temps ; seules celles reçues par le serveur sont révélées.",
               "step_texts": {}}},
    {"id": g07s["internal_id"],
     "config": {"engine": "board", "mechanic": "nd_name_three_call", "bank": "cite_trois", "code": "G07",
                "rounds": sum(1 for b in banks if b["bank"] == "cite_trois"), "target": g07s["parameters"]["target_points"],
                "answer_seconds": g07s["parameters"]["answer_seconds"], "success_points": g07s["parameters"]["success_points"],
                "score": "duel", "turn": "random", "version": g07s["version"], "bank_version": g07["bank_version"]},
     "rules": {"objective": g07s["summary"],
               "how_to": ["Lancez un appel entre vous (téléphone ou autre application) : Noodeu n'enregistre rien. Confirmez « Nous sommes en appel » puis prêts.",
                          "À chaque manche, le serveur tire au sort qui répond ; l'autre juge. La même personne peut être tirée plusieurs fois de suite.",
                          "La consigne s'affiche pour vous deux au même instant. Le répondant cite à voix haute trois réponses distinctes en 10 secondes.",
                          "Le juge choisit Réussi (+3) ou Raté (0), pendant le chrono ou juste après, pour ce qui a été dit avant zéro. Rien n'est automatique.",
                          "Avant de continuer, un verdict peut être corrigé si vous êtes d'accord tous les deux. Passer ne pénalise personne. Le premier à 30 points gagne, une fois le bilan confirmé par les deux."],
               "details": [f"Score : {g07s['score']}"] + [f"Adaptation Noodeu : {a}" for a in g07s["adaptations"]]
                          + ["Si l'un de vous n'a pas reçu la consigne dans les 750 ms après le départ, la manche est annulée sans point et une nouvelle consigne est tirée.",
                             "Quitter l'écran pendant les 10 secondes annule la manche sans point.",
                             f"Consignes originales Noodeu ({g07['bank_version']}), écrites pour jouer en appel.", ADULT]
                          + [r for r in refs(G07 / "references_B.json") if "commanditaire" not in r.lower()],
               "privacy": "Aucun enregistrement ni transcription : seul le verdict du juge est conservé.", "step_texts": {}}},
]


def q(s: str) -> str:
    return "$n$" + s + "$n$"


ids = ", ".join(q(v["id"]) for v in versions)
OUT.write_text(f"""-- Généré par scripts/import_lot4.py — Le Pendu, Petit bac, Cite trois en 10 secondes. Ne pas modifier à la main.
-- Banques côté serveur uniquement (content_banks n'est lisible que par les fonctions du moteur).
insert into public.content_banks (bank, idx, value, content_version)
select x.bank, x.idx, x.value, x.cv from jsonb_to_recordset({q(json.dumps(banks, ensure_ascii=False, sort_keys=True))}::jsonb)
  as x(bank text, idx int, value jsonb, cv text)
on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value or content_banks.content_version is distinct from excluded.content_version;

with src as (select * from jsonb_to_recordset({q(json.dumps(versions, ensure_ascii=False, sort_keys=True))}::jsonb) as x(id text, rules jsonb, config jsonb)),
changed as (
  select s.* from src s join public.games g on g.id = s.id
  where not exists (select 1 from public.game_versions v where v.game_id = s.id and v.version = g.current_version
                    and v.rules = s.rules and v.config = s.config)),
ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select c.id, coalesce((select max(version) from public.game_versions where game_id = c.id), 0) + 1, c.rules, c.config, now()
  from changed c returning game_id, version)
update public.games g set current_version = ins.version from ins where g.id = ins.game_id;

-- Consignes +18 possibles pour Cite trois seulement (désactivées par défaut, accord des deux requis dans le salon).
update public.games set adult_available = (id = $n$nd-cite-trois$n$), updated_at = now()
  where id in ({ids}) and adult_available is distinct from (id = $n$nd-cite-trois$n$);
update public.games set implementation = 'playable', updated_at = now()
  where id in ({ids}) and implementation <> 'playable' and current_version is not null;

insert into public.catalogue_imports (content_version, report)
values ($n$c14-lot4-1.0.0$n$, jsonb_build_object('partie', 'lot 4 : pendu, petit bac, cite trois', 'jouables', {len(versions)},
  'mots', {sum(1 for b in banks if b['bank'] == 'hangman_words')}, 'index', {sum(1 for b in banks if b['bank'] == 'petit_bac')},
  'consignes', {sum(1 for b in banks if b['bank'] == 'cite_trois')}));
""", encoding="utf8")
print(OUT, len(versions), "jeux,", len(banks), "entrées ; lettres Petit bac :", letters)
