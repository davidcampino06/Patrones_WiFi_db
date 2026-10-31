-- Privacy of the end users: deleting an account deletes everything it left in the database (its networks, the key,
-- codes, reports, devices, connection periods and alerts of its agent, its connection tests, alert preferences,
-- sessions and password reset links), and nothing of the team is touched. A catalog check makes sure that a future
-- table that points to an account, a home network or a device cannot keep its data after it is deleted.
-- Runs inside a transaction that is rolled back.
\ir _asserts.sql
BEGIN;

-- Every foreign key to users, home_networks or agent_devices deletes with them (CASCADE) or forgets who it was
-- (SET NULL: a team analysis or a model version keeps its history without the person).
SELECT pg_temp.assert_true(
    NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE contype = 'f' AND connamespace = 'public'::regnamespace
          AND confrelid::regclass::text IN ('users', 'home_networks', 'agent_devices')
          AND confdeltype NOT IN ('c', 'n')),
    'no table keeps the data of a deleted account, home network or device (every reference is CASCADE or SET NULL)');

INSERT INTO users (username, email, password_hash, role) VALUES ('privacidad.prueba', 'pp@x.io', 'x', 'USER');
INSERT INTO home_networks (owner_id, name) SELECT id, 'Casa privada' FROM users WHERE username = 'privacidad.prueba';
INSERT INTO agent_keys (home_network_id, key_hash, key_prefix)
SELECT id, repeat('1', 64), 'wsa_priv' FROM home_networks WHERE name = 'Casa privada';
INSERT INTO agent_pairing_codes (home_network_id, code_hash, expires_at)
SELECT id, repeat('2', 64), NOW() + INTERVAL '10 minutes' FROM home_networks WHERE name = 'Casa privada';
INSERT INTO agent_reports (home_network_id, agent_version, device_count)
SELECT id, '1.7.0', 1 FROM home_networks WHERE name = 'Casa privada';
INSERT INTO agent_devices (home_network_id, fingerprint, hostname, kind)
SELECT id, 'ccccddddeeeeffff00001111', 'Celular de Pepa', 'PHONE' FROM home_networks WHERE name = 'Casa privada';
INSERT INTO agent_device_sessions (home_network_id, fingerprint, connected_at, last_seen_at)
SELECT id, 'ccccddddeeeeffff00001111', NOW() - INTERVAL '1 hour', NOW() FROM home_networks WHERE name = 'Casa privada';
INSERT INTO agent_alerts (home_network_id, type, detail)
SELECT id, 'NEW_DEVICE', 'Apareció 1 equipo nuevo en tu red.' FROM home_networks WHERE name = 'Casa privada';
INSERT INTO connection_tests (home_network_id, latency_ms, jitter_ms, download_mbps, upload_mbps)
SELECT id, 20, 2, 100, 20 FROM home_networks WHERE name = 'Casa privada';
INSERT INTO alert_preferences (user_id) SELECT id FROM users WHERE username = 'privacidad.prueba';
INSERT INTO wifi_scan_sessions (home_network_id, origin, requested_by)
SELECT h.id, 'MANUAL', h.owner_id FROM home_networks h WHERE h.name = 'Casa privada';
INSERT INTO wifi_access_points (home_network_id, bssid_fingerprint, ssid, first_seen_at, last_seen_at)
SELECT id, 'ddddeeeeffff000011112222', 'Red del vecino', NOW(), NOW() FROM home_networks WHERE name = 'Casa privada';
INSERT INTO wifi_scan_observations (scan_id, access_point_id, signal_percent)
SELECT s.id, a.id, 60 FROM wifi_scan_sessions s JOIN wifi_access_points a ON a.home_network_id = s.home_network_id
WHERE a.bssid_fingerprint = 'ddddeeeeffff000011112222';
INSERT INTO refresh_tokens (user_id, family_id, token_hash, expires_at)
SELECT id, gen_random_uuid(), repeat('3', 64), NOW() + INTERVAL '14 days' FROM users WHERE username = 'privacidad.prueba';
INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
SELECT id, repeat('4', 64), NOW() + INTERVAL '30 minutes' FROM users WHERE username = 'privacidad.prueba';

CREATE TEMP TABLE team_before AS
SELECT (SELECT count(*) FROM networks) AS networks, (SELECT count(*) FROM measurements) AS measurements;

DELETE FROM users WHERE username = 'privacidad.prueba';

SELECT pg_temp.assert_true(NOT EXISTS (SELECT 1 FROM home_networks WHERE name = 'Casa privada'),
    'deleting an account deletes its home networks');
SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM agent_keys WHERE key_hash = repeat('1', 64))
    AND NOT EXISTS (SELECT 1 FROM agent_pairing_codes WHERE code_hash = repeat('2', 64)),
    '... the key and the installation code of its agent');
SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM agent_devices WHERE fingerprint = 'ccccddddeeeeffff00001111')
    AND NOT EXISTS (SELECT 1 FROM agent_device_sessions WHERE fingerprint = 'ccccddddeeeeffff00001111'),
    '... its devices with the names they announced and when they were connected');
SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM agent_reports r LEFT JOIN home_networks h ON h.id = r.home_network_id WHERE h.id IS NULL)
    AND NOT EXISTS (SELECT 1 FROM agent_alerts a LEFT JOIN home_networks h ON h.id = a.home_network_id WHERE h.id IS NULL)
    AND NOT EXISTS (SELECT 1 FROM connection_tests c LEFT JOIN home_networks h ON h.id = c.home_network_id WHERE h.id IS NULL),
    '... the reports, alerts and connection tests of its networks');
SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM refresh_tokens WHERE token_hash = repeat('3', 64))
    AND NOT EXISTS (SELECT 1 FROM password_reset_tokens WHERE token_hash = repeat('4', 64))
    AND NOT EXISTS (SELECT 1 FROM alert_preferences p LEFT JOIN users u ON u.id = p.user_id WHERE u.id IS NULL),
    '... and its sessions, recovery links and alert preferences');
SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM wifi_access_points WHERE bssid_fingerprint = 'ddddeeeeffff000011112222')
    AND NOT EXISTS (SELECT 1 FROM wifi_scan_sessions s LEFT JOIN home_networks h ON h.id = s.home_network_id
                    WHERE h.id IS NULL)
    AND NOT EXISTS (SELECT 1 FROM wifi_scan_observations o LEFT JOIN wifi_scan_sessions s ON s.id = o.scan_id
                    WHERE s.id IS NULL),
    '... and the scans of the nearby networks its agent made');
SELECT pg_temp.assert_true(
    (SELECT networks FROM team_before) = (SELECT count(*) FROM networks)
    AND (SELECT measurements FROM team_before) = (SELECT count(*) FROM measurements),
    'the networks and measurements of the team are not touched');

ROLLBACK;
