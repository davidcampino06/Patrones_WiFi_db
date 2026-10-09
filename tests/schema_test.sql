-- Schema validation: run after migrations + seeds. Any failed assertion aborts with an error.
\set ON_ERROR_STOP on

CREATE OR REPLACE FUNCTION pg_temp.assert_true(condition BOOLEAN, description TEXT) RETURNS VOID AS $$
BEGIN
    IF NOT condition THEN
        RAISE EXCEPTION 'FAILED: %', description;
    END IF;
    RAISE NOTICE 'PASSED: %', description;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pg_temp.assert_rejected(statement TEXT, description TEXT) RETURNS VOID AS $$
BEGIN
    BEGIN
        EXECUTE statement;
    EXCEPTION WHEN integrity_constraint_violation OR check_violation OR unique_violation
                   OR foreign_key_violation OR not_null_violation THEN
        RAISE NOTICE 'PASSED: %', description;
        RETURN;
    END;
    RAISE EXCEPTION 'FAILED: % (statement was accepted)', description;
END;
$$ LANGUAGE plpgsql;

-- Structure
SELECT pg_temp.assert_true(
    (SELECT count(*) FROM information_schema.tables
     WHERE table_schema = 'public' AND table_name IN (
        'users', 'locations', 'zones', 'networks', 'devices', 'measurements', 'traffic_observations',
        'traffic_sessions', 'protocol_statistics', 'alerts', 'analysis_results', 'ai_predictions')) = 12,
    'all 12 tables exist');

SELECT pg_temp.assert_true(
    (SELECT count(*) FROM information_schema.table_constraints
     WHERE table_schema = 'public' AND constraint_type = 'FOREIGN KEY') = 13,
    'all 13 foreign keys are defined');

SELECT pg_temp.assert_true(
    EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_measurements_network_time'),
    'measurement history index exists');

-- Constraints
SELECT pg_temp.assert_rejected(
    $$INSERT INTO users (username, email, password_hash, role) VALUES ('hacker', 'h@x.io', 'x', 'ROOT')$$,
    'invalid role is rejected');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO users (username, email, password_hash) VALUES ('admin', 'other@x.io', 'x')$$,
    'duplicate username is rejected');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO networks (zone_id, ssid, bssid, frequency_band, channel, security_type)
      VALUES (999999, 'ghost', 'AA:BB:CC:DD:EE:FF', '5GHz', 36, 'WPA3')$$,
    'network with unknown zone is rejected');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO networks (zone_id, ssid, bssid, frequency_band, channel, security_type)
      SELECT id, 'bad', 'not-a-mac', '5GHz', 36, 'WPA3' FROM zones LIMIT 1$$,
    'malformed BSSID is rejected');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO measurements (network_id, latency_ms, jitter_ms, packet_loss_pct, source, measured_at)
      SELECT id, 10, 1, 150, 'SIMULATION', NOW() FROM networks LIMIT 1$$,
    'packet loss above 100 is rejected');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO measurements (network_id, latency_ms, jitter_ms, packet_loss_pct, source, measured_at)
      SELECT id, -5, 1, 0, 'SIMULATION', NOW() FROM networks LIMIT 1$$,
    'negative latency is rejected');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO alerts (network_id, severity, message, status)
      SELECT id, 'WARNING', 'x', 'RESOLVED' FROM networks LIMIT 1$$,
    'resolved alert without resolved_at is rejected');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO ai_predictions (analysis_result_id, network_id, anomaly_detected, anomaly_score, severity,
                                  message, model_version, simulated_data)
      VALUES (1, 1, TRUE, 1.7, 'HIGH', 'x', 'v1', TRUE)$$,
    'anomaly score outside [0,1] is rejected');

-- Seed data
SELECT pg_temp.assert_true((SELECT count(*) FROM users) = 3, 'three seed users (one per role)');
SELECT pg_temp.assert_true((SELECT count(*) FROM networks) = 4, 'four seed networks');
SELECT pg_temp.assert_true(
    (SELECT count(DISTINCT network_id) FROM measurements) = 4, 'every network has measurement history');
SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM measurements WHERE source <> 'SIMULATION'), 'seed measurements are marked as simulated');
