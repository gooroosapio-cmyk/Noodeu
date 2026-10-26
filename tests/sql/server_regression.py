#!/usr/bin/env python3
"""Rejouer les preuves serveur sur une base Docker EXISTANTE et marquée jetable.

    python3 tests/sql/server_regression.py noodeu_server_<suffixe> suite
    python3 tests/sql/server_regression.py noodeu_server_<suffixe> upgrade
    python3 tests/sql/server_regression.py noodeu_server_<suffixe> activation

suite : 19 fichiers C18–C25 et C30–C40, après300011 ; upgrade : avant300010 ;
activation : après300010 inactive. Aucun accès distant ni activation persistante.
La liste des fichiers se consulte sans Docker avec --list. Le lanceur n'applique
aucune migration persistante, ne crée/supprime aucune base et ne nettoie rien.
Les tests upgrade/activation incluent leur SQL dans une transaction annulée. Les courses indépendantes
se lancent séparément avec server_concurrency.py ; elles conservent leurs fixtures.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from server_concurrency import CheckFailure, LocalPostgres, database_arg


ROOT = Path(__file__).resolve().parents[2]
MIGRATION = ROOT / "supabase/migrations/20261030001000_dots12_versioned.sql"
UPGRADE = ROOT / "supabase/tests/upgrade/dots12_from_008.sql"
INCLUDE = r"\ir ../../migrations/20261030001000_dots12_versioned.sql"
ACTIVATION = ROOT / "supabase/tests/upgrade/dots12_optional_activation.sql"
OPTIONAL = ROOT / "supabase/optional/activate_dots12_after_validation.sql"
ACTIVATION_INCLUDE = r"\ir ../../optional/activate_dots12_after_validation.sql"
SUITE_FILES = (
    "c18_sans_permission_adulte.sql", "c19_g08_simultane.sql", "c20_purete.sql",
    "c21_de30_petitbac8.sql", "c22_jamais_libelles.sql", "c23_admin_questions.sql",
    "c24_tu_preferes_situations.sql", "c25_accord_phrase.sql", "c30_duo_space.sql",
    "c31_audio.sql", "c32_random.sql", "c33_random_mixed.sql", "c34_home_moment.sql",
    "c35_petit_bac_arbitrage.sql", "c36_petit_bac_latency.sql", "c37_naval_payload_validation.sql",
    "c38_session_settings.sql", "c39_dots12.sql", "c40_server_guards.sql",
)


def files_for(phase: str) -> list[Path]:
    if phase == "upgrade":
        return [UPGRADE]
    if phase == "activation":
        return [ACTIVATION]
    files = [ROOT / "supabase/tests" / name for name in SUITE_FILES]
    missing = [str(path.relative_to(ROOT)) for path in files if not path.is_file()]
    if missing:
        raise CheckFailure("Suite SQL incomplète : " + ", ".join(missing))
    return files


def source(path: Path) -> str:
    sql = path.read_text()
    if path == UPGRADE:
        # L'inclusion doit rester celle relue dans le dépôt. Aucune commande shell
        # ni résolution de chemin fournie par l'appelant n'est acceptée.
        if sql.count(INCLUDE) != 1:
            raise CheckFailure("Inclusion upgrade010 inattendue ; relire le lanceur.")
        sql = sql.replace(INCLUDE, MIGRATION.read_text())
    if path == ACTIVATION:
        if sql.count(ACTIVATION_INCLUDE) != 5:
            raise CheckFailure("Inclusions activation facultative inattendues ; relire le lanceur.")
        sql = sql.replace(ACTIVATION_INCLUDE, OPTIONAL.read_text())
    return sql


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("database", type=database_arg)
    parser.add_argument("phase", choices=("suite", "upgrade", "activation"))
    parser.add_argument("--list", action="store_true", help="Afficher les fichiers sans accès Docker ni écriture.")
    args = parser.parse_args()
    files = files_for(args.phase)
    if args.list:
        print("\n".join(str(path.relative_to(ROOT)) for path in files))
        return 0
    output = Path(tempfile.mkdtemp(prefix="noodeu-server-regression-"))
    report = {"database": args.database, "phase": args.phase, "output": str(output), "tests": [], "ok": False}
    print(json.dumps({"evidence_directory": str(output)}), flush=True)
    try:
        db = LocalPostgres(args.database)
        report["attestation"] = db.attest()
        for path in files:
            sql = source(path)
            started = time.monotonic()
            log = output / (path.name + ".log")
            row = {"file": str(path.relative_to(ROOT)), "sql_sha256": hashlib.sha256(sql.encode()).hexdigest(),
                   "log": str(log)}
            report["tests"].append(row)
            try:
                result = subprocess.run(db.command, input=db.guard + sql, text=True,
                                        capture_output=True, env=db.env, timeout=60)
            except subprocess.TimeoutExpired as exc:
                row.update(exit=None, seconds=round(time.monotonic() - started, 3), outcome="timeout_uncertain")
                stdout = exc.stdout or b""
                stderr = exc.stderr or b""
                log.write_bytes((stdout.encode() if isinstance(stdout, str) else stdout)
                                + (stderr.encode() if isinstance(stderr, str) else stderr))
                raise CheckFailure("psql hors délai ; inspecter la transaction et le journal avant toute reprise.") from exc
            log.write_text(result.stdout + result.stderr)
            row.update(exit=result.returncode, seconds=round(time.monotonic() - started, 3))
            print(json.dumps(row, ensure_ascii=False), flush=True)
            if result.returncode:
                raise CheckFailure(f"Échec {path.name} ; voir {log}")
        if not files:
            raise CheckFailure("Aucun fichier sélectionné ; relire le lanceur.")
        report["ok"] = True
    except (CheckFailure, subprocess.SubprocessError, OSError, ValueError, KeyError) as exc:
        report["error"] = str(exc)
    (output / "results.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
