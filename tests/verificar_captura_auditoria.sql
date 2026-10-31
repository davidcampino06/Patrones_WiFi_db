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
            THEN 'OK' ELSE 'FALTA' END;
