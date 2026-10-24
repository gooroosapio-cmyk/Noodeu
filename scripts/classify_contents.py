#!/usr/bin/env python3
"""Classement des contenus (intensité, +18, durée, formats, saison, autonomie) et liste des cas à relire.

Usage : python3 scripts/classify_contents.py   (lit les banques de la base locale nd2 ou NOODEU_DB)
Écrit :
  - supabase/migrations/20261026000110_content_meta_data.sql : une ligne par question (identifiant de banque inchangé) ;
  - docs/CLASSEMENT_A_RELIRE.md : les cas ambigus, avec la raison.

Méthode : premier classement par règles explicites (drapeau +18 du kit, type de carte, banque, vocabulaire), sans
réécrire aucun texte. Les règles sont volontairement prudentes : un doute devient « à relire », jamais un classement
plus doux. Les tests standardisés (C02) ne sont pas classés question par question : leur ordre et leurs calculs restent
intacts, ils sont classés au niveau de l'activité.
"""
import json
import os
import subprocess
import unicodedata
import zlib
from pathlib import Path

DB = os.environ.get("NOODEU_DB", "nd2")
PG = ["psql", "-h", "/var/tmp/noodeu-pg", "-p", "54329", "-U", "postgres", "-d", DB, "-At", "-v", "ON_ERROR_STOP=1"]
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "supabase/migrations/20261026000110_content_meta_data.sql"
REVIEW = ROOT / "docs/CLASSEMENT_A_RELIRE.md"

BANKS = ["q_aron", "q_gottman_open", "q_usu_roadtrip", "q_gottman_rituals", "q_gottman_roles", "q_gottman_goals",
         "q_gottman_values", "conv_never", "conv_dilemma", "conv_target", "conv_opinion", "conv_sentence", "conv_predict",
         "conv_truth_dare", "cite_trois"]
PACK_THEME = {"q_aron": "36 questions pour se rapprocher", "q_gottman_open": "Conversations à prendre le temps d'avoir",
              "q_usu_roadtrip": "Se retrouver", "q_gottman_rituals": "Nos petits rituels", "q_gottman_roles": "Notre place dans le couple",
              "q_gottman_goals": "Nos projets communs", "q_gottman_values": "Ce qui compte pour nous"}

# Relances de la version approfondie : rédaction Noodeu, identiques pour toutes les questions (jamais une réécriture).
FOLLOWUPS = ["Peux-tu donner un exemple précis ?", "Qu'est-ce que cela dit de ce qui compte pour toi ?",
             "Qu'aimerais-tu que l'autre comprenne de ta réponse ?", "Ta réponse a-t-elle changé avec le temps ?"]


def norm(s: str) -> str:
    s = s.lower().replace("œ", "oe").replace("æ", "ae").replace("’", "'")
    return "".join(ch for ch in unicodedata.normalize("NFD", s) if unicodedata.category(ch) != "Mn")


def has(t: str, words) -> list:
    return [w for w in words if w in t]


SEXUAL = ["sexe", "sexuel", "sexualit", "faire l'amour", "fellation", "cunnilingus", "orgasme", "sex-toy", "masturb", "erotique",
          "intimite sexuelle", "nuit ensemble", "preservatif", "contraception", " ist", "depistage"]
HEALTH = ["depistage", " ist", "contraception", "preservatif", "consentement", "limite", "en parler", "parler de",
          "discussion", "conversation", "garder prive", "vie privee", " proches", " amis"]
DEEP = ["mort", "mourir", "deces", "deuil", "peur", "crain", "blesse", "regret", "honte", "pleur", "trist", "souffr", "colere",
        "conflit", "dispute", "desaccord", "jalou", "trahi", "mensonge", "rupture", "separ", "divorce", "pardon", "defaut",
        "critique", "insecur", "angoiss", "stress", "malad", "depress", "solitude", "seul au monde", "vulnerab", "dette",
        "argent", "enfance", "parents", "confiance", "vexe", "rejet", "attir", "seduire", "drague",
        "embrass", "ex ", "anciens partenaires", "ancienne relation", "votre mere", "ta mere", "ton pere"]
LIGHT = ["drole", "rire", "blague", "ridicule", "absurde", "invente", "imagin", "super-pouvoir", "fou rire", "mauvaise foi"]
SEASONS = {"hiver": ["noel", "fetes de fin", "hiver", "neige", "reveillon", "nouvel an"],
           "ete": ["ete ", "vacances", "plage", "pique-nique", "soleil", "piscine", "mer "],
           "automne": ["rentree", "automne", "feuilles mortes", "halloween"],
           "printemps": ["printemps", "fleurs", "paques"]}

rows, review = [], []


def classify(bank: str, idx: int, v: dict):
    item_id = v["id"]
    text = v.get("text") or v.get("text_fr") or ""
    if v.get("prompt"):
        text = v["prompt"] + " " + " / ".join(o.get("text", "") for o in v.get("options", []))
    t = " " + norm(text) + " "
    adult = bool(v.get("adult", False))
    theme = v.get("theme") or PACK_THEME.get(bank)
    notes = []

    # Durée et formats selon la nature de la carte.
    if bank in ("q_aron", "q_gottman_open", "q_usu_roadtrip"):
        kind, mins, formats = "discussion", (5, 10), ["duo", "solo"]
    elif bank.startswith("q_gottman_"):
        kind, mins, formats = "rapide", (1, 2), ["duo"] + (["rituel"] if bank == "q_gottman_rituals" else [])
    elif bank == "conv_truth_dare":
        kind, mins = "rapide", (1, 2)
        formats = ["duo", "jeu", "defi"] if v.get("kind") == "dare" else ["duo", "jeu"]
    elif bank == "cite_trois":
        kind, mins, formats = "rapide", (1, 1), ["duo", "jeu", "defi"]
    elif bank == "conv_sentence":
        kind, mins, formats = "rapide", (1, 2), ["duo", "jeu", "solo"]
    else:
        kind, mins, formats = "rapide", (1, 2), ["duo", "jeu"]

    # Autonomie (question du jour) : jamais une question d'un parcours ordonné ni une consigne chronométrée.
    standalone = bank in ("q_gottman_open", "q_usu_roadtrip", "conv_never", "conv_dilemma", "conv_target", "conv_opinion",
                          "conv_sentence", "conv_predict") or (bank == "conv_truth_dare" and v.get("kind") == "truth")

    # Intensité.
    sexual = has(t, SEXUAL)
    deep = has(t, DEEP)
    light = has(t, LIGHT)
    if adult:
        intensity = "hot"
        if has(t, HEALTH) and not has(t, ["fellation", "cunnilingus", "orgasme", "faire l'amour", "masturb", "sex-toy", "erotique"]):
            intensity = "moyen"
            notes.append("carte +18 surtout pratique (santé, limites, communication) : classée Moyen, à confirmer")
    elif sexual:
        intensity = "hot"
        notes.append(f"vocabulaire intime ({', '.join(sexual)}) dans une carte non marquée +18 dans le kit")
    elif deep:
        intensity = "moyen"
        if light:
            notes.append(f"ton léger ({', '.join(light)}) mais sujet sensible ({', '.join(deep)}) : Moyen ou Soft ?")
    else:
        intensity = "soft"
    if bank == "q_aron":
        # Protocole d'Aron : intensité croissante par série (1 Soft, 2 et 3 Moyen) ; l'ordre n'est jamais modifié.
        intensity = "soft" if v.get("section") == 1 and not deep else "moyen"

    seasons = [s for s, ws in SEASONS.items() if has(t, ws)]
    if seasons and len(seasons) > 1:
        notes.append(f"plusieurs saisons détectées ({', '.join(seasons)})")

    long_text = None
    if bank in ("q_gottman_open", "q_usu_roadtrip"):
        long_text = FOLLOWUPS[zlib.crc32(item_id.encode()) % len(FOLLOWUPS)]

    rows.append([bank, item_id, intensity, adult, kind, mins[0], mins[1], formats, standalone, bool(notes),
                 "; ".join(notes) or None, seasons, theme, long_text])
    if notes:
        review.append((bank, item_id, text, intensity, adult, "; ".join(notes)))


for bank in BANKS:
    out = subprocess.run(PG + ["-c", f"select idx, value from public.content_banks where bank = '{bank}' order by idx"],
                         capture_output=True, text=True, check=True).stdout
    for line in out.splitlines():
        idx, value = line.split("|", 1)
        classify(bank, int(idx), json.loads(value))


def q(s: str) -> str:
    return "$n$" + s + "$n$"


OUT.write_text(f"""-- Généré par scripts/classify_contents.py — classement des questions. Ne pas modifier à la main :
-- relire docs/CLASSEMENT_A_RELIRE.md, corriger les règles ou ajouter une exception dans le script, puis régénérer.
insert into public.content_meta (bank, item_id, intensity, adult, duration_kind, minutes_min, minutes_max, formats, standalone,
                                 review, review_note, seasons, theme, long_followup, source)
select r ->> 0, r ->> 1, r ->> 2, (r ->> 3)::boolean, r ->> 4, (r ->> 5)::int, (r ->> 6)::int,
       array(select jsonb_array_elements_text(r -> 7)), (r ->> 8)::boolean, (r ->> 9)::boolean, r ->> 10,
       array(select jsonb_array_elements_text(r -> 11)), r ->> 12, r ->> 13, 'regles-v1'
from jsonb_array_elements({q(json.dumps(rows, ensure_ascii=False, separators=(',', ':')))}::jsonb) r
on conflict (bank, item_id) do update set intensity = excluded.intensity, adult = excluded.adult,
  duration_kind = excluded.duration_kind, minutes_min = excluded.minutes_min, minutes_max = excluded.minutes_max,
  formats = excluded.formats, standalone = excluded.standalone, review = excluded.review, review_note = excluded.review_note,
  seasons = excluded.seasons, theme = excluded.theme, long_followup = excluded.long_followup, source = excluded.source,
  updated_at = now()
  where content_meta.source = 'regles-v1';
""", encoding="utf8")

stats = {}
for r in rows:
    stats.setdefault(r[0], {"soft": 0, "moyen": 0, "hot": 0, "relire": 0})
    stats[r[0]][r[2]] += 1
    stats[r[0]]["relire"] += int(r[9])
lines = ["# Classement des contenus : cas à relire", "",
         "Généré par `scripts/classify_contents.py` (classement par règles, sans modification des textes).",
         "Une ligne relue et validée se corrige dans le script (exception par identifiant) puis la migration est régénérée ;",
         "une correction manuelle en base (`source` différent de `regles-v1`) n'est jamais écrasée.", "",
         "| Banque | Soft | Moyen | Hot | À relire |", "|---|---:|---:|---:|---:|"]
for b, s in stats.items():
    lines.append(f"| {b} | {s['soft']} | {s['moyen']} | {s['hot']} | {s['relire']} |")
lines += ["", f"Total : {len(rows)} questions classées, {len(review)} à relire.", "", "| Identifiant | Classement | Raison | Texte |", "|---|---|---|---|"]
for bank, iid, text, inten, adult, why in review:
    lines.append(f"| {iid} | {inten}{' · +18' if adult else ''} | {why} | {text.replace('|', '/')} |")
REVIEW.write_text("\n".join(lines) + "\n", encoding="utf8")
print(len(rows), "questions,", len(review), "à relire")
for b, s in stats.items():
    print(b, s)
