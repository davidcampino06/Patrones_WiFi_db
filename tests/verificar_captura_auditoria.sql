-- Verification after applying V42-V47 on Railway (from DBeaver). It changes nothing: every row must say OK.
SELECT 'V42 origen del nombre de cada equipo' AS paso,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns
                         WHERE table_name = 'agent_devices' AND column_name = 'name_source')
             AND EXISTS (SELECT 1 FROM information_schema.columns
                         WHERE table_name = 'network_sensor_devices' AND column_name = 'name_source')
            THEN 'OK' ELSE 'FALTA' END AS estado
UNION ALL
SELECT 'V43 capacidades del computador de cada agente',
       CASE WHEN to_regclass('public.agent_capabilities') IS NOT NULL THEN 'OK' ELSE 'FALTA' END;
