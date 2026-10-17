-- Verification after applying V26-V33 on an existing database (for example Railway from DBeaver).
-- It changes nothing: every row must say OK. If one says FALTA, apply the migration it names.
SELECT 'V26 índices de las claves foráneas' AS migracion,
       CASE WHEN to_regclass('public.idx_analysis_results_requested_by') IS NOT NULL
             AND to_regclass('public.idx_ai_predictions_network') IS NOT NULL
             AND to_regclass('public.idx_alerts_analysis_result') IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END AS estado
UNION ALL
SELECT 'V27 índices por fecha para la limpieza nocturna',
       CASE WHEN (SELECT count(*) FROM pg_indexes WHERE indexname IN (
                  'idx_measurements_measured_at', 'idx_traffic_observations_observed_at',
                  'idx_traffic_sessions_started_at', 'idx_protocol_statistics_period_start',
                  'idx_analysis_results_created_at', 'idx_agent_alerts_created_at',
                  'idx_agent_pairing_codes_expires_at', 'idx_alerts_resolved_at')) = 8
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'V28 usuario y correo únicos sin importar mayúsculas',
       CASE WHEN to_regclass('public.uq_users_email_lower') IS NOT NULL
             AND to_regclass('public.uq_users_username_lower') IS NOT NULL
             AND EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_users_normalize_email')
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'V28 todos los correos en minúsculas',
       CASE WHEN NOT EXISTS (SELECT 1 FROM users WHERE email <> lower(email)) THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'V29 reglas de nombres y de JSON',
       CASE WHEN (SELECT count(*) FROM pg_constraint WHERE conname IN (
                  'ck_locations_name', 'ck_zones_name', 'ck_zones_floor', 'ck_agent_reports_details_object',
                  'ck_connection_tests_quality_object', 'ck_agent_alerts_detail')) = 6
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'V30 tabla de refresh tokens',
       CASE WHEN to_regclass('public.refresh_tokens') IS NOT NULL THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'V31-V33 diccionario de datos (todas las tablas y columnas descritas)',
       CASE WHEN NOT EXISTS (
                SELECT 1 FROM pg_class c JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
                WHERE c.relkind = 'r' AND c.relnamespace = 'public'::regnamespace
                  AND c.relname <> 'flyway_schema_history' AND col_description(c.oid, a.attnum) IS NULL)
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'Rol de la aplicación (opcional, security/rol_aplicacion.sql)',
       CASE WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'wifisense_app') THEN 'OK'
            ELSE 'OPCIONAL: no creado' END;
