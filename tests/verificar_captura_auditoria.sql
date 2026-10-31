-- Verification after applying V42-V47 on Railway (from DBeaver). It changes nothing: every row must say OK.
SELECT 'V42 origen del nombre de cada equipo' AS paso,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns
                         WHERE table_name = 'agent_devices' AND column_name = 'name_source')
             AND EXISTS (SELECT 1 FROM information_schema.columns
                         WHERE table_name = 'network_sensor_devices' AND column_name = 'name_source')
            THEN 'OK' ELSE 'FALTA' END AS estado
UNION ALL
SELECT 'V43 capacidades del computador de cada agente',
       CASE WHEN to_regclass('public.agent_capabilities') IS NOT NULL THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'V44 capturas técnicas (una activa por red)',
       CASE WHEN to_regclass('public.traffic_captures') IS NOT NULL
             AND to_regclass('public.uq_traffic_captures_active') IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'V45 estadísticas de las capturas (protocolos, servicios, segundos)',
       CASE WHEN to_regclass('public.traffic_capture_protocols') IS NOT NULL
             AND to_regclass('public.traffic_capture_ports') IS NOT NULL
             AND to_regclass('public.traffic_capture_intervals') IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'V46 hallazgos de las capturas (hechos e inferencias)',
       CASE WHEN to_regclass('public.traffic_capture_findings') IS NOT NULL THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'V47 auditoría protegida contra cambios',
       CASE WHEN to_regclass('public.audit_events') IS NOT NULL
             AND EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_events_protect')
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'V42-V47 descritas en el diccionario de datos',
       CASE WHEN obj_description('public.agent_capabilities'::regclass) IS NOT NULL
             AND obj_description('public.traffic_captures'::regclass) IS NOT NULL
             AND obj_description('public.traffic_capture_findings'::regclass) IS NOT NULL
             AND obj_description('public.audit_events'::regclass) IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'El usuario de la aplicación puede usar las tablas nuevas',
       CASE WHEN NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'wifisense_app') THEN 'OK (no se usa el rol)'
            -- one privilege per call: with a list, has_table_privilege is true if ANY of them is held
            WHEN has_table_privilege('wifisense_app', 'public.agent_capabilities', 'INSERT')
             AND has_table_privilege('wifisense_app', 'public.agent_capabilities', 'UPDATE')
             AND has_table_privilege('wifisense_app', 'public.traffic_captures', 'INSERT')
             AND has_table_privilege('wifisense_app', 'public.traffic_captures', 'UPDATE')
             AND has_table_privilege('wifisense_app', 'public.traffic_captures', 'DELETE')
             AND has_table_privilege('wifisense_app', 'public.traffic_capture_protocols', 'INSERT')
             AND has_table_privilege('wifisense_app', 'public.traffic_capture_findings', 'INSERT')
             AND has_table_privilege('wifisense_app', 'public.audit_events', 'INSERT')
             AND has_table_privilege('wifisense_app', 'public.audit_events', 'SELECT')
            THEN 'OK' ELSE 'FALTA: ejecuta otra vez security/rol_aplicacion.sql' END;
