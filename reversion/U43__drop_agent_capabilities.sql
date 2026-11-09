-- Reversión de V43 (lo que puede hacer el computador de cada agente). Los agentes lo vuelven a enviar en su próximo
-- reporte si la migración se aplica de nuevo.
BEGIN;
DROP TABLE IF EXISTS agent_capabilities;
DO $$ BEGIN
    IF to_regclass('flyway_schema_history') IS NOT NULL THEN
        DELETE FROM flyway_schema_history WHERE version = '43';
    END IF;
END $$;
COMMIT;
