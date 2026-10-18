-- Avance 13: the team's networks are measured by a sensor, the WiFiSense agent installed on a computer connected to
-- that network (the backend runs in Railway and cannot see it). AGENT is the new data source and the default one:
-- simulation stays only for local demos.
ALTER TABLE networks DROP CONSTRAINT ck_networks_data_source;
ALTER TABLE networks ADD CONSTRAINT ck_networks_data_source CHECK (
    data_source_type IN ('AGENT', 'SIMULATION', 'ROUTER_API', 'SNMP', 'SYSTEM', 'TRAFFIC_CAPTURE'));
ALTER TABLE networks ALTER COLUMN data_source_type SET DEFAULT 'AGENT';

-- The source of every measurement must be one of the known ones (the backend only writes these).
ALTER TABLE measurements ADD CONSTRAINT ck_measurements_source CHECK (
    source IN ('AGENT', 'SIMULATION', 'ROUTER_API', 'SNMP', 'SYSTEM', 'TRAFFIC_CAPTURE'));

COMMENT ON COLUMN networks.data_source_type IS
    'De dónde salen sus datos: AGENT (el sensor instalado en la red; la opción real), SIMULATION (solo demostraciones), '
    'SYSTEM, ROUTER_API, SNMP o TRAFFIC_CAPTURE.';
COMMENT ON COLUMN measurements.source IS
    'Fuente que la tomó: AGENT es el sensor de la red; SIMULATION es simulada y así se muestra.';
