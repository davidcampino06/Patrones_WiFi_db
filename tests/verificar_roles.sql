-- Verification after applying V48 on Railway (from DBeaver). It changes nothing: every row must say OK.
SELECT 'V48 el equipo tiene dos roles (ADMIN y ANALYST) y los usuarios finales USER' AS paso,
       CASE WHEN pg_get_constraintdef(oid) LIKE '%ADMIN%ANALYST%USER%' AND pg_get_constraintdef(oid) NOT LIKE '%VIEWER%'
            THEN 'OK' ELSE 'FALTA' END AS estado
FROM pg_constraint WHERE conname = 'ck_users_role'
UNION ALL
SELECT 'V48 una cuenta sin rol queda como usuario final',
       CASE WHEN column_default LIKE '''USER''%' THEN 'OK' ELSE 'FALTA' END
FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'role'
UNION ALL
SELECT 'Ninguna cuenta con el rol VIEWER',
       CASE WHEN NOT EXISTS (SELECT 1 FROM users WHERE role = 'VIEWER') THEN 'OK' ELSE 'REVISAR' END;
