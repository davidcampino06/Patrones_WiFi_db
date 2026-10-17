-- Data like the one already in production before Avance 11 (Railway), used by actualizacion_test.sh: the new
-- migrations must take it without losing a row. It includes the cases they change: emails with capitals or spaces
-- (accounts without email got "<Username>@wifisense.local"), resolved alerts, analyses requested by a team member,
-- agent reports and devices. Load it after the migrations up to V25 and the seed data.
\set ON_ERROR_STOP on
BEGIN;

INSERT INTO users (username, email, password_hash, role, phone) VALUES
    ('jefe.local', 'jefe.local@wifisense.local', '$2a$10$hash', 'ADMIN', NULL),
    ('Analista.Uno', 'Analista.Uno@wifisense.local', '$2a$10$hash', 'ANALYST', NULL),
    ('Pedro', 'Pedro@wifisense.local', '$2a$10$hash', 'USER', NULL),
    ('ana.lopez@gmail.com', 'ana.lopez@gmail.com', '$2a$10$hash', 'USER', '+573001234567'),
    ('maria', '  Maria.G@Hotmail.com', '$2a$10$hash', 'USER', NULL);

INSERT INTO home_networks (owner_id, name, provider, contracted_mbps)
SELECT id, 'Casa', 'Claro', 300 FROM users WHERE username IN ('Pedro', 'ana.lopez@gmail.com');

INSERT INTO agent_keys (home_network_id, key_hash, key_prefix, last_seen_at)
SELECT h.id, md5(h.id::text) || md5(h.id::text || 'x'), 'wsa_abcd', NOW() - INTERVAL '2 minutes'
FROM home_networks h JOIN users u ON u.id = h.owner_id WHERE u.username = 'Pedro';

INSERT INTO agent_reports (home_network_id, received_at, agent_version, ssid, authentication, band, channel,
                           signal_dbm, latency_ms, jitter_ms, packet_loss_pct, device_count, new_device_count,
                           security_score, security_grade, quality_score, anomaly_detected, anomaly_type, details)
SELECT h.id, NOW() - (n || ' minutes')::interval, '1.2.0', 'Casa_Pedro', 'WPA2', '2.4', 6, -60, 20 + n, 2, 0, 4, 0,
       80, 'ACCEPTABLE', 90, n = 10, CASE WHEN n = 10 THEN 'CONGESTION' ELSE 'NONE' END,
       CASE WHEN n = 5 THEN '{}'::jsonb ELSE '{"wifi": {"cipher": "CCMP"}, "openPorts": [53, 80]}'::jsonb END
FROM home_networks h JOIN users u ON u.id = h.owner_id, generate_series(5, 30, 5) AS n
WHERE u.username = 'Pedro';

INSERT INTO agent_devices (home_network_id, fingerprint, first_seen_at, last_seen_at, vendor, hostname, authorized, private_mac)
SELECT h.id, d.fp, NOW() - INTERVAL '3 days', NOW() - INTERVAL '5 minutes', d.vendor, d.hostname, d.ok, d.private
FROM home_networks h JOIN users u ON u.id = h.owner_id,
     (VALUES ('aaaaaaaaaaaaaaaaaaaaaaaa', 'TP-Link', 'router-sala', TRUE, FALSE),
             ('bbbbbbbbbbbbbbbbbbbbbbbb', NULL, NULL, TRUE, TRUE),
             ('cccccccccccccccccccccccc', 'Xiaomi', NULL, FALSE, FALSE)) AS d(fp, vendor, hostname, ok, private)
WHERE u.username = 'Pedro';

INSERT INTO agent_alerts (home_network_id, type, detail, emailed)
SELECT h.id, 'NEW_DEVICE', 'Apareció 1 equipo nuevo en tu red.', TRUE
FROM home_networks h JOIN users u ON u.id = h.owner_id WHERE u.username = 'Pedro';

INSERT INTO alert_preferences (user_id, email_anomaly) SELECT id, FALSE FROM users WHERE username = 'Pedro';

INSERT INTO connection_tests (home_network_id, latency_ms, jitter_ms, download_mbps, upload_mbps, quality_score,
                              quality_grade, quality_details)
SELECT h.id, 22, 3, 280, 90, q.score, q.grade, q.details
FROM home_networks h JOIN users u ON u.id = h.owner_id,
     (VALUES (88::smallint, 'GOOD', '{"score": 88, "tips": []}'::jsonb), (NULL, NULL, NULL)) AS q(score, grade, details)
WHERE u.username = 'ana.lopez@gmail.com';

INSERT INTO password_reset_tokens (user_id, token_hash, expires_at, used_at)
SELECT id, repeat('ab', 32), NOW() + INTERVAL '30 minutes', NULL FROM users WHERE username = 'ana.lopez@gmail.com';

INSERT INTO agent_pairing_codes (home_network_id, code_hash, expires_at)
SELECT h.id, repeat('cd', 32), NOW() + INTERVAL '15 minutes'
FROM home_networks h JOIN users u ON u.id = h.owner_id WHERE u.username = 'ana.lopez@gmail.com';

-- An analysis requested by a team member, its prediction and two alerts (one resolved).
INSERT INTO analysis_results (network_id, requested_by, analysis_type, detected_status, score, summary, measurement_count)
SELECT n.id, u.id, 'ANOMALY_DETECTION', 'WARNING', 0.7, 'Congestión en la biblioteca', 50
FROM networks n, users u WHERE u.username = 'Analista.Uno' ORDER BY n.id LIMIT 1;
INSERT INTO ai_predictions (analysis_result_id, network_id, anomaly_detected, anomaly_score, severity, message,
                            model_version, simulated_data, anomaly_type)
SELECT id, network_id, TRUE, 0.81, 'HIGH', 'Latencia muy alta', 'isolation-forest-1.1', TRUE, 'CONGESTION'
FROM analysis_results;
INSERT INTO alerts (network_id, analysis_result_id, severity, message, status, resolved_at)
SELECT network_id, id, 'WARNING', 'Congestión', 'RESOLVED', NOW() - INTERVAL '1 day' FROM analysis_results;
INSERT INTO alerts (network_id, severity, message) SELECT id, 'CRITICAL', 'Sin respuesta' FROM networks ORDER BY id LIMIT 1;

-- Rows per table before the upgrade; despues_de_actualizar.sql compares and then drops this table.
CREATE TABLE _conteo_antes (tabla TEXT PRIMARY KEY, filas BIGINT NOT NULL);
DO $$
DECLARE
    t TEXT;
    n BIGINT;
BEGIN
    FOR t IN SELECT relname FROM pg_class WHERE relkind = 'r' AND relnamespace = 'public'::regnamespace
                                         AND relname <> '_conteo_antes' LOOP
        EXECUTE format('SELECT count(*) FROM %I', t) INTO n;
        INSERT INTO _conteo_antes VALUES (t, n);
    END LOOP;
END $$;

COMMIT;
