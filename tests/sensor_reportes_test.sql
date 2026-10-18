-- What the sensor of a team network sees (V36): its reports with the AI verdicts and the devices of the network,
-- known only by a salted fingerprint. Everything is removed with the network. Runs inside a transaction that is
-- rolled back.
\ir _asserts.sql
BEGIN;

INSERT INTO locations (name) VALUES ('Sede Reportes Prueba');
INSERT INTO zones (location_id, name) SELECT id, 'Sala de reportes' FROM locations WHERE name = 'Sede Reportes Prueba';
INSERT INTO networks (zone_id, ssid, bssid, frequency_band, channel, security_type)
SELECT id, 'Red con reportes', 'AA:BB:CC:14:14:14', '2.4GHz', 6, 'WPA2' FROM zones WHERE name = 'Sala de reportes';

-- Reports
INSERT INTO network_sensor_reports (network_id, agent_version, ssid, authentication, band, channel, signal_dbm,
                                    latency_ms, jitter_ms, packet_loss_pct, device_count, new_device_count,
                                    security_score, security_grade, quality_score, details)
SELECT id, '1.5.0', 'Red con reportes', 'WPA2', '2.4', 6, -58, 21.5, 2.0, 0, 7, 1, 74, 'ACCEPTABLE', 88,
       '{"openPorts": [80], "security": {"score": 74}}'
FROM networks WHERE bssid = 'AA:BB:CC:14:14:14';
SELECT pg_temp.assert_true(
    (SELECT security_grade FROM network_sensor_reports r JOIN networks n ON n.id = r.network_id
     WHERE n.bssid = 'AA:BB:CC:14:14:14') = 'ACCEPTABLE',
    'a sensor report with its security audit is accepted');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO network_sensor_reports (network_id, agent_version, device_count, new_device_count)
      SELECT id, '1.5.0', 2, 5 FROM networks WHERE bssid = 'AA:BB:CC:14:14:14'$$,
    'a report cannot have more new devices than devices');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO network_sensor_reports (network_id, agent_version, device_count, security_score)
      SELECT id, '1.5.0', 2, 80 FROM networks WHERE bssid = 'AA:BB:CC:14:14:14'$$,
    'a security score always comes with its grade');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO network_sensor_reports (network_id, agent_version, device_count, details)
      SELECT id, '1.5.0', 2, '[1, 2]' FROM networks WHERE bssid = 'AA:BB:CC:14:14:14'$$,
    'the details of a report are a JSON object');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO network_sensor_reports (network_id, agent_version, device_count) VALUES (999999, '1.5.0', 1)$$,
    'a report needs an existing team network');

-- Devices
INSERT INTO network_sensor_devices (network_id, fingerprint, vendor, hostname, private_mac)
SELECT id, 'a1b2c3d4e5f6a1b2c3d4e5f6', 'Apple', 'MacBook-Lab', FALSE FROM networks WHERE bssid = 'AA:BB:CC:14:14:14';
SELECT pg_temp.assert_rejected(
    $$INSERT INTO network_sensor_devices (network_id, fingerprint)
      SELECT id, 'a1b2c3d4e5f6a1b2c3d4e5f6' FROM networks WHERE bssid = 'AA:BB:CC:14:14:14'$$,
    'a device appears once per network');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO network_sensor_devices (network_id, fingerprint)
      SELECT id, 'AA:BB:CC:DD:EE:FF' FROM networks WHERE bssid = 'AA:BB:CC:14:14:14'$$,
    'a MAC address is never stored, only its fingerprint');
SELECT pg_temp.assert_rejected(
    $$UPDATE network_sensor_devices SET label = '   ' WHERE fingerprint = 'a1b2c3d4e5f6a1b2c3d4e5f6'$$,
    'a device name is not blank');
SELECT pg_temp.assert_rejected(
    $$UPDATE network_sensor_devices SET last_seen_at = first_seen_at - INTERVAL '1 day'
      WHERE fingerprint = 'a1b2c3d4e5f6a1b2c3d4e5f6'$$,
    'a device is not seen before its first time');
UPDATE network_sensor_devices SET authorized = FALSE, label = 'Portátil del laboratorio'
WHERE fingerprint = 'a1b2c3d4e5f6a1b2c3d4e5f6';
SELECT pg_temp.assert_true(
    (SELECT NOT authorized FROM network_sensor_devices WHERE fingerprint = 'a1b2c3d4e5f6a1b2c3d4e5f6'),
    'an administrator can name a device and mark it as not authorized');

-- Deleting the network removes its reports and devices
DELETE FROM networks WHERE bssid = 'AA:BB:CC:14:14:14';
SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM network_sensor_devices WHERE fingerprint = 'a1b2c3d4e5f6a1b2c3d4e5f6')
    AND NOT EXISTS (SELECT 1 FROM network_sensor_reports WHERE agent_version = '1.5.0'),
    'deleting a network deletes its sensor reports and devices');

ROLLBACK;
