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
        'traffic_sessions', 'protocol_statistics', 'alerts', 'analysis_results', 'ai_predictions',
        'home_networks', 'connection_tests')) = 14,
    'all 14 tables exist');

SELECT pg_temp.assert_true(
    (SELECT count(*) FROM information_schema.table_constraints
     WHERE table_schema = 'public' AND constraint_type = 'FOREIGN KEY') = 15,
    'all 15 foreign keys are defined');

SELECT pg_temp.assert_true(
    EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_measurements_network_time'),
    'measurement history index exists');

-- Constraints
SELECT pg_temp.assert_rejected(
    $$INSERT INTO users (username, email, password_hash, role) VALUES ('hacker', 'h@x.io', 'x', 'ROOT')$$,
    'invalid role is rejected');
INSERT INTO users (username, email, password_hash, role) VALUES ('usuario.final', 'uf@x.io', 'x', 'USER');
SELECT pg_temp.assert_true((SELECT role FROM users WHERE username = 'usuario.final') = 'USER', 'end-user role is accepted');
DELETE FROM users WHERE username = 'usuario.final';
SELECT pg_temp.assert_rejected(
    $$INSERT INTO users (username, email, password_hash) VALUES ('dup', 'd1@x.io', 'x'), ('dup', 'd2@x.io', 'x')$$,
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

-- End-user networks
INSERT INTO users (username, email, password_hash, role) VALUES ('casa.prueba', 'cp@x.io', 'x', 'USER');
INSERT INTO home_networks (owner_id, name) SELECT id, 'Casa' FROM users WHERE username = 'casa.prueba';
SELECT pg_temp.assert_rejected(
    $$INSERT INTO home_networks (owner_id, name) SELECT id, 'CASA' FROM users WHERE username = 'casa.prueba'$$,
    'a user cannot repeat a network name (case-insensitive)');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO home_networks (owner_id, name) SELECT id, ' ' FROM users WHERE username = 'casa.prueba'$$,
    'home network name cannot be blank');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO home_networks (owner_id, name, contracted_mbps) SELECT id, 'Oficina', 0 FROM users WHERE username = 'casa.prueba'$$,
    'contracted speed must be positive');

-- Connection tests (V16)
INSERT INTO connection_tests (home_network_id, latency_ms, jitter_ms, download_mbps, upload_mbps, quality_score,
                              quality_grade, quality_details)
SELECT id, 24.5, 3.1, 180, 40, 92, 'EXCELLENT', '{"score": 92}' FROM home_networks WHERE name = 'Casa';
INSERT INTO connection_tests (home_network_id, latency_ms, jitter_ms, download_mbps, upload_mbps)
SELECT id, 40, 6, 90, 20 FROM home_networks WHERE name = 'Casa';
SELECT pg_temp.assert_true((SELECT count(*) FROM connection_tests) = 2,
    'a test is kept even when the AI could not grade it');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO connection_tests (home_network_id, latency_ms, jitter_ms, download_mbps, upload_mbps)
      SELECT id, 0, 3, 100, 10 FROM home_networks WHERE name = 'Casa'$$,
    'latency must be positive');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO connection_tests (home_network_id, latency_ms, jitter_ms, download_mbps, upload_mbps)
      SELECT id, 20, 3, 20000, 10 FROM home_networks WHERE name = 'Casa'$$,
    'speeds above 10 000 Mbps are rejected');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO connection_tests (home_network_id, latency_ms, jitter_ms, download_mbps, upload_mbps, quality_score)
      SELECT id, 20, 3, 100, 10, 80 FROM home_networks WHERE name = 'Casa'$$,
    'a score always comes with its grade');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO connection_tests (home_network_id, latency_ms, jitter_ms, download_mbps, upload_mbps, quality_score,
                                    quality_grade)
      SELECT id, 20, 3, 100, 10, 80, 'SUPER' FROM home_networks WHERE name = 'Casa'$$,
    'unknown quality grade is rejected');
DELETE FROM users WHERE username = 'casa.prueba';
SELECT pg_temp.assert_true((SELECT count(*) FROM home_networks) = 0, 'deleting a user deletes their networks');
SELECT pg_temp.assert_true((SELECT count(*) FROM connection_tests) = 0, '... and the tests of those networks');

-- Probable cause of anomalies (V15). A real analysis row is used so only the V15 checks can reject.
INSERT INTO analysis_results (network_id, analysis_type, detected_status, score, summary, measurement_count)
SELECT id, 'ANOMALY_DETECTION', 'CRITICAL', 0.7, 'v15 test', 50 FROM networks ORDER BY id LIMIT 1;
SELECT pg_temp.assert_rejected(
    $$INSERT INTO ai_predictions (analysis_result_id, network_id, anomaly_detected, anomaly_score, severity,
                                  message, model_version, simulated_data, anomaly_type)
      SELECT id, network_id, TRUE, 0.7, 'HIGH', 'x', 'v1', TRUE, 'ALIENS' FROM analysis_results WHERE summary = 'v15 test'$$,
    'unknown anomaly type is rejected');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO ai_predictions (analysis_result_id, network_id, anomaly_detected, anomaly_score, severity,
                                  message, model_version, simulated_data, anomaly_type)
      SELECT id, network_id, TRUE, 0.7, 'HIGH', 'x', 'v1', TRUE, 'NONE' FROM analysis_results WHERE summary = 'v15 test'$$,
    'a detected anomaly needs a cause other than NONE');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO ai_predictions (analysis_result_id, network_id, anomaly_detected, anomaly_score, severity,
                                  message, model_version, simulated_data, anomaly_type)
      SELECT id, network_id, FALSE, 0.2, 'NONE', 'x', 'v1', TRUE, 'CONGESTION' FROM analysis_results WHERE summary = 'v15 test'$$,
    'a normal result cannot carry a cause');
INSERT INTO ai_predictions (analysis_result_id, network_id, anomaly_detected, anomaly_score, severity, message,
                            model_version, simulated_data, anomaly_type)
SELECT id, network_id, TRUE, 0.7, 'HIGH', 'x', 'v1', TRUE, 'CONGESTION' FROM analysis_results WHERE summary = 'v15 test';
SELECT pg_temp.assert_true(
    (SELECT anomaly_type FROM ai_predictions WHERE message = 'x') = 'CONGESTION', 'a diagnosed anomaly is stored');
UPDATE ai_predictions SET anomaly_type = NULL WHERE message = 'x';
SELECT pg_temp.assert_true(
    (SELECT anomaly_type IS NULL FROM ai_predictions WHERE message = 'x'), 'older predictions may stay unclassified');
DELETE FROM analysis_results WHERE summary = 'v15 test';
SELECT pg_temp.assert_true(NOT EXISTS (SELECT 1 FROM ai_predictions WHERE message = 'x'), 'test prediction removed');
SELECT pg_temp.assert_true(
    EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_ai_predictions_anomaly_type'),
    'anomalies can be grouped by cause using an index');

-- Seed data
SELECT pg_temp.assert_true((SELECT count(*) FROM users) = 0, 'seed data creates no user accounts');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO users (username, email, password_hash) VALUES (repeat('a', 41), 'long@x.io', 'x')$$,
    'username longer than 40 characters is rejected');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO ai_predictions (analysis_result_id, network_id, anomaly_detected, anomaly_score, severity,
                                  message, model_version, simulated_data, recommendation_source)
      VALUES (1, 1, TRUE, 0.5, 'HIGH', 'x', 'v1', TRUE, 'GPT')$$,
    'unknown recommendation source is rejected');
SELECT pg_temp.assert_true((SELECT count(*) FROM networks) = 4, 'four seed networks');
SELECT pg_temp.assert_true(
    (SELECT count(DISTINCT network_id) FROM measurements) = 4, 'every network has measurement history');
SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM measurements WHERE source <> 'SIMULATION'), 'seed measurements are marked as simulated');
