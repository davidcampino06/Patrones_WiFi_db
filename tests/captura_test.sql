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
SELECT pg_temp.assert_rejected(
    $$UPDATE traffic_captures SET capture_tool = 'WIRESHARK' WHERE id = (SELECT id FROM c)$$,
    'the capture tool is NPCAP, PKTMON, RAW_SOCKET or PACKET_SOCKET');
UPDATE traffic_captures SET status = 'RUNNING', started_at = NOW(), capture_tool = 'PKTMON', interface_name = 'Wi-Fi'
WHERE id = (SELECT id FROM c);
SELECT pg_temp.assert_rejected(
    $$UPDATE traffic_captures SET status = 'COMPLETED', finished_at = NOW(), stop_reason = 'DURATION',
             packet_count = 6000, byte_count = 1000 WHERE id = (SELECT id FROM c)$$,
    'the statistics never go over the packet limit');
SELECT pg_temp.assert_rejected(
    $$UPDATE traffic_captures SET status = 'COMPLETED', finished_at = NOW(), stop_reason = 'DURATION',
             packet_count = 10, byte_count = 1000, dropped_by_tool = -1 WHERE id = (SELECT id FROM c)$$,
    'the packets dropped by the tool are never negative');
UPDATE traffic_captures SET status = 'COMPLETED', finished_at = NOW(), stop_reason = 'DURATION', duration_ms = 30000,
       packet_count = 1200, byte_count = 840000, dropped_by_tool = 0, malformed_packets = 0, inbound_bytes = 600000,
       outbound_bytes = 240000, broadcast_packets = 40, multicast_packets = 80, distinct_local_hosts = 6,
       distinct_remote_hosts = 25, analyzed_with = 'AI'
WHERE id = (SELECT id FROM c);
SELECT pg_temp.assert_true(
    (SELECT status = 'COMPLETED' AND failure_reason IS NULL FROM traffic_captures WHERE id = (SELECT id FROM c)),
    'a capture completes with its statistics');
INSERT INTO traffic_captures (network_id, purpose, max_seconds, max_packets, max_bytes)
SELECT network_id, 'Segunda captura despues de la primera', 10, 1000, 1048576 FROM equipo;
SELECT pg_temp.assert_true(
    (SELECT count(*) FROM traffic_captures WHERE network_id = (SELECT network_id FROM equipo)) = 2,
    'once a capture finishes, the network can capture again');
UPDATE traffic_captures SET status = 'CANCELLED', finished_at = NOW(), cancel_requested_at = NOW()
WHERE purpose = 'Segunda captura despues de la primera';
SELECT pg_temp.assert_true(
    (SELECT status FROM traffic_captures WHERE purpose = 'Segunda captura despues de la primera') = 'CANCELLED',
    'a capture that had not started can be cancelled');

-- Statistics
INSERT INTO traffic_capture_protocols (capture_id, protocol, packets, bytes)
SELECT id, p, n, b FROM c, (VALUES ('HTTPS', 700, 600000), ('DNS', 120, 12000), ('ARP', 40, 2400)) AS v(p, n, b);
SELECT pg_temp.assert_rejected(
    $$INSERT INTO traffic_capture_protocols (capture_id, protocol, packets, bytes) SELECT id, 'TELNET', 1, 1 FROM c$$,
    'protocols come from a known list');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO traffic_capture_protocols (capture_id, protocol, packets, bytes) SELECT id, 'DNS', 1, 1 FROM c$$,
    'each protocol appears once per capture');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO traffic_capture_protocols (capture_id, protocol, packets, bytes) SELECT id, 'UDP', 0, 0 FROM c$$,
    'a protocol without packets is not stored');
INSERT INTO traffic_capture_ports (capture_id, transport, port, packets, bytes) SELECT id, 'TCP', 443, 700, 600000 FROM c;
SELECT pg_temp.assert_rejected(
    $$INSERT INTO traffic_capture_ports (capture_id, transport, port, packets, bytes) SELECT id, 'SCTP', 80, 1, 1 FROM c$$,
    'a service is TCP or UDP');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO traffic_capture_ports (capture_id, transport, port, packets, bytes) SELECT id, 'UDP', 70000, 1, 1 FROM c$$,
    'a port is between 0 and 65535');
INSERT INTO traffic_capture_intervals (capture_id, second_offset, packets, bytes)
SELECT id, s, 40, 28000 FROM c, generate_series(0, 29) AS s;
SELECT pg_temp.assert_rejected(
    $$INSERT INTO traffic_capture_intervals (capture_id, second_offset, packets, bytes) SELECT id, 999, 1, 1 FROM c$$,
    'an interval falls inside the capture');

-- Findings: facts apart from inferences
INSERT INTO traffic_capture_findings (capture_id, category, code, severity, title, evidence, source)
SELECT id, 'OBSERVED', 'BROADCAST_SHARE', 'INFO', 'Poca difusión', '40 de 1200 paquetes (3 %) fueron de difusión.', 'RULES'
FROM c;
INSERT INTO traffic_capture_findings (capture_id, category, code, severity, title, evidence, recommendation,
                                      confidence, source)
SELECT id, 'INFERRED', 'TRAFFIC_BURST', 'WARNING', 'Ráfaga de tráfico', 'El segundo 14 tuvo 9 veces la mediana.',
       'Repite la captura a la misma hora y compara.', 0.62, 'AI' FROM c;
SELECT pg_temp.assert_rejected(
    $$INSERT INTO traffic_capture_findings (capture_id, category, code, severity, title, evidence, source)
      SELECT id, 'INFERRED', 'TRAFFIC_BURST', 'WARNING', 'Sin confianza', 'x', 'AI' FROM c$$,
    'an inference always says how sure it is');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO traffic_capture_findings (capture_id, category, code, severity, title, evidence, confidence, source)
      SELECT id, 'OBSERVED', 'PACKETS', 'INFO', 'Un hecho', 'x', 0.5, 'RULES' FROM c$$,
    'an observation is a count, not a guess: no confidence');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO traffic_capture_findings (capture_id, category, code, severity, title, evidence, confidence, source)
      SELECT id, 'INFERRED', 'X', 'WARNING', 'Mal', 'x', 1.5, 'AI' FROM c$$,
    'confidence is between 0 and 1 (and codes are upper-case words)');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO traffic_capture_findings (capture_id, category, code, severity, title, evidence, source)
      SELECT id, 'GUESS', 'SOMETHING', 'INFO', 'Mal', 'x', 'AI' FROM c$$,
    'a finding is OBSERVED or INFERRED');

-- Deleting the network deletes its captures and everything they produced; deleting the admin keeps them
DELETE FROM users WHERE username = 'captura.admin';
SELECT pg_temp.assert_true(
    (SELECT requested_by IS NULL FROM traffic_captures WHERE id = (SELECT id FROM c)),
    'deleting the account that asked for a capture keeps the capture without the person');
DELETE FROM networks WHERE id = (SELECT network_id FROM equipo);
SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM traffic_captures WHERE network_id = (SELECT network_id FROM equipo))
    AND NOT EXISTS (SELECT 1 FROM traffic_capture_protocols WHERE capture_id = (SELECT id FROM c))
    AND NOT EXISTS (SELECT 1 FROM traffic_capture_ports WHERE capture_id = (SELECT id FROM c))
    AND NOT EXISTS (SELECT 1 FROM traffic_capture_intervals WHERE capture_id = (SELECT id FROM c))
    AND NOT EXISTS (SELECT 1 FROM traffic_capture_findings WHERE capture_id = (SELECT id FROM c)),
    'deleting a team network deletes its captures, statistics and findings');

ROLLBACK;
