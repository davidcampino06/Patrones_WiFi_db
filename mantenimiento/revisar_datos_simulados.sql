-- Read-only: what borrar_datos_simulados.sql would delete and what stays. Changes nothing.
-- Run it in DBeaver (Alt + X) before the deletion and keep the result to compare.
SELECT 'Redes simuladas (se borran con sus datos)' AS que, count(*)::text AS cantidad,
       coalesce(string_agg(ssid, ', ' ORDER BY ssid), '-') AS detalle
FROM networks WHERE data_source_type = 'SIMULATION'
UNION ALL
SELECT 'Mediciones simuladas (se borran)', count(*)::text, '-' FROM measurements WHERE source = 'SIMULATION'
UNION ALL
SELECT 'Análisis hechos sobre datos simulados (se borran)', count(*)::text, '-'
FROM ai_predictions WHERE simulated_data
UNION ALL
SELECT 'Sedes de demostración sin otras redes (se borran con sus zonas)', count(*)::text,
       coalesce(string_agg(l.name, ', ' ORDER BY l.name), '-')
FROM locations l
WHERE l.name IN ('Main Campus', 'Downtown Office')
  AND NOT EXISTS (SELECT 1 FROM zones z JOIN networks n ON n.zone_id = z.id
                  WHERE z.location_id = l.id AND n.data_source_type <> 'SIMULATION')
UNION ALL
SELECT 'Redes que se quedan', count(*)::text, coalesce(string_agg(ssid || ' (' || data_source_type || ')', ', ' ORDER BY ssid), '-')
FROM networks WHERE data_source_type <> 'SIMULATION'
UNION ALL
SELECT 'Cuentas (se quedan todas)', count(*)::text, '-' FROM users
UNION ALL
SELECT 'Redes de Mi Wi-Fi de los usuarios (se quedan todas)', count(*)::text, '-' FROM home_networks;
