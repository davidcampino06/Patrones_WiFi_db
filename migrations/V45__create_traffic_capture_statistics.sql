-- Avance 24: the statistics of a completed capture, computed on the sensor's computer from the packets it really
-- captured: how they split by protocol, which services (transport and port) moved the most, and how the traffic
-- was spread over the capture, second by second. Only counts: no address, no MAC, no content.
CREATE TABLE traffic_capture_protocols (
    capture_id BIGINT      NOT NULL REFERENCES traffic_captures (id) ON DELETE CASCADE,
    protocol   VARCHAR(12) NOT NULL,
    packets    INTEGER     NOT NULL,
    bytes      BIGINT      NOT NULL,
    PRIMARY KEY (capture_id, protocol),
    CONSTRAINT ck_traffic_capture_protocols_protocol CHECK (protocol IN (
        'TCP', 'UDP', 'ICMP', 'ICMPV6', 'ARP', 'IGMP', 'DNS', 'MDNS', 'DHCP', 'SSDP', 'NETBIOS', 'LLMNR', 'HTTP',
        'HTTPS', 'QUIC', 'NTP', 'IPV6_OTHER', 'IPV4_OTHER', 'OTHER')),
    CONSTRAINT ck_traffic_capture_protocols_counts CHECK (packets > 0 AND bytes >= 0)
);

-- Top services: at most 20 per capture, chosen by the sensor.
CREATE TABLE traffic_capture_ports (
    capture_id BIGINT     NOT NULL REFERENCES traffic_captures (id) ON DELETE CASCADE,
    transport  VARCHAR(4) NOT NULL,
    port       INTEGER    NOT NULL,
    packets    INTEGER    NOT NULL,
    bytes      BIGINT     NOT NULL,
    PRIMARY KEY (capture_id, transport, port),
    CONSTRAINT ck_traffic_capture_ports_transport CHECK (transport IN ('TCP', 'UDP')),
    CONSTRAINT ck_traffic_capture_ports_port CHECK (port BETWEEN 0 AND 65535),
    CONSTRAINT ck_traffic_capture_ports_counts CHECK (packets > 0 AND bytes >= 0)
);

-- Traffic per second of the capture (second 0 is the start). Seconds without traffic are not stored.
CREATE TABLE traffic_capture_intervals (
    capture_id    BIGINT   NOT NULL REFERENCES traffic_captures (id) ON DELETE CASCADE,
    second_offset SMALLINT NOT NULL,
    packets       INTEGER  NOT NULL,
    bytes         BIGINT   NOT NULL,
    PRIMARY KEY (capture_id, second_offset),
    CONSTRAINT ck_traffic_capture_intervals_second CHECK (second_offset BETWEEN 0 AND 360),
    CONSTRAINT ck_traffic_capture_intervals_counts CHECK (packets > 0 AND bytes >= 0)
);

COMMENT ON TABLE traffic_capture_protocols IS 'Paquetes y bytes de una captura por protocolo.';
COMMENT ON COLUMN traffic_capture_protocols.capture_id IS 'Captura.';
COMMENT ON COLUMN traffic_capture_protocols.protocol IS
    'Protocolo reconocido por la cabecera y el puerto (TCP, UDP, ICMP, ARP, DNS, MDNS, DHCP, HTTPS, QUIC...; OTHER si no se reconoce).';
COMMENT ON COLUMN traffic_capture_protocols.packets IS 'Paquetes de ese protocolo.';
COMMENT ON COLUMN traffic_capture_protocols.bytes IS 'Bytes de esos paquetes.';
COMMENT ON TABLE traffic_capture_ports IS 'Servicios (transporte y puerto conocido) que más tráfico movieron en una captura; hasta 20.';
COMMENT ON COLUMN traffic_capture_ports.capture_id IS 'Captura.';
COMMENT ON COLUMN traffic_capture_ports.transport IS 'TCP o UDP.';
COMMENT ON COLUMN traffic_capture_ports.port IS 'Puerto del servicio (el menor de los dos, o el bien conocido).';
COMMENT ON COLUMN traffic_capture_ports.packets IS 'Paquetes de ese servicio.';
COMMENT ON COLUMN traffic_capture_ports.bytes IS 'Bytes de ese servicio.';
COMMENT ON TABLE traffic_capture_intervals IS 'Paquetes y bytes de una captura en cada segundo (los segundos sin tráfico no se guardan).';
COMMENT ON COLUMN traffic_capture_intervals.capture_id IS 'Captura.';
COMMENT ON COLUMN traffic_capture_intervals.second_offset IS 'Segundo de la captura (0 = el comienzo).';
COMMENT ON COLUMN traffic_capture_intervals.packets IS 'Paquetes en ese segundo.';
COMMENT ON COLUMN traffic_capture_intervals.bytes IS 'Bytes en ese segundo.';
