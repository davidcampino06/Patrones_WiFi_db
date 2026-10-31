#!/usr/bin/env bash
# Upgrade test: the new migrations must work on a database that already has data, like the one in Railway, and V28
# must stop cleanly (changing nothing) if two accounts only differ in upper/lower case.
# Usage: ADMIN_URL=postgresql://postgres:<pass>@localhost:5432/postgres tests/actualizacion_test.sh
# DEPLOYED is the oldest production state to upgrade from (default 25, after Avance 10); CURRENT is production today
# (default 38, after Avance 16, with the application role).
set -euo pipefail
: "${ADMIN_URL:?Set ADMIN_URL to a user that can create databases, e.g. postgresql://postgres:secret@localhost:5432/postgres}"
DEPLOYED=${DEPLOYED:-25}
CURRENT=${CURRENT:-38}
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
INSERT INTO network_sensor_reports (network_id, agent_version, device_count, security_score, security_grade)
SELECT id, '1.5.0', 3, 80, 'ACCEPTABLE' FROM networks LIMIT 1;
INSERT INTO network_sensor_devices (network_id, fingerprint) SELECT id, repeat('ab', 12) FROM networks LIMIT 1;
UPDATE network_sensor_devices SET authorized = FALSE, label = 'Equipo raro', last_seen_at = NOW();
INSERT INTO network_sensor_device_sessions (network_id, fingerprint, connected_at, last_seen_at)
SELECT network_id, fingerprint, NOW(), NOW() FROM network_sensor_devices;
UPDATE network_sensor_device_sessions SET disconnected_at = last_seen_at;
DELETE FROM network_sensor_device_sessions;
UPDATE network_sensor_devices SET kind = 'PHONE', role = NULL, model = 'Pixel 8';
UPDATE network_sensors SET identify_until = NOW() + INTERVAL '10 minutes';
INSERT INTO ai_model_versions (version, algorithm, samples, networks, data_from, data_to, decision, reason, active,
                               training_set)
VALUES ('real-rol', 'IsolationForest', 600, 1, NOW() - INTERVAL '3 days', NOW(), 'PROMOTED', 'Prueba', TRUE, '[]');
UPDATE ai_model_versions SET active = FALSE;
INSERT INTO wifi_scan_sessions (home_network_id, origin) SELECT id, 'MANUAL' FROM home_networks LIMIT 1;
UPDATE wifi_scan_sessions SET status = 'RUNNING', started_at = NOW();
INSERT INTO wifi_access_points (home_network_id, bssid_fingerprint, ssid, first_seen_at, last_seen_at)
SELECT id, repeat('cd', 12), 'Vecino', NOW(), NOW() FROM home_networks LIMIT 1;
INSERT INTO wifi_scan_observations (scan_id, access_point_id, signal_percent)
SELECT s.id, a.id, 70 FROM wifi_scan_sessions s, wifi_access_points a;
UPDATE wifi_scan_sessions SET status = 'COMPLETED', finished_at = NOW(), network_count = 1, access_point_count = 1;
DELETE FROM wifi_scan_observations;
DELETE FROM wifi_access_points;
DELETE FROM wifi_scan_sessions;
UPDATE network_sensor_devices SET hostname = 'Portatil-sala', name_source = 'ROUTER';
INSERT INTO agent_capabilities (network_id, platform, capture_consent, pktmon) SELECT id, 'Windows', TRUE, TRUE FROM networks LIMIT 1;
UPDATE agent_capabilities SET elevated = TRUE, reported_at = NOW();
INSERT INTO traffic_captures (network_id, purpose, max_seconds, max_packets, max_bytes)
SELECT id, 'Prueba del rol de la aplicacion', 10, 1000, 1048576 FROM networks LIMIT 1;
UPDATE traffic_captures SET status = 'COMPLETED', started_at = NOW(), finished_at = NOW(), stop_reason = 'DURATION',
       packet_count = 10, byte_count = 600;
INSERT INTO traffic_capture_protocols (capture_id, protocol, packets, bytes) SELECT id, 'DNS', 10, 600 FROM traffic_captures;
INSERT INTO traffic_capture_ports (capture_id, transport, port, packets, bytes) SELECT id, 'UDP', 53, 10, 600 FROM traffic_captures;
INSERT INTO traffic_capture_intervals (capture_id, second_offset, packets, bytes) SELECT id, 0, 10, 600 FROM traffic_captures;
INSERT INTO traffic_capture_findings (capture_id, category, code, severity, title, evidence, source)
SELECT id, 'OBSERVED', 'DNS_SHARE', 'INFO', 'Solo DNS', '10 de 10 paquetes.', 'RULES' FROM traffic_captures;
DELETE FROM traffic_captures;
DELETE FROM agent_capabilities;
INSERT INTO audit_events (actor_role, action, outcome) VALUES ('SYSTEM', 'RETENTION_PURGED', 'SUCCESS');
DELETE FROM network_sensor_devices;
DELETE FROM network_sensor_reports;
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
