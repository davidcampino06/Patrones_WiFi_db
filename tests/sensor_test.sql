-- Sensor of the team networks (V34-V35): the AGENT source, one sensor and one pending code per network, keys and
-- codes stored only as SHA-256, and everything removed with the network. Runs inside a transaction that is rolled back.
\ir _asserts.sql
BEGIN;

INSERT INTO locations (name) VALUES ('Sede Sensor Prueba');
INSERT INTO zones (location_id, name) SELECT id, 'Sala del sensor' FROM locations WHERE name = 'Sede Sensor Prueba';
INSERT INTO networks (zone_id, ssid, bssid, frequency_band, channel, security_type)
SELECT id, 'Red del sensor', 'AA:BB:CC:13:13:13', '5GHz', 36, 'WPA3' FROM zones WHERE name = 'Sala del sensor';

-- Source of the data (V34)
SELECT pg_temp.assert_true(
    (SELECT data_source_type FROM networks WHERE bssid = 'AA:BB:CC:13:13:13') = 'AGENT',
    'a new network is measured by its sensor unless something else is chosen');
SELECT pg_temp.assert_rejected(
    $$UPDATE networks SET data_source_type = 'MAGIA' WHERE bssid = 'AA:BB:CC:13:13:13'$$,
    'an unknown data source is rejected');
INSERT INTO measurements (network_id, latency_ms, jitter_ms, packet_loss_pct, source, measured_at)
SELECT id, 18.5, 2.1, 0, 'AGENT', NOW() FROM networks WHERE bssid = 'AA:BB:CC:13:13:13';
SELECT pg_temp.assert_true(
    (SELECT count(*) FROM measurements m JOIN networks n ON n.id = m.network_id
     WHERE n.bssid = 'AA:BB:CC:13:13:13' AND m.source = 'AGENT') = 1,
    'a measurement taken by the sensor is accepted');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO measurements (network_id, latency_ms, jitter_ms, packet_loss_pct, source, measured_at)
      SELECT id, 1, 1, 0, 'INVENTADA', NOW() FROM networks WHERE bssid = 'AA:BB:CC:13:13:13'$$,
    'a measurement from an unknown source is rejected');

-- Sensors (V35)
INSERT INTO network_sensors (network_id, key_hash, key_prefix)
SELECT id, repeat('1a', 32), 'wsa_Ab12' FROM networks WHERE bssid = 'AA:BB:CC:13:13:13';
SELECT pg_temp.assert_rejected(
    $$INSERT INTO network_sensors (network_id, key_hash, key_prefix)
      SELECT id, repeat('2b', 32), 'wsa_Cd34' FROM networks WHERE bssid = 'AA:BB:CC:13:13:13'$$,
    'a network has one sensor');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO network_sensors (network_id, key_hash, key_prefix) VALUES (999999, repeat('3c', 32), 'wsa_Ef56')$$,
    'a sensor needs an existing network');
SELECT pg_temp.assert_rejected(
    $$UPDATE network_sensors SET key_hash = 'clave-en-texto-plano' WHERE key_prefix = 'wsa_Ab12'$$,
    'only the SHA-256 of the key is stored');
SELECT pg_temp.assert_rejected(
    $$UPDATE network_sensors SET key_prefix = 'otra_cosa' WHERE key_prefix = 'wsa_Ab12'$$,
    'the visible start of the key has the agent format');
SELECT pg_temp.assert_rejected(
    $$UPDATE network_sensors SET agent_version = 'v1; DROP TABLE x' WHERE key_prefix = 'wsa_Ab12'$$,
    'the agent version is a plain version number');

-- Pairing codes (V35)
INSERT INTO network_sensor_pairing_codes (network_id, code_hash, expires_at)
SELECT id, repeat('4d', 32), NOW() + INTERVAL '15 minutes' FROM networks WHERE bssid = 'AA:BB:CC:13:13:13';
SELECT pg_temp.assert_rejected(
    $$INSERT INTO network_sensor_pairing_codes (network_id, code_hash, expires_at)
      SELECT id, repeat('5e', 32), NOW() + INTERVAL '15 minutes' FROM networks WHERE bssid = 'AA:BB:CC:13:13:13'$$,
    'a network has at most one pending code');
SELECT pg_temp.assert_rejected(
    $$UPDATE network_sensor_pairing_codes SET expires_at = created_at + INTERVAL '2 hours'$$,
    'a code cannot live more than an hour');

-- Deleting the network removes its sensor, its code and its measurements
DELETE FROM networks WHERE bssid = 'AA:BB:CC:13:13:13';
SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM network_sensors WHERE key_prefix = 'wsa_Ab12')
    AND NOT EXISTS (SELECT 1 FROM network_sensor_pairing_codes WHERE code_hash = repeat('4d', 32)),
    'deleting a network deletes its sensor and its pending code');

ROLLBACK;
