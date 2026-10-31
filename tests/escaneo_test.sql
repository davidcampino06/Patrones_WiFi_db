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
SELECT pg_temp.assert_rejected(
    $$INSERT INTO wifi_scan_sessions (home_network_id, origin, status, finished_at)
      SELECT network_id, 'AUTOMATIC', 'COMPLETED', NOW() FROM casa$$,
    'the origin is MANUAL or SCHEDULED');
SELECT pg_temp.assert_rejected(
    $$UPDATE wifi_scan_sessions SET status = 'DONE'$$,
    'the status is one of the four known ones');
SELECT pg_temp.assert_rejected(
    $$UPDATE wifi_scan_sessions SET status = 'FAILED', finished_at = NOW()$$,
    'a failed scan always says why');
SELECT pg_temp.assert_rejected(
    $$UPDATE wifi_scan_sessions SET status = 'FAILED', finished_at = NOW(), failure_reason = 'SOMETHING'$$,
    'the reason of a failure is a known one');
SELECT pg_temp.assert_rejected(
    $$UPDATE wifi_scan_sessions SET status = 'COMPLETED'$$,
    'a finished scan has its end time');
SELECT pg_temp.assert_rejected(
    $$UPDATE wifi_scan_sessions SET status = 'COMPLETED', finished_at = NOW(), failure_reason = 'TIMEOUT'$$,
    'a completed scan has no failure reason');
SELECT pg_temp.assert_rejected(
    $$UPDATE wifi_scan_sessions SET started_at = requested_at - INTERVAL '1 minute'$$,
    'a scan does not start before it was requested');
SELECT pg_temp.assert_rejected(
    $$UPDATE wifi_scan_sessions SET network_count = -1$$,
    'counts are never negative');
SELECT pg_temp.assert_rejected(
    $$UPDATE wifi_scan_sessions SET scan_tool = 'IWLIST'$$,
    'the scan tool is NETSH or NMCLI');
UPDATE wifi_scan_sessions SET status = 'RUNNING', started_at = NOW(), interface_name = 'Wi-Fi', scan_tool = 'NETSH';

-- Access points: one per BSSID fingerprint, never the BSSID
INSERT INTO wifi_access_points (home_network_id, bssid_fingerprint, bssid_suffix, vendor, ssid, first_seen_at,
                                last_seen_at)
SELECT network_id, 'aaaabbbbccccddddeeeeffff', 'F1', 'TP-Link', 'Café ☕ "Vecino"', NOW(), NOW() FROM casa;
SELECT pg_temp.assert_true(
    (SELECT ssid FROM wifi_access_points WHERE bssid_fingerprint = 'aaaabbbbccccddddeeeeffff') = 'Café ☕ "Vecino"',
    'a network name with accents, symbols and quotes is kept as it is');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO wifi_access_points (home_network_id, bssid_fingerprint, ssid, first_seen_at, last_seen_at)
      SELECT network_id, 'aaaabbbbccccddddeeeeffff', 'Otra', NOW(), NOW() FROM casa$$,
    'the same access point is stored once per network (repeating a scan does not copy it)');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO wifi_access_points (home_network_id, bssid_fingerprint, ssid, first_seen_at, last_seen_at)
      SELECT network_id, 'A4:2B:B0:12:34:56', 'Red', NOW(), NOW() FROM casa$$,
    'a BSSID is never stored, only its fingerprint');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO wifi_access_points (home_network_id, bssid_fingerprint, bssid_suffix, ssid, first_seen_at,
                                      last_seen_at)
      SELECT network_id, '111122223333444455556666', 'f1', 'Red', NOW(), NOW() FROM casa$$,
    'the last byte of the BSSID is kept as two upper-case hex digits');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO wifi_access_points (home_network_id, bssid_fingerprint, ssid, hidden, first_seen_at, last_seen_at)
      SELECT network_id, '111122223333444455556666', 'Visible', TRUE, NOW(), NOW() FROM casa$$,
    'a hidden network has no name');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO wifi_access_points (home_network_id, bssid_fingerprint, first_seen_at, last_seen_at)
      SELECT network_id, '111122223333444455556666', NOW(), NOW() FROM casa$$,
    'a network without a name is marked hidden');
INSERT INTO wifi_access_points (home_network_id, bssid_fingerprint, hidden, first_seen_at, last_seen_at)
SELECT network_id, '111122223333444455556666', TRUE, NOW(), NOW() FROM casa;
SELECT pg_temp.assert_rejected(
    $$UPDATE wifi_access_points SET last_seen_at = first_seen_at - INTERVAL '1 day'$$,
    'an access point is not last seen before it was first seen');
SELECT pg_temp.assert_rejected(
    $$UPDATE wifi_access_points SET times_seen = 0$$,
    'an access point was seen at least once');

-- Observations
INSERT INTO wifi_scan_observations (scan_id, access_point_id, ssid, signal_percent, channel, band, radio_type,
                                    authentication, security_label, cipher, connected)
SELECT s.id, a.id, a.ssid, 82, 44, '5', '802.11ac', 'WPA2', 'WPA2-Personal', 'CCMP', TRUE
FROM wifi_scan_sessions s JOIN wifi_access_points a ON a.home_network_id = s.home_network_id
WHERE a.bssid_fingerprint = 'aaaabbbbccccddddeeeeffff';
INSERT INTO wifi_scan_observations (scan_id, access_point_id)
SELECT s.id, a.id FROM wifi_scan_sessions s JOIN wifi_access_points a ON a.home_network_id = s.home_network_id
WHERE a.bssid_fingerprint = '111122223333444455556666';
SELECT pg_temp.assert_true(
    (SELECT authentication FROM wifi_scan_observations o JOIN wifi_access_points a ON a.id = o.access_point_id
     WHERE a.bssid_fingerprint = '111122223333444455556666') = 'UNKNOWN'
    AND (SELECT signal_percent IS NULL AND channel IS NULL AND band IS NULL FROM wifi_scan_observations o
         JOIN wifi_access_points a ON a.id = o.access_point_id
         WHERE a.bssid_fingerprint = '111122223333444455556666'),
    'what the system did not report stays unknown');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO wifi_scan_observations (scan_id, access_point_id)
      SELECT scan_id, access_point_id FROM wifi_scan_observations LIMIT 1$$,
    'a scan sees each access point once');
SELECT pg_temp.assert_rejected($$UPDATE wifi_scan_observations SET signal_percent = 101$$, 'signal is 0 to 100 %');
SELECT pg_temp.assert_rejected($$UPDATE wifi_scan_observations SET signal_dbm = 5$$, 'dBm is negative');
SELECT pg_temp.assert_rejected($$UPDATE wifi_scan_observations SET channel = 0$$, 'channel is 1 to 233');
SELECT pg_temp.assert_rejected($$UPDATE wifi_scan_observations SET band = '60'$$, 'band is 2.4, 5 or 6 GHz');
SELECT pg_temp.assert_rejected($$UPDATE wifi_scan_observations SET authentication = 'WPA4'$$,
    'security is one of the known summaries');

ROLLBACK;
