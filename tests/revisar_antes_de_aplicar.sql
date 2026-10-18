-- Run BEFORE applying new migrations (V26 onwards) on a database that already has data (Railway, from DBeaver).
-- It changes nothing. Every row must say OK. If one says REVISAR, fix that data first: the migration would stop at that point
-- (V28 and V29 refuse data that breaks their rules instead of changing it silently).
SELECT 'Usuarios repetidos sin importar mayúsculas (V28)' AS revision,
       coalesce('REVISAR: ' || (SELECT string_agg(name, ', ') FROM (
           SELECT lower(username) AS name FROM users GROUP BY lower(username) HAVING count(*) > 1) AS d), 'OK') AS estado
UNION ALL
SELECT 'Correos repetidos sin importar mayúsculas (V28)',
       coalesce('REVISAR: ' || (SELECT string_agg(mail, ', ') FROM (
           SELECT lower(btrim(email)) AS mail FROM users GROUP BY lower(btrim(email)) HAVING count(*) > 1) AS d), 'OK')
UNION ALL
SELECT 'Correos sin una @ o con espacios (V28)',
       coalesce('REVISAR: ' || (SELECT string_agg(username, ', ') FROM users
                                WHERE lower(btrim(email)) !~ '^[^@[:space:]]+@[^@[:space:]]+$'), 'OK')
UNION ALL
SELECT 'Sedes con nombre, dirección o ciudad en blanco (V29)',
       coalesce('REVISAR: ' || (SELECT string_agg(id::text, ', ') FROM locations
                                WHERE btrim(name) = '' OR btrim(address) = '' OR btrim(city) = ''), 'OK')
UNION ALL
SELECT 'Zonas sin nombre o con piso fuera de -10..200 (V29)',
       coalesce('REVISAR: ' || (SELECT string_agg(id::text, ', ') FROM zones
                                WHERE btrim(name) = '' OR floor NOT BETWEEN -10 AND 200), 'OK')
UNION ALL
SELECT 'Reportes del agente cuyo detalle no es un objeto JSON (V29)',
       coalesce('REVISAR: ' || (SELECT NULLIF(count(*), 0)::text FROM agent_reports WHERE jsonb_typeof(details) <> 'object')
                || ' reportes', 'OK')
UNION ALL
SELECT 'Pruebas de conexión con detalle que no es un objeto JSON (V29)',
       coalesce('REVISAR: ' || (SELECT NULLIF(count(*), 0)::text FROM connection_tests
                                WHERE quality_details IS NOT NULL AND jsonb_typeof(quality_details) <> 'object')
                || ' pruebas', 'OK')
UNION ALL
SELECT 'Avisos del agente sin texto (V29)',
       coalesce('REVISAR: ' || (SELECT NULLIF(count(*), 0)::text FROM agent_alerts WHERE btrim(detail) = '') || ' avisos', 'OK')
UNION ALL
SELECT 'Mediciones con una fuente desconocida (V34)',
       coalesce('REVISAR: ' || (SELECT string_agg(DISTINCT source, ', ') FROM measurements
                                WHERE source NOT IN ('AGENT', 'SIMULATION', 'ROUTER_API', 'SNMP', 'SYSTEM', 'TRAFFIC_CAPTURE')),
                'OK');
