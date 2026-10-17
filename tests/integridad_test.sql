-- Integrity rules added in V28-V30: unique accounts whatever the case, emails in lower case, no blank names, JSON
-- objects only and refresh tokens. Runs inside a transaction that is rolled back.
\ir _asserts.sql
BEGIN;

INSERT INTO users (username, email, password_hash, role) VALUES ('Prueba.Integridad', 'prueba.integridad@ejemplo.com', 'x', 'USER');

-- Accounts (V28)
SELECT pg_temp.assert_rejected(
    $$INSERT INTO users (username, email, password_hash, role) VALUES ('prueba.integridad', 'otra.integridad@ejemplo.com', 'x', 'USER')$$,
    'a username that only differs in case is the same account');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO users (username, email, password_hash, role) VALUES ('integridad2', 'PRUEBA.integridad@ejemplo.com', 'x', 'USER')$$,
    'the same email in capitals is the same email');
INSERT INTO users (username, email, password_hash, role) VALUES ('Pedro.Integridad', '  Pedro.Integridad@WiFiSense.local ', 'x', 'USER');
SELECT pg_temp.assert_true(
    (SELECT email FROM users WHERE username = 'Pedro.Integridad') = 'pedro.integridad@wifisense.local',
    'the database stores emails trimmed and in lower case, whoever writes them');
UPDATE users SET email = 'Pedro.Nuevo.Integridad@Ejemplo.com' WHERE username = 'Pedro.Integridad';
SELECT pg_temp.assert_true(
    (SELECT email FROM users WHERE username = 'Pedro.Integridad') = 'pedro.nuevo.integridad@ejemplo.com',
    'changing an email also stores it in lower case');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO users (username, email, password_hash, role) VALUES ('integridad3', 'sin-arroba', 'x', 'USER')$$,
    'an email needs exactly one @');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO users (username, email, password_hash, role) VALUES ('integridad4', 'prueba @ejemplo.com', 'x', 'USER')$$,
    'an email cannot contain spaces');
SELECT pg_temp.assert_true(
    (SELECT count(*) FROM users WHERE lower(email) = lower('Prueba.Integridad@Ejemplo.com')) = 1,
    'looking an email up ignoring case finds exactly one account');
SET LOCAL enable_seqscan = off;  -- on a small table the planner may prefer a scan; this proves the index fits
SELECT pg_temp.assert_true(
    pg_temp.plan_of($$SELECT id FROM users WHERE lower(email) = 'prueba.integridad@ejemplo.com'$$) LIKE '%uq_users_email_lower%',
    'the case-insensitive email lookup uses its unique index');
RESET enable_seqscan;
SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_users_email'),
    'the old case-sensitive email constraint is gone');

-- Places, zones and agent alerts (V29)
SELECT pg_temp.assert_rejected($$INSERT INTO locations (name) VALUES ('   ')$$, 'a place needs a name');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO locations (name, city) VALUES ('Sede de prueba', '')$$, 'a city cannot be blank');
INSERT INTO locations (name) VALUES ('Sede de prueba');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO zones (location_id, name) SELECT id, ' ' FROM locations WHERE name = 'Sede de prueba'$$,
    'a zone needs a name');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO zones (location_id, name, floor) SELECT id, 'Torre', 500 FROM locations WHERE name = 'Sede de prueba'$$,
    'a floor beyond 200 is a typo');
INSERT INTO zones (location_id, name, floor) SELECT id, 'Sótano', -2 FROM locations WHERE name = 'Sede de prueba';
SELECT pg_temp.assert_true(
    EXISTS (SELECT 1 FROM zones WHERE name = 'Sótano' AND floor = -2), 'basements have negative floors');

INSERT INTO home_networks (owner_id, name) SELECT id, 'Casa integridad' FROM users WHERE username = 'Prueba.Integridad';
SELECT pg_temp.assert_rejected(
    $$INSERT INTO agent_reports (home_network_id, agent_version, device_count, details)
      SELECT id, '1.3.0', 1, '[1, 2]' FROM home_networks WHERE name = 'Casa integridad'$$,
    'report details are always a JSON object');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO connection_tests (home_network_id, latency_ms, jitter_ms, download_mbps, upload_mbps, quality_details)
      SELECT id, 20, 2, 100, 50, '"bueno"' FROM home_networks WHERE name = 'Casa integridad'$$,
    'quality details are a JSON object or nothing');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO agent_alerts (home_network_id, type, detail)
      SELECT id, 'NEW_DEVICE', '  ' FROM home_networks WHERE name = 'Casa integridad'$$,
    'an agent alert carries a sentence for the user');

-- Refresh tokens (V30)
INSERT INTO refresh_tokens (user_id, family_id, token_hash, expires_at)
SELECT id, '7c9e6679-7425-40de-944b-e07fc1f90ae7', repeat('ab', 32), NOW() + INTERVAL '14 days'
FROM users WHERE username = 'Prueba.Integridad';
SELECT pg_temp.assert_rejected(
    $$INSERT INTO refresh_tokens (user_id, family_id, token_hash, expires_at)
      SELECT id, gen_random_uuid(), 'el-token-en-texto-plano-nunca-se-guarda-en-la-base-0000000000000', NOW() + INTERVAL '1 day'
      FROM users WHERE username = 'Prueba.Integridad'$$,
    'only the SHA-256 of a refresh token is stored');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO refresh_tokens (user_id, family_id, token_hash, expires_at)
      SELECT id, gen_random_uuid(), repeat('ab', 32), NOW() + INTERVAL '1 day' FROM users WHERE username = 'Prueba.Integridad'$$,
    'a refresh token is unique');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO refresh_tokens (user_id, family_id, token_hash, created_at, expires_at)
      SELECT id, gen_random_uuid(), repeat('cd', 32), NOW(), NOW() - INTERVAL '1 minute' FROM users WHERE username = 'Prueba.Integridad'$$,
    'a refresh token cannot expire before it is issued');
SELECT pg_temp.assert_rejected(
    $$UPDATE refresh_tokens SET revoked_at = created_at - INTERVAL '1 day' WHERE token_hash = repeat('ab', 32)$$,
    'a refresh token cannot be revoked before it is issued');
DELETE FROM users WHERE username = 'Prueba.Integridad';
SELECT pg_temp.assert_true(
    NOT EXISTS (SELECT 1 FROM refresh_tokens WHERE token_hash = repeat('ab', 32)),
    'deleting an account deletes its sessions');

ROLLBACK;
