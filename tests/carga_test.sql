-- Load test of the database: a month of real use of three team networks (a sensor reporting every 5 minutes, about
-- 26 000 measurements per network, half of them with traffic) and 200 devices with their connection periods. The
-- queries the backend runs most often must use an index and answer within a generous time even on a slow CI
-- machine. Runs inside a transaction that is rolled back: it leaves the database exactly as it was.
\ir _asserts.sql
BEGIN;

-- Median time of a query in milliseconds, over a few runs (the first run warms the cache and is not counted).
CREATE OR REPLACE FUNCTION pg_temp.ms_of(query TEXT, runs INTEGER DEFAULT 5) RETURNS NUMERIC AS $$
DECLARE
    started TIMESTAMPTZ;
    times NUMERIC[] := '{}';
BEGIN
    EXECUTE query;
    FOR i IN 1..runs LOOP
        started := clock_timestamp();
        EXECUTE query;
        times := times || (EXTRACT(EPOCH FROM clock_timestamp() - started) * 1000)::NUMERIC;
    END LOOP;
    RETURN (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY t) FROM unnest(times) t);
END;
$$ LANGUAGE plpgsql;

INSERT INTO locations (name) VALUES ('Sede Carga Prueba');
INSERT INTO zones (location_id, name) SELECT id, 'Piso carga' FROM locations WHERE name = 'Sede Carga Prueba';
INSERT INTO networks (zone_id, ssid, bssid, frequency_band, channel, security_type, data_source_type)
SELECT z.id, 'Red carga ' || n, 'AA:BB:CC:17:17:1' || n, '5GHz', 36, 'WPA2', 'AGENT'
FROM zones z CROSS JOIN generate_series(1, 3) n WHERE z.name = 'Piso carga';

-- 30 days every 5 minutes for each network (8 640 per network per month, x3 to simulate a busier year-end month).
INSERT INTO measurements (network_id, latency_ms, jitter_ms, packet_loss_pct, signal_strength_dbm, connected_devices,
                          source, measured_at)
SELECT n.id, 20 + random() * 40, 1 + random() * 6, random() * 0.5, -45 - (random() * 25)::INT, 3 + (random() * 15)::INT,
       'AGENT', NOW() - (i * INTERVAL '100 seconds')
FROM networks n CROSS JOIN generate_series(1, 26000) i WHERE n.ssid LIKE 'Red carga %';
INSERT INTO traffic_observations (network_id, traffic_volume_mb, packet_count, observed_at)
SELECT network_id, random() * 100, (random() * 9000)::BIGINT, measured_at
FROM measurements m JOIN networks n ON n.id = m.network_id WHERE n.ssid LIKE 'Red carga %' AND m.id % 2 = 0;

INSERT INTO network_sensor_devices (network_id, fingerprint, kind, first_seen_at, last_seen_at)
SELECT n.id, lpad(to_hex(n.id * 1000 + d), 24, '0'), 'PHONE', NOW() - INTERVAL '30 days', NOW()
FROM networks n CROSS JOIN generate_series(1, 200) d WHERE n.ssid LIKE 'Red carga %';
INSERT INTO network_sensor_device_sessions (network_id, fingerprint, connected_at, last_seen_at, disconnected_at)
SELECT dev.network_id, dev.fingerprint, NOW() - (p * INTERVAL '6 hours') - INTERVAL '2 hours',
       NOW() - (p * INTERVAL '6 hours'), NOW() - (p * INTERVAL '6 hours')
FROM network_sensor_devices dev JOIN networks n ON n.id = dev.network_id CROSS JOIN generate_series(1, 25) p
WHERE n.ssid LIKE 'Red carga %';
ANALYZE measurements;
ANALYZE traffic_observations;
ANALYZE network_sensor_devices;
ANALYZE network_sensor_device_sessions;

SELECT pg_temp.assert_true(
    (SELECT count(*) FROM measurements m JOIN networks n ON n.id = m.network_id WHERE n.ssid LIKE 'Red carga %') = 78000,
    '78 000 measurements of three networks loaded');

-- The panel of a network: its latest 50 measurements.
SELECT pg_temp.assert_true(
    pg_temp.plan_of($$SELECT * FROM measurements WHERE network_id = (SELECT min(id) FROM networks WHERE ssid LIKE 'Red carga %')
                     ORDER BY measured_at DESC LIMIT 50$$) LIKE '%idx_measurements_network_time%',
    'the latest measurements of a network are read through idx_measurements_network_time');
SELECT round(pg_temp.ms_of($$SELECT * FROM measurements WHERE network_id = (SELECT min(id) FROM networks WHERE ssid LIKE 'Red carga %')
                   ORDER BY measured_at DESC LIMIT 50$$), 1) AS ms \gset
SELECT pg_temp.assert_true(:ms < 50, format('%s (%s ms)', 'the latest 50 measurements of a network take less than 50 ms', :ms));

-- The weekly report: one week of a network grouped by day of Colombia.
SELECT round(pg_temp.ms_of($$SELECT (measured_at AT TIME ZONE 'America/Bogota')::DATE, count(*), avg(latency_ms), avg(packet_loss_pct)
                   FROM measurements WHERE network_id = (SELECT min(id) FROM networks WHERE ssid LIKE 'Red carga %')
                     AND measured_at >= NOW() - INTERVAL '7 days' GROUP BY 1$$), 1) AS ms \gset
SELECT pg_temp.assert_true(:ms < 300, format('%s (%s ms)', 'the week of a network grouped by day takes less than 300 ms', :ms));

-- The traffic of the same window (crossed by time with the measurements).
SELECT pg_temp.assert_true(
    pg_temp.plan_of($$SELECT * FROM traffic_observations WHERE network_id = (SELECT min(id) FROM networks WHERE ssid LIKE 'Red carga %')
                     ORDER BY observed_at DESC LIMIT 50$$) LIKE '%idx_traffic_observations_network_time%',
    'the latest traffic of a network is read through idx_traffic_observations_network_time');

-- The devices of a network and the connection history of one of them.
SELECT round(pg_temp.ms_of($$SELECT * FROM network_sensor_devices WHERE network_id = (SELECT min(id) FROM networks WHERE ssid LIKE 'Red carga %')
                   ORDER BY first_seen_at$$), 1) AS ms \gset
SELECT pg_temp.assert_true(:ms < 50, format('%s (%s ms)', 'the 200 devices of a network take less than 50 ms', :ms));
SELECT round(pg_temp.ms_of($$SELECT * FROM network_sensor_device_sessions s
                   WHERE (s.network_id, s.fingerprint) = (SELECT network_id, fingerprint FROM network_sensor_devices
                                                          WHERE kind = 'PHONE' ORDER BY network_id DESC LIMIT 1)
                     AND s.connected_at >= NOW() - INTERVAL '7 days' ORDER BY s.connected_at DESC$$), 1) AS ms \gset
SELECT pg_temp.assert_true(:ms < 50, format('%s (%s ms)', 'the 7-day history of one device takes less than 50 ms', :ms));

-- The data set of the AI training (the same query as the backend): the latest 10 000 real measurements of 30 days.
SELECT round(pg_temp.ms_of($$SELECT * FROM (
                       SELECT m.measured_at AS at, m.latency_ms, m.jitter_ms, t.traffic_volume_mb
                       FROM measurements m
                       LEFT JOIN LATERAL (SELECT o.traffic_volume_mb FROM traffic_observations o
                                          WHERE o.network_id = m.network_id AND o.observed_at = m.measured_at LIMIT 1) t ON TRUE
                       WHERE m.source = 'AGENT' AND m.measured_at >= NOW() - INTERVAL '30 days') s
                   ORDER BY at DESC LIMIT 10000$$, 3), 1) AS ms \gset
SELECT pg_temp.assert_true(:ms < 2000, format('%s (%s ms)', 'the AI training data set (10 000 measurements with their traffic) takes less than 2 s', :ms));

-- The nightly cleanup of 90-day-old data finds the old rows by date, without reading the whole table.
SELECT round(pg_temp.ms_of($$SELECT count(*) FROM measurements WHERE measured_at < NOW() - INTERVAL '90 days'$$), 1) AS ms \gset
SELECT pg_temp.assert_true(:ms < 50, format('%s (%s ms)', 'finding measurements older than 90 days takes less than 50 ms', :ms));

ROLLBACK;
