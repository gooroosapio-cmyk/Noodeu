#!/bin/bash
# Tests SQL sur une base PostgreSQL locale jetable (jamais sur Supabase).
# 1. Migrations jusqu'à la purge exclue, puis tests de l'ancienne base (moteurs toujours présents dans le code).
# 2. Purge et migrations suivantes, puis tests du catalogue actuel (catégories 1 à 4).
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
for f in supabase/migrations/*.sql; do [[ "$f" < "$PURGE" ]] || run "$f"; done
for f in supabase/tests/c14_*.sql; do [ -e "$f" ] || continue; echo "== $f"; psql_ -d noodeu -v ON_ERROR_STOP=1 -q -At -f "$f" || exit 1; done
