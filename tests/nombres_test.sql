-- Where the name of a device came from (V42): only the four known sources, and never a source without a name, for
-- the devices of Mi Wi-Fi and of the sensors of the team networks. Runs inside a transaction that is rolled back.
\ir _asserts.sql
BEGIN;

INSERT INTO users (username, email, password_hash, role) VALUES ('nombres.prueba', 'np@x.io', 'x', 'USER');
INSERT INTO home_networks (owner_id, name) SELECT id, 'Casa nombres' FROM users WHERE username = 'nombres.prueba';
CREATE TEMP TABLE casa AS SELECT id AS network_id FROM home_networks WHERE name = 'Casa nombres';

INSERT INTO agent_devices (home_network_id, fingerprint, hostname, name_source)
SELECT network_id, 'aaaa0000bbbb1111cccc2222', 'Portatil-de-Ana', 'CONFIRMED' FROM casa;
INSERT INTO agent_devices (home_network_id, fingerprint, hostname, name_source)
SELECT network_id, 'aaaa0000bbbb1111cccc3333', 'Galaxy-A54', 'ROUTER' FROM casa;
INSERT INTO agent_devices (home_network_id, fingerprint, vendor)
SELECT network_id, 'aaaa0000bbbb1111cccc4444', 'Samsung' FROM casa;
SELECT pg_temp.assert_true(
    (SELECT count(*) FROM agent_devices WHERE home_network_id = (SELECT network_id FROM casa)) = 3,
    'a device keeps where its name came from, and a device without a name has no source');
SELECT pg_temp.assert_true(
    (SELECT name_source FROM agent_devices WHERE fingerprint = 'aaaa0000bbbb1111cccc4444') IS NULL,
    'the maker alone is an estimate, not a name: no source');
SELECT pg_temp.assert_rejected(
    $$UPDATE agent_devices SET name_source = 'GUESS' WHERE fingerprint = 'aaaa0000bbbb1111cccc2222'$$,
    'the source of a name is CONFIRMED, ANNOUNCED, ROUTER or DNS');
SELECT pg_temp.assert_rejected(
    $$UPDATE agent_devices SET name_source = 'ANNOUNCED' WHERE fingerprint = 'aaaa0000bbbb1111cccc4444'$$,
    'a source without a name is rejected');
SELECT pg_temp.assert_rejected(
    $$UPDATE agent_devices SET hostname = NULL WHERE fingerprint = 'aaaa0000bbbb1111cccc3333'$$,
    'a name cannot be removed while its source stays');
UPDATE agent_devices SET hostname = NULL, name_source = NULL WHERE fingerprint = 'aaaa0000bbbb1111cccc3333';
SELECT pg_temp.assert_true(
    (SELECT hostname IS NULL AND name_source IS NULL FROM agent_devices
     WHERE fingerprint = 'aaaa0000bbbb1111cccc3333'),
    'a name and its source are removed together');

ROLLBACK;
