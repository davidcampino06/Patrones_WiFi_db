-- Reversión de V39 (escaneos de redes cercanas). Se aplica después de U41 y U40.
BEGIN;
DROP TABLE IF EXISTS wifi_scan_sessions;
DO $$ BEGIN
    IF to_regclass('flyway_schema_history') IS NOT NULL THEN
        DELETE FROM flyway_schema_history WHERE version = '39';
    END IF;
END $$;
COMMIT;
