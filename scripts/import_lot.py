#!/usr/bin/env python3
"""Import d'un lot de moteurs (familles 2 à 8) : niveaux côté serveur, versions de règles, activités jouables.

Usage : python3 -I scripts/import_lot.py <dossier Noodeu_Jeux_144 décompressé> <numéro de famille>

Produit supabase/migrations/20261022{famille:02d}0030_famille{famille}_contenus.sql, idempotent :
  - niveaux du kit (data/niveaux) utilisés par la famille, rangés dans content_banks (jamais dans les fichiers publics) ;
  - une nouvelle version de règles seulement si règles ou configuration ont changé ;
  - activités de la famille dotées d'un moteur passées en « jouable ».
"""
import importlib
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
KIT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 2 else None
if not KIT or not os.path.isfile(os.path.join(KIT, "data", "catalogue_144.json")):
    sys.exit("Usage : import_lot.py <dossier Noodeu_Jeux_144> <famille>")
FAMILY = int(sys.argv[2])
VERSION = "2.1.0"
ENGINES = importlib.import_module(f"engines_family{FAMILY}").ENGINES


def load(rel):
    with open(os.path.join(KIT, rel), encoding="utf-8") as f:
        return json.load(f)


def q(value):
    text = value if isinstance(value, str) else json.dumps(value, ensure_ascii=False, sort_keys=True)
    tag = "n"
    while f"${tag}$" in text:
        tag += "x"
    return f"${tag}${text}${tag}$"


def compact(rows):
    return q("[\n" + ",\n".join(json.dumps(r, ensure_ascii=False, separators=(",", ":"), sort_keys=True) for r in rows) + "\n]") + "::jsonb"


def report(section):
    return (f"insert into public.catalogue_imports (content_version, report)\n"
            f"select {q(VERSION)}, jsonb_build_object('partie', {q(f'famille {FAMILY}')}, 'section', {q(section)},\n"
            f"  'ajouts', count(*) filter (where inserted), 'mises_a_jour', count(*) filter (where not inserted)) from up;\n\n")


catalogue = load("data/catalogue_144.json")
games = [g for g in catalogue["games"] if g["family"] == FAMILY and g["engine"] in ENGINES]
missing = sorted({g["engine"] for g in catalogue["games"] if g["family"] == FAMILY} - set(ENGINES))
if missing:
    print("moteurs encore à faire :", ", ".join(missing))

levels = []
for g in games:
    path = g["content_path"]
    if path.startswith("data/niveaux/"):
        bank = os.path.basename(path)[:-5]
        for i, v in enumerate(load(path)):
            levels.append({"bank": bank, "idx": i, "value": v})

versions = [{"id": g["id"], "rules": ENGINES[g["engine"]]["rules"], "config": dict(ENGINES[g["engine"]]["config"], mechanic=g["engine"])}
            for g in games]

sql = (f"-- Import généré par scripts/import_lot.py — famille {FAMILY}, édition {VERSION}. Idempotent ; ne pas modifier à la main.\n\n")
if levels:
    sql += f"""-- Niveaux (avec solutions) : côté serveur uniquement.
with src as (select * from jsonb_to_recordset({compact(levels)}) as x(bank text, idx int, value jsonb)),
up as (
  insert into public.content_banks (bank, idx, value, content_version)
  select bank, idx, value, {q(VERSION)} from src
  on conflict (bank, idx) do update set value = excluded.value, content_version = excluded.content_version, updated_at = now()
  where content_banks.value is distinct from excluded.value or content_banks.content_version is distinct from excluded.content_version
  returning (xmax = 0) as inserted)
""" + report("niveaux")
sql += f"""-- Versions de règles : nouvelle version publiée seulement si règles ou configuration ont changé.
with src as (select * from jsonb_to_recordset({compact(versions)}) as x(id text, rules jsonb, config jsonb)),
changed as (
  select s.* from src s join public.games g on g.id = s.id
  where not exists (select 1 from public.game_versions v where v.game_id = s.id and v.version = g.current_version
                    and v.rules = s.rules and v.config = s.config)),
ins as (
  insert into public.game_versions (game_id, version, rules, config, published_at)
  select c.id, coalesce((select max(version) from public.game_versions where game_id = c.id), 0) + 1, c.rules, c.config, now()
  from changed c returning game_id, version),
up as (update public.games g set current_version = ins.version from ins where g.id = ins.game_id returning true as inserted)
""" + report("versions de règles")
sql += f"""-- Activités dotées d'un moteur : jouables.
with up as (update public.games set implementation = 'playable'
            where id in ({", ".join(q(g["id"]) for g in games)}) and implementation <> 'playable' returning true as inserted)
""" + report("activités jouables")

name = f"20261022{FAMILY:02d}0030_famille{FAMILY}_contenus.sql"
with open(os.path.join(ROOT, "supabase", "migrations", name), "w", encoding="utf-8") as f:
    f.write(sql)
print(name, "—", len(games), "activités,", len(levels), "niveaux")
