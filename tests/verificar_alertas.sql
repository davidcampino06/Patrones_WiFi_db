-- Verificación después de aplicar V23 y V24 en una base existente (por ejemplo la de Railway desde DBeaver).
-- No modifica nada: cada fila debe decir OK. Si alguna dice FALTA, aplica la migración indicada.
SELECT 'V23 fabricante, nombre y autorización del equipo' AS migracion,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns
                         WHERE table_name = 'agent_devices' AND column_name = 'vendor')
             AND EXISTS (SELECT 1 FROM information_schema.columns
                         WHERE table_name = 'agent_devices' AND column_name = 'hostname')
             AND EXISTS (SELECT 1 FROM information_schema.columns
                         WHERE table_name = 'agent_devices' AND column_name = 'authorized')
            THEN 'OK' ELSE 'FALTA' END AS estado
UNION ALL
SELECT 'V24 preferencias de avisos',
       CASE WHEN to_regclass('public.alert_preferences') IS NOT NULL THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'V24 historial de avisos',
       CASE WHEN to_regclass('public.agent_alerts') IS NOT NULL THEN 'OK' ELSE 'FALTA' END;
