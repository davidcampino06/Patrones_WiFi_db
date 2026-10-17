-- Verificación después de aplicar V25 en una base existente (por ejemplo la de Railway desde DBeaver).
-- No modifica nada: cada fila debe decir OK. Si alguna dice FALTA, aplica la migración indicada.
SELECT 'V25 equipos con MAC privada (celulares y tabletas)' AS migracion,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns
                         WHERE table_name = 'agent_devices' AND column_name = 'private_mac'
                           AND is_nullable = 'NO')
            THEN 'OK' ELSE 'FALTA' END AS estado
UNION ALL
SELECT 'V25 índice de anomalías para el panel del equipo',
       CASE WHEN to_regclass('public.idx_agent_reports_anomalies') IS NOT NULL THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'Ningún equipo guarda su MAC (solo la huella)',
       CASE WHEN NOT EXISTS (SELECT 1 FROM agent_devices WHERE fingerprint ~ '[:-]') THEN 'OK' ELSE 'REVISAR' END;
