-- Verificación después de aplicar V17, V18 y V19 en una base existente (por ejemplo la de Railway desde DBeaver).
-- No modifica nada: cada fila debe decir OK. Si alguna dice FALTA, aplica la migración indicada.
SELECT 'V17 agent_keys' AS migracion,
       CASE WHEN to_regclass('public.agent_keys') IS NOT NULL THEN 'OK' ELSE 'FALTA' END AS estado
UNION ALL
SELECT 'V18 agent_reports',
       CASE WHEN to_regclass('public.agent_reports') IS NOT NULL
             AND to_regclass('public.idx_agent_reports_network_time') IS NOT NULL THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'V19 agent_devices',
       CASE WHEN to_regclass('public.agent_devices') IS NOT NULL THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'Solo se guarda el hash de la clave',
       CASE WHEN EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_agent_keys_hash') THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'Nunca se guarda una MAC',
       CASE WHEN EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_agent_devices_fingerprint') THEN 'OK' ELSE 'FALTA' END;
