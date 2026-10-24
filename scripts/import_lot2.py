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

# Consignes affichées aux joueurs : reformulation fidèle des règles du kit (specification.json « rules »),
# limitée à ce que le moteur applique. Les règles intégrales du kit s'adressent à l'intégrateur.
HOW_TO = {
    "M01": ["Le premier joueur est tiré au sort : il joue X, l'autre O. À chaque nouvelle manche de la série, le premier joueur alterne.",
            "Chacun son tour, pose ton symbole dans une case vide.",
            "Trois symboles alignés (ligne, colonne ou diagonale) gagnent aussitôt, même sur la neuvième case. Plateau plein sans alignement : manche nulle.",
            "Une manche gagnée vaut 1 victoire. La série se joue en 1, 2 ou 3 victoires (réglage du salon), 12 manches au plus ; égalité possible."],
    "M04": ["Le premier joueur est tiré au sort. Chacun son tour, trace un trait entre deux points voisins, à l'horizontale ou à la verticale.",
            "Fermer le quatrième côté d'une case te la donne : 1 point par case, 2 si ton trait en ferme deux.",
            "Tant que tu fermes au moins une case, tu rejoues ; sinon la main passe.",
            "Quand les 16 cases sont fermées, le plus de cases l'emporte ; 8 à 8, c'est une égalité."],
    "M11": ["Chacun choisit en secret pierre, feuille ou ciseaux, puis verrouille son choix : il ne peut plus changer.",
            "Les deux gestes sont révélés ensemble. Pierre bat ciseaux, ciseaux bat feuille, feuille bat pierre ; même geste : égalité, 0 point.",
            "Chaque manche dure 30 secondes. Si un choix manque, la manche est annulée sans montrer le geste de l'autre et sans point.",
            "Le premier à 2 manches gagnées remporte la partie. Après 20 manches, la série s'arrête sur le score du moment."],
    "M12": ["Le premier joueur est tiré au sort. À ton tour, lance le dé autant de fois que tu veux : chaque résultat de 2 à 6 s'ajoute au total du tour.",
            "Un 1 fait perdre le total du tour et passe la main ; les points déjà conservés restent acquis.",
            "S'arrêter ajoute le total du tour à ton score conservé et passe la main.",
            "Le premier qui atteint 100 points conservés en s'arrêtant gagne, sans dernier tour pour l'autre. Le dé est lancé par le serveur."],
    "M07": ["Grille de A à J et de 1 à 10, cinq navires de 5, 4, 3, 3 et 2 cases. Place-les droits, sans chevauchement ; ils peuvent se toucher.",
            "Placement case par case avec le bouton Tourner, ou placement aléatoire ; une fois ta flotte verrouillée, elle ne bouge plus.",
            "Quand les deux flottes sont prêtes, le premier tireur est tiré au sort. Un tir par tour, même après un touché ; une case déjà visée est refusée.",
            "Un touché annonce le type de navire ; un coulé annonce son identité. Le premier à toucher les 17 cases adverses gagne. Les positions restantes ne sont jamais montrées."],
}
# Adaptations du kit qui décrivent des options non livrées (voir docs/DECISIONS.md, lot 2).
SKIP_ADAPTATIONS = {"Premier joueur serveur ; révélation finale sur accord commun."}

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
    rules = {"objective": spec["summary"], "how_to": HOW_TO[code],
             "details": [f"Score : {spec['score']}"]
                        + [f"Adaptation Noodeu : {a}" for a in spec.get("adaptations", []) if a not in SKIP_ADAPTATIONS] + sources
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
