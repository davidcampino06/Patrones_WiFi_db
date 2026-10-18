-- Verification after applying V34-V35 and mantenimiento/borrar_datos_simulados.sql on Railway (from DBeaver).
-- It changes nothing: every row must say OK.
SELECT 'V34 fuente AGENT (sensor) para redes y mediciones' AS paso,
       CASE WHEN pg_get_constraintdef((SELECT oid FROM pg_constraint WHERE conname = 'ck_networks_data_source'))
                 LIKE '%AGENT%'
             AND EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_measurements_source')
            THEN 'OK' ELSE 'FALTA' END AS estado
UNION ALL
SELECT 'V35 tablas del sensor',
       CASE WHEN to_regclass('public.network_sensors') IS NOT NULL
             AND to_regclass('public.network_sensor_pairing_codes') IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'V35 descritas en el diccionario de datos',
       CASE WHEN obj_description('public.network_sensors'::regclass) IS NOT NULL
             AND col_description('public.network_sensors'::regclass, 2) IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'El usuario de la aplicación puede usar las tablas del sensor',
       CASE WHEN NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'wifisense_app') THEN 'OK (no se usa el rol)'
            -- one privilege per call: with a list, has_table_privilege is true if ANY of them is held
            WHEN has_table_privilege('wifisense_app', 'public.network_sensors', 'INSERT')
             AND has_table_privilege('wifisense_app', 'public.network_sensors', 'UPDATE')
             AND has_table_privilege('wifisense_app', 'public.network_sensors', 'DELETE')
             AND has_table_privilege('wifisense_app', 'public.network_sensor_pairing_codes', 'INSERT')
             AND has_table_privilege('wifisense_app', 'public.network_sensor_pairing_codes', 'DELETE')
            THEN 'OK' ELSE 'FALTA: ejecuta otra vez security/rol_aplicacion.sql' END
UNION ALL
SELECT 'Sin redes ni mediciones simuladas',
       CASE WHEN NOT EXISTS (SELECT 1 FROM networks WHERE data_source_type = 'SIMULATION')
             AND NOT EXISTS (SELECT 1 FROM measurements WHERE source = 'SIMULATION')
            THEN 'OK' ELSE 'FALTA: ejecuta mantenimiento/borrar_datos_simulados.sql' END;
