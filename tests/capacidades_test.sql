-- What the computer of each agent can do (V43): one row per agent, of a Mi Wi-Fi network or of a team network but
-- never both nor neither, known values only, and deleted with its network. Runs inside a transaction that is rolled
-- back.
\ir _asserts.sql
BEGIN;

INSERT INTO users (username, email, password_hash, role) VALUES ('capacidades.prueba', 'cp@x.io', 'x', 'USER');
INSERT INTO home_networks (owner_id, name) SELECT id, 'Casa capacidades' FROM users WHERE username = 'capacidades.prueba';
CREATE TEMP TABLE casa AS SELECT id AS network_id FROM home_networks WHERE name = 'Casa capacidades';
CREATE TEMP TABLE equipo AS SELECT id AS network_id FROM networks ORDER BY id LIMIT 1;

INSERT INTO agent_capabilities (home_network_id, platform, agent_version) SELECT network_id, 'Windows', '2.0.0' FROM casa;
SELECT pg_temp.assert_true(
    (SELECT NOT capture_consent AND NOT elevated AND NOT npcap AND NOT pktmon AND monitor_mode = 'UNKNOWN'
     FROM agent_capabilities WHERE home_network_id = (SELECT network_id FROM casa)),
    'by default nothing is allowed nor assumed: no consent, no tools, monitor mode unknown');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO agent_capabilities (home_network_id, platform) SELECT network_id, 'Windows' FROM casa$$,
    'one row per agent of Mi Wi-Fi');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO agent_capabilities (platform) VALUES ('Windows')$$,
    'a row always belongs to an agent');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO agent_capabilities (home_network_id, network_id)
      SELECT (SELECT network_id FROM casa), (SELECT network_id FROM equipo)$$,
    'a row belongs to a Mi Wi-Fi network or to a team network, not to both');
SELECT pg_temp.assert_rejected(
    $$UPDATE agent_capabilities SET monitor_mode = 'MAYBE'$$,
    'monitor mode is SUPPORTED, UNSUPPORTED or UNKNOWN');
SELECT pg_temp.assert_rejected(
    $$UPDATE agent_capabilities SET capture_interfaces = -1$$,
    'the number of capture interfaces is never negative');

INSERT INTO agent_capabilities (network_id, platform, elevated, capture_consent, pktmon, capture_interfaces)
SELECT network_id, 'Windows', TRUE, TRUE, TRUE, 2 FROM equipo;
SELECT pg_temp.assert_true(
    (SELECT capture_consent AND pktmon FROM agent_capabilities WHERE network_id = (SELECT network_id FROM equipo)),
    'the sensor of a team network says it may capture with pktmon');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO agent_capabilities (network_id) SELECT network_id FROM equipo$$,
    'one row per sensor of a team network');

DELETE FROM users WHERE username = 'capacidades.prueba';
SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM agent_capabilities WHERE home_network_id IS NOT NULL
                AND home_network_id NOT IN (SELECT id FROM home_networks)),
    'the capabilities of an agent of Mi Wi-Fi are deleted with the account');
DELETE FROM networks WHERE id = (SELECT network_id FROM equipo);
SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM agent_capabilities WHERE network_id = (SELECT network_id FROM equipo)),
    'the capabilities of a sensor are deleted with its team network');

ROLLBACK;
