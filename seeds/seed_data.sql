-- Demo data. All measurements are SIMULATED (source = 'SIMULATION').
BEGIN;

SELECT setseed(0.42);

-- No user accounts here: the backend creates them (see README).

INSERT INTO locations (name, address, city) VALUES
    ('Main Campus', 'Calle 18 # 50-02', 'Pasto'),
    ('Downtown Office', 'Carrera 25 # 17-40', 'Pasto');

INSERT INTO zones (location_id, name, floor)
SELECT l.id, z.name, z.floor
FROM (VALUES
    ('Main Campus', 'Library', 1),
    ('Main Campus', 'Engineering Building', 2),
    ('Main Campus', 'Cafeteria', 1),
    ('Downtown Office', 'Open Space', 3)
) AS z(location_name, name, floor)
JOIN locations l ON l.name = z.location_name;

INSERT INTO networks (zone_id, ssid, bssid, frequency_band, channel, security_type, status)
SELECT z.id, n.ssid, n.bssid, n.band, n.channel, n.security, n.status
FROM (VALUES
    ('Library',              'WiFiSense-Library',  'A4:2B:B0:10:00:01', '5GHz',   36, 'WPA3',            'NORMAL'),
    ('Engineering Building', 'WiFiSense-Labs',     'A4:2B:B0:10:00:02', '5GHz',   44, 'WPA2_ENTERPRISE', 'NORMAL'),
    ('Cafeteria',            'WiFiSense-Guest',    'A4:2B:B0:10:00:03', '2.4GHz',  6, 'OPEN',            'WARNING'),
    ('Open Space',           'WiFiSense-Office',   'A4:2B:B0:10:00:04', '6GHz',   37, 'WPA3',            'NORMAL')
) AS n(zone_name, ssid, bssid, band, channel, security, status)
JOIN zones z ON z.name = n.zone_name;

-- 24h of measurements every 15 minutes; the guest network is noisier and degraded.
INSERT INTO measurements (network_id, latency_ms, jitter_ms, packet_loss_pct, bandwidth_mbps,
                          signal_strength_dbm, connected_devices, source, measured_at)
SELECT n.id,
       round((p.base_latency + random() * p.base_latency * 0.4)::numeric, 2),
       round((p.base_jitter + random() * p.base_jitter)::numeric, 2),
       round(LEAST(100, p.base_loss * random() * 2)::numeric, 2),
       round((p.base_bandwidth * (0.8 + random() * 0.3))::numeric, 2),
       (p.base_signal - floor(random() * 8))::int,
       (p.base_devices + floor(random() * 10))::int,
       'SIMULATION',
       NOW() - (s.step * INTERVAL '15 minutes')
FROM networks n
JOIN (VALUES
    ('WiFiSense-Library', 18.0, 3.0, 0.3, 320.0, -52, 25),
    ('WiFiSense-Labs',    22.0, 4.0, 0.5, 280.0, -58, 40),
    ('WiFiSense-Guest',   65.0, 15.0, 3.5, 45.0, -71, 60),
    ('WiFiSense-Office',  12.0, 2.0, 0.1, 650.0, -48, 15)
) AS p(ssid, base_latency, base_jitter, base_loss, base_bandwidth, base_signal, base_devices) ON p.ssid = n.ssid
CROSS JOIN generate_series(1, 96) AS s(step);

INSERT INTO traffic_observations (network_id, traffic_volume_mb, packet_count, observed_at)
SELECT n.id,
       round((80 + random() * 400)::numeric, 2),
       (60000 + floor(random() * 300000))::bigint,
       NOW() - (s.step * INTERVAL '15 minutes')
FROM networks n
CROSS JOIN generate_series(1, 96) AS s(step);

INSERT INTO protocol_statistics (network_id, protocol, packet_count, period_start, period_end)
SELECT n.id, p.protocol, (p.share * (200000 + floor(random() * 50000)))::bigint,
       date_trunc('hour', NOW()) - INTERVAL '1 hour', date_trunc('hour', NOW())
FROM networks n
CROSS JOIN (VALUES ('HTTPS', 0.62), ('DNS', 0.08), ('QUIC', 0.18), ('HTTP', 0.05), ('OTHER', 0.07)) AS p(protocol, share);

INSERT INTO devices (network_id, hostname, ip_address, mac_address, device_type, connection_status, signal_strength)
SELECT n.id, d.hostname, d.ip, d.mac, d.type, d.status, d.signal
FROM (VALUES
    ('WiFiSense-Library', 'lib-ap-01',      '10.10.1.1',  'F0:9F:C2:00:00:01', 'ACCESS_POINT', 'CONNECTED',    -40),
    ('WiFiSense-Library', 'student-laptop', '10.10.1.23', '3C:22:FB:00:00:11', 'LAPTOP',       'CONNECTED',    -55),
    ('WiFiSense-Labs',    'lab-pc-07',      '10.10.2.7',  '3C:22:FB:00:00:12', 'LAPTOP',       'IDLE',         -61),
    ('WiFiSense-Labs',    'temp-sensor-1',  '10.10.2.90', 'B8:27:EB:00:00:13', 'IOT',          'CONNECTED',    -67),
    ('WiFiSense-Guest',   'guest-phone',    '10.10.3.45', '9C:B6:D0:00:00:14', 'PHONE',        'CONNECTED',    -74),
    ('WiFiSense-Guest',   'guest-tablet',   '10.10.3.46', '9C:B6:D0:00:00:15', 'TABLET',       'DISCONNECTED', -82),
    ('WiFiSense-Office',  'office-laptop',  '10.20.0.10', '3C:22:FB:00:00:16', 'LAPTOP',       'CONNECTED',    -47)
) AS d(ssid, hostname, ip, mac, type, status, signal)
JOIN networks n ON n.ssid = d.ssid;

INSERT INTO traffic_sessions (device_id, protocol, destination_port, bytes_sent, bytes_received, started_at, ended_at)
SELECT d.id, s.protocol, s.port,
       (10000 + floor(random() * 5000000))::bigint,
       (50000 + floor(random() * 50000000))::bigint,
       NOW() - INTERVAL '2 hours' + (s.offset_min * INTERVAL '1 minute'),
       NOW() - INTERVAL '2 hours' + ((s.offset_min + 20) * INTERVAL '1 minute')
FROM devices d
CROSS JOIN (VALUES ('HTTPS', 443, 0), ('DNS', 53, 5), ('QUIC', 443, 30)) AS s(protocol, port, offset_min)
WHERE d.device_type <> 'ACCESS_POINT';

INSERT INTO alerts (network_id, severity, message, status)
SELECT id, 'WARNING', 'La red entró en estado de advertencia', 'OPEN'
FROM networks WHERE ssid = 'WiFiSense-Guest';

COMMIT;
