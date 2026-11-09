-- Reversión de V44 (capturas técnicas). Se aplica después de U46 y U45, que borran lo que depende de esta tabla.
BEGIN;
DROP TABLE IF EXISTS traffic_captures;
DO $$ BEGIN
    IF to_regclass('flyway_schema_history') IS NOT NULL THEN
        DELETE FROM flyway_schema_history WHERE version = '44';
    END IF;
END $$;
COMMIT;
