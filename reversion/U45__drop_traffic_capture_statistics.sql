-- Reversión de V45 (protocolos, servicios y segundos de cada captura). Borra esas estadísticas.
BEGIN;
DROP TABLE IF EXISTS traffic_capture_intervals;
DROP TABLE IF EXISTS traffic_capture_ports;
DROP TABLE IF EXISTS traffic_capture_protocols;
DO $$ BEGIN
    IF to_regclass('flyway_schema_history') IS NOT NULL THEN
        DELETE FROM flyway_schema_history WHERE version = '45';
    END IF;
END $$;
COMMIT;
