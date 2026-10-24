#!/usr/bin/env python3
"""Lot 2 des mini-jeux (kit C03/C04 V1) : règles et configuration des cinq moteurs livrés.

Usage : python3 scripts/import_lot2.py <dossier Noodeu_C03_C04_V1>
Écrit supabase/migrations/20261025000110_minijeux_lot2_catalogue.sql (idempotent : une version seulement si
règles ou configuration changent). Les textes de règles sont ceux du kit ; seules les phrases de confidentialité
sont des libellés d'interface.
"""
import json
import sys
from pathlib import Path

KIT = Path(sys.argv[1])
OUT = Path(__file__).resolve().parent.parent / "supabase/migrations/20261025000110_minijeux_lot2_catalogue.sql"

GAMES = {
    "M01": {"rounds": 12, "settings": {"series_wins": {"label": "Victoires pour gagner la série", "options": [1, 2, 3], "default": 1}},
            "privacy": "Le plateau est visible par vous deux ; le serveur vérifie chaque coup."},
    "M04": {"rounds": 1, "privacy": "Le plateau est visible par vous deux ; le serveur attribue les carrés."},
    "M11": {"rounds": 20, "privacy": "Ton geste reste secret jusqu'à la révélation commune ; un geste isolé n'est jamais montré."},
    "M12": {"rounds": 1, "privacy": "Le dé est lancé par le serveur ; vous voyez tous les deux chaque lancer."},
    "M07": {"rounds": 1, "privacy": "Ta flotte reste secrète : seul le résultat de chaque tir est annoncé, même après la partie."},
}


def q(s: str) -> str:
    return "$n$" + s + "$n$"


versions = []
for code, extra in GAMES.items():
    spec = json.load(open(KIT / f"03_Categorie_4/{code}/specification.json"))
    refs = json.load(open(KIT / f"03_Categorie_4/{code}/references_B.json"))["references"]
    sources = [f"Source de mécanique : {r['title']} — {r['publisher']} ({r['url']})." for r in refs]
    config = {"engine": "board", "mechanic": spec["mechanic"], "rounds": extra["rounds"], "score": "duel",
              "turn": "simultaneous" if spec["mechanic"] == "rps" else "alternate", "code": code,
              "parameters": spec["parameters"], "version": spec["version"]}
    if "settings" in extra:
        config["settings"] = extra["settings"]
    rules = {"objective": spec["summary"], "how_to": spec["rules"],
             "details": [f"Score : {spec['score']}"] + [f"Adaptation Noodeu : {a}" for a in spec.get("adaptations", [])] + sources
                        + ["Règles rédigées par Noodeu (" + spec.get("content_origin", "règles originales") + ")."],
             "privacy": extra["privacy"], "step_texts": {}}
    versions.append({"id": spec["internal_id"], "rules": rules, "config": config})

rows = json.dumps(versions, ensure_ascii=False, sort_keys=True)
ids = ", ".join(q(v["id"]) for v in versions)
OUT.write_text(f"""-- Généré par scripts/import_lot2.py — mini-jeux du lot 2 (M01, M04, M11, M12, M07). Ne pas modifier à la main.
with src as (select * from jsonb_to_recordset({q(rows)}::jsonb) as x(id text, rules jsonb, config jsonb)),
changed as (
  select s.* from src s join public.games g on g.id = s.id
  where not exists (select 1 from public.game_versions v where v.game_id = s.id and v.version = g.current_version
                    and v.rules = s.rules and v.config = s.config)),
ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select c.id, coalesce((select max(version) from public.game_versions where game_id = c.id), 0) + 1, c.rules, c.config, now()
  from changed c returning game_id, version)
update public.games g set current_version = ins.version from ins where g.id = ins.game_id;

update public.games set implementation = 'playable', updated_at = now()
  where id in ({ids}) and implementation <> 'playable' and current_version is not null;

insert into public.catalogue_imports (content_version, report)
values ($n$c14-lot2-1.0.0$n$, jsonb_build_object('partie', 'mini-jeux lot 2', 'jouables', {len(versions)}));
""", encoding="utf8")
print(OUT, len(versions))
