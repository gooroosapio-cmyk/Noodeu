#!/usr/bin/env python3
"""Lecture du catalogue éditorial consolidé (PDF du 24/10/2026) et des packs G05, G08, G09, G10.

Usage : python3 scripts/parse_catalogue_final.py CATALOGUE.pdf PACKS.pdf SORTIE.json
Extrait chaque entrée (identifiant stable du catalogue, texte, choix cités, réponses QCM, type, badge +18, source),
les sections, et les grilles d'échelle. Aucun texte n'est réécrit : seules les coupures de ligne du PDF sont recollées.
"""
import json
import re
import subprocess
import sys

cat_pdf, packs_pdf, out = sys.argv[1:4]


def text_of(pdf):
    return subprocess.run(["pdftotext", "-layout", pdf, "-"], capture_output=True, text=True, check=True).stdout


ID = re.compile(r"^(C\d-\d{2}-\d{3}) (.+)$")
TYPE = re.compile(r"^(Libre|QCM|Action|Choix cités \+ commentaire|Oral|Action / oral)[^|]*\|\s*(.+)$")
SECTION = re.compile(r"^(\S.*) \((\d+)\)$")
NOISE = re.compile(r"^(Noodeu •|noodeu\s)")

lines = text_of(cat_pdf).splitlines()
# Le corps commence au chapitre 01 (après le sommaire) et s'arrête aux annexes.
start = next(i for i, l in enumerate(lines) if l.startswith("01 Se découvrir") and "entrées" in lines[i + 1])
end = next(i for i, l in enumerate(lines) if l.startswith("Annexes et traçabilité") and i > start)
body = [l.rstrip() for l in lines[start:end]]

entries, sections, grids = [], [], {}
cur = None
section = None
grid = None
pending_desc = None
for raw in body:
    l = raw.strip()
    if not l or NOISE.match(raw):
        continue
    g = re.match(r"^Grille (\S+) - (.+)$", l)
    if g:
        grid = g.group(1)
        grids[grid] = {"title": g.group(2), "options": []}
        cur = None
        continue
    if grid:
        m = re.match(r"^([A-G])\s{2,}(\d+)(?: - (.+))?$", l)
        if m:
            grids[grid]["options"].append({"value": int(m.group(2)), "label": m.group(3)})
            continue
        if l.startswith("Choix "):
            continue
        grid = None
    m = ID.match(l)
    if m and m.group(2).startswith("·"):
        cur = None  # renvois « Questions communes placées ailleurs » : pas de nouvelle entrée
        continue
    if m:
        cur = {"id": m.group(1), "text": m.group(2), "section": section["title"] if section else None,
               "choices": None, "answers": None, "type": None, "adult": False, "source": None}
        entries.append(cur)
        continue
    if cur is not None and cur["type"] is None:
        t = TYPE.match(l)
        if t:
            head = l.split("|")[0]
            cur["type"] = t.group(1)
            cur["adult"] = "+18" in head
            gm = re.search(r"Grille (\S+)", head)
            cur["grid"] = gm.group(1) if gm else None
            cur["source"] = t.group(2).strip()
            continue
        if l.startswith("Choix cités :"):
            cur["choices"] = l[len("Choix cités :"):].strip()
            cur["_in"] = "choices"
            continue
        if l.startswith("Réponses :"):
            cur["answers"] = l[len("Réponses :"):].strip()
            cur["_in"] = "answers"
            continue
        key = cur.get("_in", "text")
        cur[key] = (cur[key] + " " + l).replace("  ", " ")
        continue
    s = SECTION.match(l)
    if s and not ID.match(l):
        section = {"title": s.group(1), "count": int(s.group(2)), "chapter": None, "intro": ""}
        sections.append(section)
        cur = None
        continue
    if section and cur is None and not l.startswith(("C1-", "C2-", "C3-", "C4-", "C5-")):
        section["intro"] = (section["intro"] + " " + l).strip()

for e in entries:
    e.pop("_in", None)
    e["text"] = re.sub(r"\s+", " ", e["text"]).strip()
    for k in ("choices", "answers"):
        if e[k]:
            e[k] = [re.sub(r"^[A-G]\. ", "", x.strip()) for x in re.split(r" / (?=[A-G]\. )", e[k])]

# Packs G05, G08, G09, G10 (PDF à part) : une puce par entrée.
packs = {}
code = None
for l in text_of(packs_pdf).splitlines():
    l = l.strip()
    m = re.match(r"^(G\d{2}) – (.+)$", l)
    if m:
        code = m.group(1)
        packs[code] = {"title": m.group(2), "items": []}
        continue
    if code and l.startswith("• "):
        packs[code]["items"].append(l[2:].strip())
    elif code and packs[code]["items"] and l and not l.startswith(("Packs G05", "Amorces", "démarrer", "Banques")):
        packs[code]["items"][-1] += " " + l

json.dump({"entries": entries, "sections": sections, "grids": grids, "packs": packs}, open(out, "w"), ensure_ascii=False, indent=1)
print(len(entries), "entrées,", len(sections), "sections,", {k: len(v["items"]) for k, v in packs.items()})
