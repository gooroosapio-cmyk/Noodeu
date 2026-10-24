#!/usr/bin/env python3
"""Lot 3 : les huit jeux de conversation (kit C03/C04 V1, catégorie 3).

Usage : python3 scripts/import_lot3.py <dossier Noodeu_C03_C04_V1 contenant 02_Categorie_3>
Écrit supabase/migrations/20261025000210_conversation_catalogue.sql : banques (côté serveur uniquement),
versions de règles (une nouvelle version seulement si règles ou configuration changent) et passage en jouable.
Les cartes sont celles des banques du kit, sans modification ; les consignes affichées reformulent fidèlement
les règles du kit en se limitant à ce que le moteur applique.
"""
import json
import sys
from pathlib import Path

KIT = Path(sys.argv[1])
OUT = Path(__file__).resolve().parent.parent / "supabase/migrations/20261025000210_conversation_catalogue.sql"

PRIVATE = "Ta réponse reste secrète jusqu'à ce que vous ayez répondu tous les deux. Passer clôt la carte sans rien révéler."
ADULT = "Cartes +18 désactivées par défaut : elles n'apparaissent que si vous les activez tous les deux. Retirer ton accord est immédiat."

GAMES = {
    "G02": {"bank": "conv_never", "cards": "Nombre de cartes",
            "how_to": ["Une affirmation s'affiche pour vous deux.",
                       "Chacun répond en secret « Déjà fait » ou « Jamais », puis verrouille sa réponse.",
                       "Les deux réponses apparaissent ensemble ; racontez si vous en avez envie, sans obligation.",
                       "Passer clôt la carte sans pénalité et sans rien révéler. Continuez quand vous êtes prêts tous les deux."],
            "privacy": PRIVATE},
    "G03": {"bank": "conv_dilemma", "cards": "Nombre de cartes",
            "how_to": ["Deux propositions s'affichent ; chacun choisit en secret celle qu'il préfère et verrouille.",
                       "Les deux choix apparaissent ensemble. Aucune préférence n'est vraie ou fausse.",
                       "Passer ne vaut aucune des deux options et ne révèle rien. Continuez quand vous êtes prêts tous les deux."],
            "privacy": PRIVATE},
    "G04": {"bank": "conv_target", "cards": "Nombre de cartes",
            "how_to": ["Une question s'affiche : « Qui de nous deux… ? ».",
                       "Chacun désigne en secret l'un de vous deux, y compris lui-même, puis verrouille.",
                       "Les deux votes apparaissent ensemble. Un désaccord n'est ni une erreur ni un échec.",
                       "Passer clôt la carte sans rien révéler. Continuez quand vous êtes prêts tous les deux."],
            "privacy": PRIVATE},
    "G05": {"bank": "conv_predict", "cards": "Nombre de manches",
            "how_to": ["À chaque manche, l'un de vous est le sujet, l'autre devine ; les rôles alternent, le premier sujet est tiré au sort.",
                       "Le sujet répond pour lui ; l'autre écrit la réponse qu'il imagine. Chacun verrouille son texte.",
                       "Les deux textes apparaissent ensemble. Seul le sujet décide : « Ça correspond » rapporte 1 point à celui qui devine.",
                       "« Je ne sais pas », « Aucun » ou « Jamais » sont des réponses possibles ; passer ne rapporte rien."],
            "privacy": PRIVATE},
    "G09": {"bank": "conv_sentence", "cards": "Nombre de cartes",
            "how_to": ["Une même amorce s'affiche pour vous deux.",
                       "Chacun la complète librement, en secret (1000 caractères au plus), puis verrouille.",
                       "Les deux phrases apparaissent ensemble. Pas de bonne réponse ni de classement.",
                       "Passer clôt la carte sans rien révéler. Continuez quand vous êtes prêts tous les deux."],
            "privacy": PRIVATE},
    "G10": {"bank": "conv_opinion", "cards": "Nombre de cartes",
            "how_to": ["Une opinion s'affiche, jamais présentée comme un fait.",
                       "Chacun vote en secret « D'accord » ou « Pas d'accord », puis verrouille.",
                       "Les deux votes apparaissent ensemble ; débattez si vous voulez. Il n'y a pas de perdant.",
                       "Passer clôt la carte sans rien révéler. Continuez quand vous êtes prêts tous les deux."],
            "privacy": PRIVATE},
    "G01": {"bank": "conv_truth_dare", "cards": "Nombre de manches",
            "how_to": ["Le premier joueur est tiré au sort, puis vous alternez à chaque manche.",
                       "À ton tour, choisis Vérité ou Action : la carte n'est tirée qu'après ton choix. Tu peux la changer avant de répondre.",
                       "Vérité : réponds par écrit. Action : réalise-la dans votre appel et marque-la faite, sans preuve ; tu peux partager un mot si tu veux.",
                       "Passer clôt la manche sans pénalité. Aucun score."],
            "privacy": "Tes réponses ne sont visibles qu'une fois envoyées. Aucune preuve n'est jamais demandée."},
    "G08": {"bank": None, "cards": "Nombre de manches",
            "how_to": ["L'auteur est tiré au sort, puis les rôles alternent.",
                       "L'auteur écrit trois affirmations sur lui (240 caractères au plus) et désigne en secret celle qui est fausse.",
                       "L'autre voit les trois affirmations et choisit celle qu'il croit fausse.",
                       "Mensonge trouvé : 1 point à celui qui devine ; sinon 1 point à l'auteur. Une manche passée ne compte pas."],
            "privacy": "L'autre ne voit que tes trois affirmations ; le mensonge reste secret jusqu'à son choix."},
}

banks = []
versions = []
adult_ids = []
for code, g in GAMES.items():
    spec = json.load(open(KIT / f"02_Categorie_3/{code}/specification.json"))
    refs = json.load(open(KIT / f"02_Categorie_3/{code}/references_B.json")).get("references", [])
    bank_json = json.load(open(KIT / f"02_Categorie_3/{code}/banque_A.json"))
    has_adult = False
    if g["bank"]:
        for idx, it in enumerate(bank_json["items"]):
            md = it.get("metadata", {})
            comp = it.get("compatibility", {})
            if "adult_only" not in md or not comp.get("distance") or comp.get("physical_copresence"):
                continue  # métadonnées manquantes ou carte non jouable à distance : exclue
            v = {"id": it["id"], "text": it["text_fr"], "adult": bool(md["adult_only"]), "theme": md.get("theme_label_fr")}
            if code in ("G02", "G03", "G10"):
                v["options"] = [{"id": o["id"], "text": o["text"]} for o in it["options"]]
            if code == "G03":
                v["prompt"] = md.get("prompt_fr")
            if code == "G09":
                v["prefix"] = md.get("completion_slot", {}).get("prefix_fr")
            if code == "G01":
                v["kind"] = md["kind"]
            has_adult = has_adult or v["adult"]
            banks.append({"bank": g["bank"], "idx": idx, "value": v, "cv": bank_json["bank_version"]})
    params = spec["parameters"]
    config = {"engine": "board", "mechanic": spec["mechanic"], "bank": g["bank"], "code": code,
              "rounds": params["default_rounds"], "rounds_setting": "cartes",
              "settings": {"cartes": {"label": g["cards"], "options": params["rounds"], "default": params["default_rounds"]}},
              "score": "duel" if code in ("G05", "G08") else "none", "turn": "alternate" if code in ("G01", "G08") else "simultaneous",
              "version": spec["version"], "bank_version": bank_json.get("bank_version")}
    sources = [f"Référence de mécanique : {r['title']} — {r['publisher']}" + (f" ({r['url']})." if r.get("url") else ".") for r in refs]
    details = [f"Score : {spec['score']}"] + [f"Adaptation Noodeu : {a}" for a in spec.get("adaptations", [])] + sources
    if g["bank"]:
        details.append(f"Cartes originales Noodeu ({bank_json.get('bank_version')}), écrites pour jouer à distance.")
    if has_adult:
        details.append(ADULT)
        adult_ids.append(spec["internal_id"])
    rules = {"objective": spec["summary"], "how_to": g["how_to"], "details": details, "privacy": g["privacy"], "step_texts": {}}
    versions.append({"id": spec["internal_id"], "rules": rules, "config": config})


def q(s: str) -> str:
    return "$n$" + s + "$n$"


ids = ", ".join(q(v["id"]) for v in versions)
OUT.write_text(f"""-- Généré par scripts/import_lot3.py — jeux de conversation (G01 à G10). Ne pas modifier à la main.
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

-- Cartes +18 possibles (désactivées par défaut, accord des deux requis dans le salon).
update public.games set adult_available = (id in ({", ".join(q(i) for i in adult_ids)})), updated_at = now()
  where id in ({ids}) and adult_available is distinct from (id in ({", ".join(q(i) for i in adult_ids)}));
update public.games set implementation = 'playable', updated_at = now()
  where id in ({ids}) and implementation <> 'playable' and current_version is not null;

insert into public.catalogue_imports (content_version, report)
values ($n$c14-lot3-1.0.0$n$, jsonb_build_object('partie', 'jeux de conversation', 'jouables', {len(versions)}, 'cartes', {len(banks)}));
""", encoding="utf8")
print(OUT, len(versions), "jeux,", len(banks), "cartes")
