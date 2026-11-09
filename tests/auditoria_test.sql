-- Audit of the sensitive operations (V47): known outcomes, roles and action codes, a target id always has its type,
-- the rows cannot be changed nor recent ones deleted, and deleting an account keeps who it was. Runs inside a
-- transaction that is rolled back.
\ir _asserts.sql
BEGIN;

INSERT INTO users (username, email, password_hash, role) VALUES ('auditoria.admin', 'aa@x.io', 'x', 'ADMIN');
INSERT INTO audit_events (actor_id, actor_username, actor_role, action, outcome, target_type, target_id, network_id,
                          detail)
SELECT id, 'auditoria.admin', 'ADMIN', 'CAPTURE_REQUESTED', 'SUCCESS', 'CAPTURE', 7, 3, 'Captura de 30 s, 5000 paquetes'
FROM users WHERE username = 'auditoria.admin';
INSERT INTO audit_events (actor_username, actor_role, action, outcome, detail)
VALUES ('analista.uno', 'ANALYST', 'CAPTURE_REQUESTED', 'DENIED', 'Sin permiso de administrador');
SELECT pg_temp.assert_true(
    (SELECT count(*) FROM audit_events WHERE action = 'CAPTURE_REQUESTED') = 2,
    'successful and denied operations are both recorded');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO audit_events (action, outcome) VALUES ('capture requested', 'SUCCESS')$$,
    'actions are upper-case codes');
SELECT pg_temp.assert_rejected(
    $$INSERT INTO audit_events (action, outcome) VALUES ('USER_DELETED', 'MAYBE')$$,
    'the outcome is SUCCESS, DENIED or FAILED');

ROLLBACK;
