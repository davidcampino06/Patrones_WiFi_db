-- Reversión de V46 (hallazgos de las capturas: hechos e inferencias). Borra los hallazgos guardados.
BEGIN;
DROP TABLE IF EXISTS traffic_capture_findings;
DO $$ BEGIN
    IF to_regclass('flyway_schema_history') IS NOT NULL THEN
        DELETE FROM flyway_schema_history WHERE version = '46';
    END IF;
END $$;
COMMIT;
