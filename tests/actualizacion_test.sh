#!/usr/bin/env bash
# Upgrade test: the new migrations must work on a database that already has data, like the one in Railway, and V28
# must stop cleanly (changing nothing) if two accounts only differ in upper/lower case.
# Usage: ADMIN_URL=postgresql://postgres:<pass>@localhost:5432/postgres tests/actualizacion_test.sh
# DEPLOYED is the oldest production state to upgrade from (default 25, after Avance 10); CURRENT is production today
# (default 33, after Avance 11, with the application role).
set -euo pipefail
: "${ADMIN_URL:?Set ADMIN_URL to a user that can create databases, e.g. postgresql://postgres:secret@localhost:5432/postgres}"
DEPLOYED=${DEPLOYED:-25}
CURRENT=${CURRENT:-33}
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
cleanup() {
    psql "$ADMIN_URL" -q -c "DROP DATABASE IF EXISTS wifisense_upgrade" -c "DROP DATABASE IF EXISTS wifisense_upgrade_dup" \
        -c "DROP DATABASE IF EXISTS wifisense_upgrade_role" >/dev/null 2>&1 || true
}
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

echo "== 4. Production today: V1..V$CURRENT, demo data and the application role; then the new migrations"
url=$(fresh_db wifisense_upgrade_role)
migrate "$url" 1 "$CURRENT"
psql "$url" -v ON_ERROR_STOP=1 -q -o /dev/null -f seeds/seed_data.sql
psql "$url" -v ON_ERROR_STOP=1 -q -f security/rol_aplicacion.sql
psql "$url" -q -c "INSERT INTO users (username, email, password_hash, role) VALUES ('Real.Usuario', 'real@ejemplo.com', 'x', 'USER')"
psql "$url" -q -c "INSERT INTO home_networks (owner_id, name) SELECT id, 'Casa real' FROM users WHERE username = 'Real.Usuario'"
migrate "$url" $((CURRENT + 1)) 9999
# Tables created after the role script (by the same owner) must be usable by the application without new grants.
psql "$url" -v ON_ERROR_STOP=1 -q <<'SQL'
BEGIN;
SET LOCAL ROLE wifisense_app;
INSERT INTO network_sensors (network_id, key_hash, key_prefix) SELECT id, repeat('ab', 32), 'wsa_Rol1' FROM networks LIMIT 1;
UPDATE network_sensors SET last_seen_at = NOW(), agent_version = '1.4.0' WHERE key_prefix = 'wsa_Rol1';
INSERT INTO network_sensor_pairing_codes (network_id, code_hash, expires_at)
SELECT id, repeat('cd', 32), NOW() + INTERVAL '15 minutes' FROM networks LIMIT 1;
DELETE FROM network_sensor_pairing_codes;
DELETE FROM network_sensors;
ROLLBACK;
SQL
echo "   OK: the application role uses the new tables"
# The team panel starts empty: the cleanup deletes every simulated thing and nothing else.
psql "$url" -v ON_ERROR_STOP=1 -q -o /dev/null -f mantenimiento/revisar_datos_simulados.sql
psql "$url" -q -c "INSERT INTO locations (name) VALUES ('Sede real')" \
    -c "INSERT INTO zones (location_id, name) SELECT id, 'Piso 1' FROM locations WHERE name = 'Sede real'" \
    -c "INSERT INTO networks (zone_id, ssid, bssid, frequency_band, channel, security_type)
        SELECT id, 'Red real', 'AA:BB:CC:00:00:01', '5GHz', 36, 'WPA3' FROM zones WHERE name = 'Piso 1'"
psql "$url" -v ON_ERROR_STOP=1 -q -o /dev/null -f mantenimiento/borrar_datos_simulados.sql
left=$(psql "$url" -At -c "SELECT (SELECT count(*) FROM networks WHERE data_source_type = 'SIMULATION')
    + (SELECT count(*) FROM measurements WHERE source = 'SIMULATION')
    + (SELECT count(*) FROM locations WHERE name IN ('Main Campus', 'Downtown Office'))")
[ "$left" = "0" ] || { echo "FAILED: simulated data left after the cleanup ($left rows)"; exit 1; }
kept=$(psql "$url" -At -c "SELECT (SELECT count(*) FROM networks WHERE ssid = 'Red real')
    + (SELECT count(*) FROM users WHERE username = 'Real.Usuario') + (SELECT count(*) FROM home_networks)")
[ "$kept" = "3" ] || { echo "FAILED: the cleanup deleted real data ($kept of 3 left)"; exit 1; }
echo "   OK: the cleanup leaves no simulated data and keeps the real network, the account and Mi Wi-Fi"

echo "UPGRADE TEST PASSED"
