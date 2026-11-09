-- Reversión de V41 (lo que vio cada escaneo de redes cercanas). Borra esas observaciones.
BEGIN;
DROP TABLE IF EXISTS wifi_scan_observations;
DO $$ BEGIN
    IF to_regclass('flyway_schema_history') IS NOT NULL THEN
        DELETE FROM flyway_schema_history WHERE version = '41';
    END IF;
END $$;
COMMIT;
