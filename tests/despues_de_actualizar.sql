-- Checks after applying the new migrations on top of datos_previos.sql (run by actualizacion_test.sh).
\ir _asserts.sql

SELECT pg_temp.assert_true(changed IS NULL, 'no table lost or gained rows in the upgrade' || coalesce(' (' || changed || ')', ''))
FROM (SELECT string_agg(format('%s: %s -> %s', b.tabla, b.filas, a.filas), ', ') AS changed
      FROM _conteo_antes b
      CROSS JOIN LATERAL (SELECT (xpath('/row/n/text()',
                                  query_to_xml(format('SELECT count(*) AS n FROM %I', b.tabla), FALSE, TRUE, '')))[1]::text::bigint AS filas) a
      WHERE a.filas <> b.filas) AS t;

SELECT pg_temp.assert_true(
    (SELECT array_agg(email::text ORDER BY email COLLATE "C") FROM users) =
        ARRAY['ana.lopez@gmail.com', 'analista.uno@wifisense.local', 'jefe.local@wifisense.local',
              'maria.g@hotmail.com', 'pedro@wifisense.local'],
    'existing emails were trimmed and moved to lower case');
SELECT pg_temp.assert_true(
    EXISTS (SELECT 1 FROM users WHERE username = 'Pedro'),
    'usernames keep the case the user chose (only their uniqueness ignores it)');
SELECT pg_temp.assert_true(
    (SELECT count(*) FROM agent_reports WHERE jsonb_typeof(details) = 'object') = 6,
    'every existing report still has its details');
SELECT pg_temp.assert_true(
    (SELECT count(*) FROM alerts WHERE status = 'RESOLVED' AND analysis_result_id IS NOT NULL) = 1,
    'resolved alerts keep their analysis');
SELECT pg_temp.assert_true(
    to_regclass('public.refresh_tokens') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM refresh_tokens),
    'the refresh tokens table starts empty');

DROP TABLE _conteo_antes;
