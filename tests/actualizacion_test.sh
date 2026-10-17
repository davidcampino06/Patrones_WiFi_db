#!/usr/bin/env bash
# Upgrade test: the new migrations must work on a database that already has data, like the one in Railway, and V28
# must stop cleanly (changing nothing) if two accounts only differ in upper/lower case.
# Usage: ADMIN_URL=postgresql://postgres:<pass>@localhost:5432/postgres tests/actualizacion_test.sh
# DEPLOYED is the last migration that production already has (default 25, the state after Avance 10).
set -euo pipefail
: "${ADMIN_URL:?Set ADMIN_URL to a user that can create databases, e.g. postgresql://postgres:secret@localhost:5432/postgres}"
DEPLOYED=${DEPLOYED:-25}
cd "$(dirname "$0")/.."

version() { basename "$1" | sed -E 's/^V([0-9]+)__.*/\1/'; }
migrate() {  # migrate <url> <from> <to>: applies the migrations with from <= version <= to
    for file in $(ls migrations/V*__*.sql | sort -V); do
        v=$(version "$file")
        if [ "$v" -ge "$2" ] && [ "$v" -le "$3" ]; then
            psql "$1" -v ON_ERROR_STOP=1 -q -f "$file"
        fi
    done
}
fresh_db() {
    psql "$ADMIN_URL" -q -c "DROP DATABASE IF EXISTS $1" -c "CREATE DATABASE $1"
    echo "${ADMIN_URL%/*}/$1"
}
cleanup() { psql "$ADMIN_URL" -q -c "DROP DATABASE IF EXISTS wifisense_upgrade" -c "DROP DATABASE IF EXISTS wifisense_upgrade_dup" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "== 1. Production-like database: V1..V$DEPLOYED, seed data and existing rows"
url=$(fresh_db wifisense_upgrade)
migrate "$url" 1 "$DEPLOYED"
psql "$url" -v ON_ERROR_STOP=1 -q -o /dev/null -f seeds/seed_data.sql
psql "$url" -v ON_ERROR_STOP=1 -q -f tests/datos_previos.sql

echo "== 2. New migrations on top of the data"
migrate "$url" $((DEPLOYED + 1)) 9999
psql "$url" -v ON_ERROR_STOP=1 -q -o /dev/null -f tests/despues_de_actualizar.sql
for t in optimizacion integridad diccionario; do
    psql "$url" -v ON_ERROR_STOP=1 -q -o /dev/null -f "tests/${t}_test.sql"
done
echo "   OK: no row lost and every check passes"

echo "== 3. Two accounts that only differ in case: V28 must refuse and change nothing"
url=$(fresh_db wifisense_upgrade_dup)
migrate "$url" 1 27
psql "$url" -q -c "INSERT INTO users (username, email, password_hash) VALUES
    ('Carlos', 'Carlos@wifisense.local', 'x'), ('carlos', 'carlos.otro@gmail.com', 'x')"
if output=$(psql "$url" -v ON_ERROR_STOP=1 -q -f migrations/V28__case_insensitive_users.sql 2>&1); then
    echo "FAILED: V28 accepted duplicate accounts"; exit 1
fi
grep -q "V28: hay cuentas que solo se diferencian en mayúsculas" <<<"$output" || { echo "FAILED: unclear message: $output"; exit 1; }
untouched=$(psql "$url" -At -c "SELECT count(*) FROM users WHERE email = 'Carlos@wifisense.local'")
[ "$untouched" = "1" ] || { echo "FAILED: V28 changed data before refusing"; exit 1; }
echo "   OK: V28 stopped with a clear message and changed nothing"

echo "UPGRADE TEST PASSED"
