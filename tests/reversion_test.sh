#!/usr/bin/env bash
# Recovery test of the Avance 24 migrations (V39..V47): the reversion scripts must take a database with data back to
# exactly the schema it had before (V38), without touching the older data, and the migrations must apply again after.
# Usage: ADMIN_URL=postgresql://postgres:<pass>@localhost:5432/postgres tests/reversion_test.sh
set -euo pipefail
: "${ADMIN_URL:?Set ADMIN_URL to a user that can create databases, e.g. postgresql://postgres:secret@localhost:5432/postgres}"
FIRST=${FIRST:-39}
cd "$(dirname "$0")/.."

version() { basename "$1" | sed -E 's/^V([0-9]+)__.*/\1/'; }
migrate() {  # migrate <url> <from> <to>
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
schema() {  # the schema without comments or ownership, sorted so two equal schemas compare equal
    pg_dump --schema-only --no-owner --no-privileges --no-comments "$1" | grep -v '^--' | grep -v '^$' \
        | grep -v '^SET \|^SELECT pg_catalog\|^\\restrict \|^\\unrestrict ' | sort
}
cleanup() {
    psql "$ADMIN_URL" -q -c "DROP DATABASE IF EXISTS wifisense_before" -c "DROP DATABASE IF EXISTS wifisense_undo" \
        >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "== 1. The schema before the Avance 24 (V1..V$((FIRST - 1)))"
before=$(fresh_db wifisense_before)
migrate "$before" 1 $((FIRST - 1))
schema "$before" > /tmp/wifisense_before.sql

echo "== 2. Every migration, with data in the old and in the new tables"
url=$(fresh_db wifisense_undo)
migrate "$url" 1 9999
psql "$url" -v ON_ERROR_STOP=1 -q -o /dev/null -f seeds/seed_data.sql
psql "$url" -v ON_ERROR_STOP=1 -q -f security/rol_aplicacion.sql  # as in Railway: tables made later stay usable
psql "$url" -v ON_ERROR_STOP=1 -q <<'SQL'
INSERT INTO users (username, email, password_hash, role) VALUES ('Ana.Reversion', 'ana.rev@ejemplo.com', 'x', 'USER');
INSERT INTO home_networks (owner_id, name) SELECT id, 'Casa de Ana' FROM users WHERE username = 'Ana.Reversion';
INSERT INTO wifi_scan_sessions (home_network_id, origin, status)
    SELECT id, 'MANUAL', 'PENDING' FROM home_networks WHERE name = 'Casa de Ana';
INSERT INTO traffic_captures (network_id, purpose, max_seconds, max_packets, max_bytes)
    SELECT id, 'Prueba de reversión de la base', 30, 5000, 20971520 FROM networks ORDER BY id LIMIT 1;
INSERT INTO audit_events (actor_username, actor_role, action, outcome) VALUES ('Jefe', 'ADMIN', 'CAPTURE_REQUESTED', 'SUCCESS');
SQL
old_rows=$(psql "$url" -At -c "SELECT (SELECT count(*) FROM users) || '/' || (SELECT count(*) FROM measurements) || '/' || (SELECT count(*) FROM home_networks)")
