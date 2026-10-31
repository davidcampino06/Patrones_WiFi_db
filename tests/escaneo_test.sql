-- Scans of the nearby Wi-Fi networks (V39-V41): the life of a scan (one waiting or running per network, a failed
-- scan always says why, a finished one has its end time), access points stored once per BSSID fingerprint and never
-- with the BSSID itself, observations with values in range, and everything deleted with the network. Runs inside a
-- transaction that is rolled back.
\ir _asserts.sql
BEGIN;

INSERT INTO users (username, email, password_hash, role) VALUES ('escaneo.prueba', 'ep@x.io', 'x', 'USER');
INSERT INTO home_networks (owner_id, name) SELECT id, 'Casa escaneo' FROM users WHERE username = 'escaneo.prueba';
CREATE TEMP TABLE casa AS SELECT h.id AS network_id, h.owner_id FROM home_networks h WHERE h.name = 'Casa escaneo';

-- Life of a scan
INSERT INTO wifi_scan_sessions (home_network_id, origin, requested_by)
SELECT network_id, 'MANUAL', owner_id FROM casa;
SELECT pg_temp.assert_true(
    (SELECT status FROM wifi_scan_sessions WHERE home_network_id = (SELECT network_id FROM casa)) = 'PENDING',
    'a new scan starts waiting for the agent');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO wifi_scan_sessions (home_network_id, origin) SELECT network_id, 'SCHEDULED' FROM casa$$,
    'a network has at most one scan waiting or running');

ROLLBACK;
