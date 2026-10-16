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
        'home_networks', 'connection_tests', 'agent_keys', 'agent_reports', 'agent_devices', 'password_reset_tokens',
        'agent_pairing_codes')) = 19,
    'all 19 tables exist');

SELECT pg_temp.assert_true(
    (SELECT count(*) FROM information_schema.table_constraints
     WHERE table_schema = 'public' AND constraint_type = 'FOREIGN KEY') = 20,
    'all 20 foreign keys are defined');

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
-- Agent (V17-V19)
INSERT INTO agent_keys (home_network_id, key_hash, key_prefix)
SELECT id, repeat('ab', 32), 'wsa_AbC1' FROM home_networks WHERE name = 'Casa';
SELECT pg_temp.assert_rejected(
    $$INSERT INTO agent_keys (home_network_id, key_hash, key_prefix)
      SELECT id, repeat('cd', 32), 'wsa_XyZ9' FROM home_networks WHERE name = 'Casa'$$,
    'a network has a single agent key');
SELECT pg_temp.assert_rejected(
    $$UPDATE agent_keys SET key_hash = 'wsa_la-clave-en-texto-plano-no-se-guarda-nunca-aqui-0000000000'$$,
    'only the SHA-256 of the key is stored');
SELECT pg_temp.assert_rejected(
    $$UPDATE agent_keys SET key_prefix = 'Bearer'$$, 'key prefix keeps its format');

INSERT INTO agent_reports (home_network_id, agent_version, ssid, authentication, band, channel, signal_dbm, latency_ms,
                           jitter_ms, packet_loss_pct, device_count, new_device_count, security_score, security_grade,
                           quality_score, anomaly_detected, anomaly_type, details)
SELECT id, '1.0.0', 'Casa', 'WPA2', '5', 44, -58, 21.5, 2.1, 0, 7, 1, 90, 'SECURE', 88, FALSE, 'NONE',
       '{"openPorts": [53, 80, 443]}' FROM home_networks WHERE name = 'Casa';
INSERT INTO agent_reports (home_network_id, agent_version, device_count)
SELECT id, '1.0.0', 1 FROM home_networks WHERE name = 'Casa';
SELECT pg_temp.assert_true((SELECT count(*) FROM agent_reports) = 2,
    'a report is kept even when the agent could not read the Wi-Fi and the AI was unavailable');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO agent_reports (home_network_id, agent_version, device_count, authentication)
      SELECT id, '1.0.0', 3, 'WPA9' FROM home_networks WHERE name = 'Casa'$$,
    'unknown authentication is rejected');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO agent_reports (home_network_id, agent_version, device_count, new_device_count)
      SELECT id, '1.0.0', 2, 5 FROM home_networks WHERE name = 'Casa'$$,
    'there cannot be more new devices than devices');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO agent_reports (home_network_id, agent_version, device_count, security_score)
      SELECT id, '1.0.0', 2, 70 FROM home_networks WHERE name = 'Casa'$$,
    'a security score always comes with its grade');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO agent_reports (home_network_id, agent_version, device_count, anomaly_detected, anomaly_type)
      SELECT id, '1.0.0', 2, FALSE, 'CONGESTION' FROM home_networks WHERE name = 'Casa'$$,
    'a normal report cannot carry an anomaly cause');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO agent_reports (home_network_id, agent_version, device_count, signal_dbm)
      SELECT id, '1.0.0', 2, 12 FROM home_networks WHERE name = 'Casa'$$,
    'signal must be between -100 and 0 dBm');

INSERT INTO agent_devices (home_network_id, fingerprint, label)
SELECT id, '0123456789abcdef01234567', 'Celular' FROM home_networks WHERE name = 'Casa';
SELECT pg_temp.assert_rejected(
    $$INSERT INTO agent_devices (home_network_id, fingerprint)
      SELECT id, '9c:a2:f4:00:00:02' FROM home_networks WHERE name = 'Casa'$$,
    'a MAC address is never stored, only its fingerprint');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO agent_devices (home_network_id, fingerprint)
      SELECT id, '0123456789abcdef01234567' FROM home_networks WHERE name = 'Casa'$$,
    'a device is registered once per network');
SELECT pg_temp.assert_rejected(
    $$UPDATE agent_devices SET label = '   '$$, 'device name cannot be blank');

-- Account recovery (V20, V21)
UPDATE users SET phone = '+573001234567' WHERE username = 'casa.prueba';
SELECT pg_temp.assert_rejected(
    $$UPDATE users SET phone = '300 123 4567' WHERE username = 'casa.prueba'$$,
    'phone must be in international format');
SELECT pg_temp.assert_true(
    EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_users_email_lower'), 'email lookup ignores case');
INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
SELECT id, repeat('ef', 32), NOW() + INTERVAL '30 minutes' FROM users WHERE username = 'casa.prueba';
SELECT pg_temp.assert_rejected(
    $$INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
      SELECT id, 'el-enlace-en-texto-plano-nunca-se-guarda-en-la-base-de-datos-00', NOW() + INTERVAL '30 minutes'
      FROM users WHERE username = 'casa.prueba'$$,
    'only the SHA-256 of a reset link is stored');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO password_reset_tokens (user_id, token_hash, created_at, expires_at)
      SELECT id, repeat('aa', 32), NOW(), NOW() - INTERVAL '1 minute' FROM users WHERE username = 'casa.prueba'$$,
    'a reset link cannot expire before it is created');

-- Agent pairing codes (V22)
INSERT INTO agent_pairing_codes (home_network_id, code_hash, expires_at)
SELECT id, repeat('12', 32), NOW() + INTERVAL '15 minutes' FROM home_networks WHERE name = 'Casa';
SELECT pg_temp.assert_rejected(
    $$INSERT INTO agent_pairing_codes (home_network_id, code_hash, expires_at)
      SELECT id, repeat('34', 32), NOW() + INTERVAL '15 minutes' FROM home_networks WHERE name = 'Casa'$$,
    'a network has a single pending pairing code');
SELECT pg_temp.assert_rejected(
    $$UPDATE agent_pairing_codes SET expires_at = created_at + INTERVAL '2 days'$$,
    'a pairing code lives at most one hour');

DELETE FROM users WHERE username = 'casa.prueba';
SELECT pg_temp.assert_true((SELECT count(*) FROM home_networks) = 0, 'deleting a user deletes their networks');
SELECT pg_temp.assert_true((SELECT count(*) FROM connection_tests) = 0, '... and the tests of those networks');
SELECT pg_temp.assert_true((SELECT count(*) FROM agent_keys) + (SELECT count(*) FROM agent_reports)
                           + (SELECT count(*) FROM agent_devices) = 0, '... and their agent key, reports and devices');
SELECT pg_temp.assert_true((SELECT count(*) FROM password_reset_tokens) + (SELECT count(*) FROM agent_pairing_codes) = 0,
    '... and their reset links and pairing codes');

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
