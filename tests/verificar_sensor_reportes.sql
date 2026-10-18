-- Verification after applying V36 on Railway (from DBeaver). It changes nothing: every row must say OK.
SELECT 'V36 reportes y equipos del sensor' AS paso,
       CASE WHEN to_regclass('public.network_sensor_reports') IS NOT NULL
             AND to_regclass('public.network_sensor_devices') IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END AS estado
UNION ALL
SELECT 'V36 descritas en el diccionario de datos',
       CASE WHEN obj_description('public.network_sensor_reports'::regclass) IS NOT NULL
             AND obj_description('public.network_sensor_devices'::regclass) IS NOT NULL
             AND col_description('public.network_sensor_devices'::regclass, 2) IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'El usuario de la aplicación puede usar las tablas nuevas',
       CASE WHEN NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'wifisense_app') THEN 'OK (no se usa el rol)'
            -- one privilege per call: with a list, has_table_privilege is true if ANY of them is held
            WHEN has_table_privilege('wifisense_app', 'public.network_sensor_reports', 'INSERT')
             AND has_table_privilege('wifisense_app', 'public.network_sensor_reports', 'DELETE')
             AND has_table_privilege('wifisense_app', 'public.network_sensor_devices', 'INSERT')
             AND has_table_privilege('wifisense_app', 'public.network_sensor_devices', 'UPDATE')
             AND has_table_privilege('wifisense_app', 'public.network_sensor_devices', 'DELETE')
            THEN 'OK' ELSE 'FALTA: ejecuta otra vez security/rol_aplicacion.sql' END;
