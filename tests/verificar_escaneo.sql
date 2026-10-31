-- Verification after applying V39-V41 on Railway (from DBeaver). It changes nothing: every row must say OK.
SELECT 'V39 escaneos de redes cercanas' AS paso,
       CASE WHEN to_regclass('public.wifi_scan_sessions') IS NOT NULL
             AND to_regclass('public.uq_wifi_scan_sessions_active') IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END AS estado
UNION ALL
SELECT 'V40 puntos de acceso vistos (uno por BSSID, sin la MAC)',
       CASE WHEN to_regclass('public.wifi_access_points') IS NOT NULL
             AND to_regclass('public.uq_wifi_access_points_bssid') IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'V41 observaciones de cada escaneo',
       CASE WHEN to_regclass('public.wifi_scan_observations') IS NOT NULL
             AND to_regclass('public.idx_wifi_scan_observations_access_point') IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'V39-V41 descritas en el diccionario de datos',
       CASE WHEN obj_description('public.wifi_scan_sessions'::regclass) IS NOT NULL
             AND obj_description('public.wifi_access_points'::regclass) IS NOT NULL
             AND obj_description('public.wifi_scan_observations'::regclass) IS NOT NULL
            THEN 'OK' ELSE 'FALTA' END
UNION ALL
SELECT 'El usuario de la aplicación puede usar las tablas nuevas',
       CASE WHEN NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'wifisense_app') THEN 'OK (no se usa el rol)'
            -- one privilege per call: with a list, has_table_privilege is true if ANY of them is held
            WHEN has_table_privilege('wifisense_app', 'public.wifi_scan_sessions', 'INSERT')
             AND has_table_privilege('wifisense_app', 'public.wifi_scan_sessions', 'UPDATE')
             AND has_table_privilege('wifisense_app', 'public.wifi_scan_sessions', 'DELETE')
             AND has_table_privilege('wifisense_app', 'public.wifi_access_points', 'INSERT')
             AND has_table_privilege('wifisense_app', 'public.wifi_access_points', 'UPDATE')
             AND has_table_privilege('wifisense_app', 'public.wifi_access_points', 'DELETE')
             AND has_table_privilege('wifisense_app', 'public.wifi_scan_observations', 'INSERT')
             AND has_table_privilege('wifisense_app', 'public.wifi_scan_observations', 'DELETE')
            THEN 'OK' ELSE 'FALTA: ejecuta otra vez security/rol_aplicacion.sql' END;
