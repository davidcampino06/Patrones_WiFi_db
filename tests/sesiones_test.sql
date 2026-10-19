-- When each device was connected (V37): periods of Mi Wi-Fi devices and of the devices a sensor sees. A device has at
-- most one open period, a period never ends before it was last seen, and everything goes with its device. Runs
-- inside a transaction that is rolled back.
\ir _asserts.sql
BEGIN;

INSERT INTO users (username, email, password_hash, role) VALUES ('sesiones.prueba', 'sp@x.io', 'x', 'USER');
INSERT INTO home_networks (owner_id, name) SELECT id, 'Casa sesiones' FROM users WHERE username = 'sesiones.prueba';
INSERT INTO agent_devices (home_network_id, fingerprint)
SELECT id, 'aaaabbbbccccddddeeeeffff' FROM home_networks WHERE name = 'Casa sesiones';

-- Mi Wi-Fi
INSERT INTO agent_device_sessions (home_network_id, fingerprint, connected_at, last_seen_at)
SELECT id, 'aaaabbbbccccddddeeeeffff', NOW() - INTERVAL '1 hour', NOW() FROM home_networks WHERE name = 'Casa sesiones';
SELECT pg_temp.assert_rejected(
    $$INSERT INTO agent_device_sessions (home_network_id, fingerprint, connected_at, last_seen_at)
      SELECT id, 'aaaabbbbccccddddeeeeffff', NOW(), NOW() FROM home_networks WHERE name = 'Casa sesiones'$$,
    'a device has only one open period');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO agent_device_sessions (home_network_id, fingerprint, connected_at, last_seen_at)
      SELECT id, '000000000000000000000000', NOW(), NOW() FROM home_networks WHERE name = 'Casa sesiones'$$,
    'a period belongs to a known device');
SELECT pg_temp.assert_rejected(
    $$UPDATE agent_device_sessions SET disconnected_at = connected_at - INTERVAL '1 minute'
      WHERE fingerprint = 'aaaabbbbccccddddeeeeffff'$$,
    'a period does not end before the device was last seen');
UPDATE agent_device_sessions SET disconnected_at = last_seen_at WHERE fingerprint = 'aaaabbbbccccddddeeeeffff';
INSERT INTO agent_device_sessions (home_network_id, fingerprint, connected_at, last_seen_at)
SELECT id, 'aaaabbbbccccddddeeeeffff', NOW(), NOW() FROM home_networks WHERE name = 'Casa sesiones';
SELECT pg_temp.assert_true(
    (SELECT count(*) FROM agent_device_sessions WHERE fingerprint = 'aaaabbbbccccddddeeeeffff') = 2,
    'once a period is closed the device can connect again');
DELETE FROM agent_devices WHERE fingerprint = 'aaaabbbbccccddddeeeeffff';
SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM agent_device_sessions WHERE fingerprint = 'aaaabbbbccccddddeeeeffff'),
    'deleting a device deletes its periods');

-- Team network seen by its sensor
INSERT INTO locations (name) VALUES ('Sede Sesiones Prueba');
INSERT INTO zones (location_id, name) SELECT id, 'Sala' FROM locations WHERE name = 'Sede Sesiones Prueba';
INSERT INTO networks (zone_id, ssid, bssid, frequency_band, channel, security_type)
SELECT id, 'Red sesiones', 'AA:BB:CC:15:15:15', '5GHz', 36, 'WPA2' FROM zones WHERE name = 'Sala';
INSERT INTO network_sensor_devices (network_id, fingerprint)
SELECT id, '111122223333444455556666' FROM networks WHERE bssid = 'AA:BB:CC:15:15:15';
INSERT INTO network_sensor_device_sessions (network_id, fingerprint, connected_at, last_seen_at)
SELECT id, '111122223333444455556666', NOW() - INTERVAL '10 minutes', NOW() FROM networks WHERE bssid = 'AA:BB:CC:15:15:15';
SELECT pg_temp.assert_rejected(
    $$INSERT INTO network_sensor_device_sessions (network_id, fingerprint, connected_at, last_seen_at)
      SELECT id, '111122223333444455556666', NOW(), NOW() FROM networks WHERE bssid = 'AA:BB:CC:15:15:15'$$,
    'a device of a team network has only one open period');
SELECT pg_temp.assert_rejected(
    $$UPDATE network_sensor_device_sessions SET last_seen_at = connected_at - INTERVAL '1 minute'
      WHERE fingerprint = '111122223333444455556666'$$,
    'a period is not last seen before it started');
DELETE FROM networks WHERE bssid = 'AA:BB:CC:15:15:15';
SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM network_sensor_device_sessions WHERE fingerprint = '111122223333444455556666'),
    'deleting a team network deletes the periods of its devices');

ROLLBACK;
