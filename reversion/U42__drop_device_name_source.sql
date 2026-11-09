-- Reversión de V42 (de dónde salió el nombre de cada equipo). Los nombres se quedan; solo se pierde su origen.
BEGIN;
ALTER TABLE agent_devices DROP CONSTRAINT IF EXISTS ck_agent_devices_name_source_name;
ALTER TABLE agent_devices DROP CONSTRAINT IF EXISTS ck_agent_devices_name_source;
ALTER TABLE agent_devices DROP COLUMN IF EXISTS name_source;
ALTER TABLE network_sensor_devices DROP CONSTRAINT IF EXISTS ck_network_sensor_devices_name_source_name;
ALTER TABLE network_sensor_devices DROP CONSTRAINT IF EXISTS ck_network_sensor_devices_name_source;
ALTER TABLE network_sensor_devices DROP COLUMN IF EXISTS name_source;
DO $$ BEGIN
    IF to_regclass('flyway_schema_history') IS NOT NULL THEN
        DELETE FROM flyway_schema_history WHERE version = '42';
    END IF;
END $$;
COMMIT;
