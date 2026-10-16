-- Verificación después de aplicar V20, V21 y V22 en una base existente (por ejemplo la de Railway desde DBeaver).
-- No modifica nada: cada fila debe decir OK. Si alguna dice FALTA, aplica la migración indicada.
SELECT 'V20 teléfono y cambio de contraseña' AS migracion,
       CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'phone')
             AND EXISTS (SELECT 1 FROM information_schema.columns
                         WHERE table_name = 'users' AND column_name = 'password_changed_at')
            THEN 'OK' ELSE 'FALTA' END AS estado
UNION ALL
SELECT 'V21 enlaces de recuperación',
       CASE WHEN to_regclass('public.password_reset_tokens') IS NOT NULL THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'V22 códigos de instalación del agente',
       CASE WHEN to_regclass('public.agent_pairing_codes') IS NOT NULL THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'Solo se guarda el hash del enlace',
       CASE WHEN EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_password_reset_tokens_hash') THEN 'OK' ELSE 'FALTA' END;
