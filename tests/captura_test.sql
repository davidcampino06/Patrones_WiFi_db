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

ROLLBACK;
