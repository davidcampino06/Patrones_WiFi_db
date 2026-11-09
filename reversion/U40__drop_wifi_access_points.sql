-- Reversión de V40 (puntos de acceso cercanos, uno por BSSID). Se aplica después de U41.
BEGIN;
DROP TABLE IF EXISTS wifi_access_points;
DO $$ BEGIN
    IF to_regclass('flyway_schema_history') IS NOT NULL THEN
        DELETE FROM flyway_schema_history WHERE version = '40';
    END IF;
END $$;
COMMIT;
