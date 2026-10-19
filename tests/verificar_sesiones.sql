-- Verification after applying V37 on Railway (from DBeaver). It changes nothing: every row must say OK.
SELECT 'V37 historial de conexiones de los equipos' AS paso,
       CASE WHEN to_regclass('public.agent_device_sessions') IS NOT NULL
             AND to_regclass('public.network_sensor_device_sessions') IS NOT NULL
             AND to_regclass('public.uq_agent_device_sessions_open') IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END AS estado
UNION ALL
SELECT 'V37 descritas en el diccionario de datos',
       CASE WHEN obj_description('public.agent_device_sessions'::regclass) IS NOT NULL
             AND obj_description('public.network_sensor_device_sessions'::regclass) IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'El usuario de la aplicación puede usar las tablas nuevas',
       CASE WHEN NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'wifisense_app') THEN 'OK (no se usa el rol)'
            -- one privilege per call: with a list, has_table_privilege is true if ANY of them is held
            WHEN has_table_privilege('wifisense_app', 'public.agent_device_sessions', 'INSERT')
             AND has_table_privilege('wifisense_app', 'public.agent_device_sessions', 'UPDATE')
             AND has_table_privilege('wifisense_app', 'public.agent_device_sessions', 'DELETE')
             AND has_table_privilege('wifisense_app', 'public.network_sensor_device_sessions', 'INSERT')
             AND has_table_privilege('wifisense_app', 'public.network_sensor_device_sessions', 'UPDATE')
             AND has_table_privilege('wifisense_app', 'public.network_sensor_device_sessions', 'DELETE')
            THEN 'OK' ELSE 'FALTA: ejecuta otra vez security/rol_aplicacion.sql' END;
