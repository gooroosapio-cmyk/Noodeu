#!/bin/bash
# Tests SQL sur une base PostgreSQL locale jetable (jamais sur Supabase).
# 1. Migrations jusqu'à la purge exclue, puis tests de l'ancienne base (moteurs toujours présents dans le code).
# 2. Purge et migrations suivantes, puis tests du catalogue (catégories 1 à 4).
# Variables : PGSOCK (dossier du socket, défaut /var/tmp/noodeu-pg), PGPORT (défaut 54329).
set -e
cd "$(dirname "$0")/.."
H=${PGSOCK:-/var/tmp/noodeu-pg}; P=${PGPORT:-54329}
psql_() { psql -h "$H" -p "$P" -U postgres "$@"; }
psql_ -qc 'drop database if exists noodeu' -c 'create database noodeu'
run() { psql_ -d noodeu -v ON_ERROR_STOP=1 -q -f "$1" > /dev/null || { echo "ÉCHEC dans $1"; exit 1; }; }
PURGE=supabase/migrations/20261023000000_purge_activites.sql
run supabase/tests/local_shim.sql
for f in supabase/migrations/*.sql; do [[ "$f" < "$PURGE" ]] && run "$f"; done
for f in supabase/tests/ancienne_base/slice*.sql; do echo "== $f"; psql_ -d noodeu -v ON_ERROR_STOP=1 -q -At -f "$f" || exit 1; done
# 3. Jusqu'au retrait des permissions +18 exclu : tests c14 à c17 (écrits pour l'accord +18 et le plafond d'intensité).
SANS18=supabase/migrations/20261028000100_sans_permission_adulte.sql
for f in supabase/migrations/*.sql; do [[ "$f" < "$PURGE" || ! "$f" < "$SANS18" ]] || run "$f"; done
for f in supabase/tests/c1[4-7]_*.sql; do echo "== $f"; psql_ -d noodeu -v ON_ERROR_STOP=1 -q -At -f "$f" || exit 1; done
# 4. Migrations suivantes jusqu'à la refonte rouge exclue, puis tests c18 à c40 (+18 sans permission ; G08 v2 simultané).
ROUGE=supabase/migrations/20261030001200_salon_revision_g01_oral_g08_tours.sql
for f in supabase/migrations/*.sql; do [[ "$f" < "$SANS18" || ! "$f" < "$ROUGE" ]] || run "$f"; done
for f in supabase/tests/c1[8-9]_*.sql supabase/tests/c[23][0-9]_*.sql supabase/tests/c40_*.sql; do [ -e "$f" ] || continue; echo "== $f"; psql_ -d noodeu -v ON_ERROR_STOP=1 -q -At -f "$f" || exit 1; done
# 5. Refonte rouge et suivantes : révision du salon, lancement de l'hôte, G01 oral, G08 tour par tour.
for f in supabase/migrations/*.sql; do [[ "$f" < "$ROUGE" ]] || run "$f"; done
for f in supabase/tests/c4[1-9]_*.sql supabase/tests/c[5-9][0-9]_*.sql; do [ -e "$f" ] || continue; echo "== $f"; psql_ -d noodeu -v ON_ERROR_STOP=1 -q -At -f "$f" || exit 1; done
