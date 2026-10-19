-- What the agent tells about each device and the versions of the AI model (V38). Runs inside a transaction that is
-- rolled back.
\ir _asserts.sql
BEGIN;

INSERT INTO users (username, email, password_hash, role) VALUES ('identidad.prueba', 'ip@x.io', 'x', 'ADMIN');
INSERT INTO users (username, email, password_hash, role) VALUES ('casa.identidad', 'ci@x.io', 'x', 'USER');
INSERT INTO home_networks (owner_id, name) SELECT id, 'Casa identidad' FROM users WHERE username = 'casa.identidad';
INSERT INTO agent_devices (home_network_id, fingerprint, kind, role, model)
SELECT id, 'aaaaaaaaaaaaaaaaaaaaaaaa', 'PHONE', NULL, 'iPhone15,2' FROM home_networks WHERE name = 'Casa identidad';
INSERT INTO agent_devices (home_network_id, fingerprint, kind, role)
SELECT id, 'bbbbbbbbbbbbbbbbbbbbbbbb', 'COMPUTER', 'SELF' FROM home_networks WHERE name = 'Casa identidad';

-- Devices
SELECT pg_temp.assert_true(
    (SELECT count(*) FROM agent_devices WHERE kind IS NOT NULL) = 2,
    'a device can say what kind it is, its role and its model');
SELECT pg_temp.assert_rejected(
    $$UPDATE agent_devices SET kind = 'TOSTADORA' WHERE fingerprint = 'aaaaaaaaaaaaaaaaaaaaaaaa'$$,
    'an unknown kind of device is rejected');
SELECT pg_temp.assert_rejected(
    $$UPDATE agent_devices SET role = 'ADMIN' WHERE fingerprint = 'aaaaaaaaaaaaaaaaaaaaaaaa'$$,
    'a device is the agent computer, the router or nothing special');
SELECT pg_temp.assert_rejected(
    $$UPDATE agent_devices SET model = '  ' WHERE fingerprint = 'aaaaaaaaaaaaaaaaaaaaaaaa'$$,
    'a model is never blank');

-- Identification mode
UPDATE agent_keys SET identify_until = NOW() + INTERVAL '10 minutes' WHERE FALSE;
SELECT pg_temp.assert_true(
    EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'network_sensors'
            AND column_name = 'identify_until'),
    'agents and sensors can be asked to report every minute for a while');

-- Model versions
INSERT INTO ai_model_versions (version, algorithm, trained_by, samples, networks, data_from, data_to, metrics,
                               decision, reason, active, training_set)
SELECT 'real-prueba-1', 'IsolationForest', id, 1200, 2, NOW() - INTERVAL '5 days', NOW(), '{"candidate": {"f1": 0.9}}',
       'PROMOTED', 'Mejor F1 y menos falsas alarmas.', TRUE, '[[20, 2, 0, 300, -55, 0.4, 6, 900]]'
FROM users WHERE username = 'identidad.prueba';
SELECT pg_temp.assert_rejected(
    $$INSERT INTO ai_model_versions (version, algorithm, samples, networks, data_from, data_to, decision, reason, active,
                                     training_set)
      VALUES ('real-prueba-2', 'IsolationForest', 900, 1, NOW(), NOW(), 'PROMOTED', 'Otro', TRUE, '[]')$$,
    'only one model is in use');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO ai_model_versions (version, algorithm, samples, networks, data_from, data_to, decision, reason, active,
                                     training_set)
      VALUES ('real-prueba-3', 'IsolationForest', 900, 1, NOW(), NOW(), 'REJECTED', 'Peor', TRUE, '[]')$$,
    'a rejected model is never in use');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO ai_model_versions (version, algorithm, samples, networks, data_from, data_to, decision, reason,
                                     training_set)
      VALUES ('real-prueba-4', 'IsolationForest', 0, 1, NOW(), NOW(), 'REJECTED', 'Sin datos', '[]')$$,
    'a model is trained with at least one measurement');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO ai_model_versions (version, algorithm, samples, networks, data_from, data_to, decision, reason,
                                     training_set)
      VALUES ('real-prueba-5', 'IsolationForest', 10, 1, NOW(), NOW() - INTERVAL '1 day', 'REJECTED', 'Al revés', '[]')$$,
    'the period of the data is in order');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO ai_model_versions (version, algorithm, samples, networks, data_from, data_to, decision, reason,
                                     training_set)
      VALUES ('real-prueba-6', 'IsolationForest', 10, 1, NOW(), NOW(), 'REJECTED', 'Objeto', '{"a": 1}')$$,
    'the training set is a list of measurements');
DELETE FROM users WHERE username = 'identidad.prueba';
SELECT pg_temp.assert_true(
    (SELECT trained_by FROM ai_model_versions WHERE version = 'real-prueba-1') IS NULL,
    'the history of the model stays when the administrator account is deleted');

ROLLBACK;
