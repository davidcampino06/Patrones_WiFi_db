-- Verification after applying V38 on Railway (from DBeaver). It changes nothing: every row must say OK.
SELECT 'V38 tipo, rol y modelo de los equipos' AS paso,
       CASE WHEN (SELECT count(*) FROM information_schema.columns
                  WHERE table_name IN ('agent_devices', 'network_sensor_devices')
                    AND column_name IN ('kind', 'role', 'model')) = 6
            THEN 'OK' ELSE 'FALTA' END AS estado
UNION ALL
SELECT 'V38 modo identificar del agente y del sensor',
       CASE WHEN (SELECT count(*) FROM information_schema.columns
                  WHERE table_name IN ('agent_keys', 'network_sensors') AND column_name = 'identify_until') = 2
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'V38 versiones del modelo de IA',
       CASE WHEN to_regclass('public.ai_model_versions') IS NOT NULL
             AND obj_description('public.ai_model_versions'::regclass) IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'El usuario de la aplicación puede usar la tabla nueva',
       CASE WHEN NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'wifisense_app') THEN 'OK (no se usa el rol)'
            -- one privilege per call: with a list, has_table_privilege is true if ANY of them is held
            WHEN has_table_privilege('wifisense_app', 'public.ai_model_versions', 'INSERT')
             AND has_table_privilege('wifisense_app', 'public.ai_model_versions', 'UPDATE')
             AND has_table_privilege('wifisense_app', 'public.ai_model_versions', 'SELECT')
            THEN 'OK' ELSE 'FALTA: ejecuta otra vez security/rol_aplicacion.sql' END;
