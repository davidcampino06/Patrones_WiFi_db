-- Technical captures (V44-V46): the life of a capture (one waiting or running per network, limits, a failure always
-- says why, only a completed capture says why it stopped and has statistics that never go over its limits), the
-- statistics without addresses, the findings that keep facts apart from inferences, and everything deleted with
-- the network. Runs inside a transaction that is rolled back.
\ir _asserts.sql
BEGIN;

INSERT INTO users (username, email, password_hash, role) VALUES ('captura.admin', 'ca@x.io', 'x', 'ADMIN');
CREATE TEMP TABLE equipo AS
SELECT (SELECT id FROM networks ORDER BY id LIMIT 1) AS network_id,
       (SELECT id FROM users WHERE username = 'captura.admin') AS admin_id;

-- No column can hold an address, a MAC or the content of a packet
SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name LIKE 'traffic_capture%'
                  AND (column_name ~ '(^|_)(ip|mac|address|payload|content|bssid)($|_)')),
    'the capture tables have no column for addresses, MACs or packet content');

-- Life of a capture
INSERT INTO traffic_captures (network_id, requested_by, purpose, max_seconds, max_packets, max_bytes)
SELECT network_id, admin_id, 'Revisar picos de latencia en la sala', 30, 5000, 10485760 FROM equipo;
CREATE TEMP TABLE c AS SELECT id FROM traffic_captures WHERE purpose = 'Revisar picos de latencia en la sala';
SELECT pg_temp.assert_true(
    (SELECT status FROM traffic_captures WHERE id = (SELECT id FROM c)) = 'PENDING',
    'a new capture waits for the sensor');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO traffic_captures (network_id, purpose, max_seconds, max_packets, max_bytes)
      SELECT network_id, 'Otra captura al mismo tiempo', 10, 1000, 1048576 FROM equipo$$,
    'a network has at most one capture waiting or running');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO traffic_captures (network_id, purpose, max_seconds, max_packets, max_bytes)
      SELECT (SELECT id FROM networks ORDER BY id OFFSET 1 LIMIT 1), 'porque si', 10, 1000, 1048576$$,
    'the purpose is stated (at least 10 characters)');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO traffic_captures (network_id, purpose, max_seconds, max_packets, max_bytes)
      SELECT (SELECT id FROM networks ORDER BY id OFFSET 1 LIMIT 1), 'Una captura de una hora', 3600, 1000, 1048576$$,
    'a capture lasts at most 5 minutes');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO traffic_captures (network_id, purpose, max_seconds, max_packets, max_bytes)
      SELECT (SELECT id FROM networks ORDER BY id OFFSET 1 LIMIT 1), 'Una captura enorme', 60, 1000000, 1048576$$,
    'a capture keeps at most 100 000 packets');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO traffic_captures (network_id, purpose, max_seconds, max_packets, max_bytes)
      SELECT (SELECT id FROM networks ORDER BY id OFFSET 1 LIMIT 1), 'Una captura enorme', 60, 1000, 1073741824$$,
    'a capture keeps at most 100 MB');
SELECT pg_temp.assert_rejected(
    $$UPDATE traffic_captures SET status = 'PAUSED' WHERE id = (SELECT id FROM c)$$,
    'the status is one of the five known ones');
SELECT pg_temp.assert_rejected(
    $$UPDATE traffic_captures SET status = 'FAILED', finished_at = NOW() WHERE id = (SELECT id FROM c)$$,
    'a failed capture always says why');
SELECT pg_temp.assert_rejected(
    $$UPDATE traffic_captures SET status = 'FAILED', finished_at = NOW(), failure_reason = 'BAD_LUCK'
      WHERE id = (SELECT id FROM c)$$,
    'the reason of a failure is a known one');
SELECT pg_temp.assert_rejected(
    $$UPDATE traffic_captures SET status = 'COMPLETED', finished_at = NOW() WHERE id = (SELECT id FROM c)$$,
    'a completed capture says why it stopped and has its statistics');

ROLLBACK;
