-- Avance 24: the statistics of a completed capture, computed on the sensor's computer from the packets it really
-- captured: how they split by protocol, which services (transport and port) moved the most, and how the traffic
-- was spread over the capture, second by second. Only counts: no address, no MAC, no content.
CREATE TABLE traffic_capture_protocols (
    capture_id BIGINT      NOT NULL REFERENCES traffic_captures (id) ON DELETE CASCADE,
    protocol   VARCHAR(12) NOT NULL,
    packets    INTEGER     NOT NULL,
    bytes      BIGINT      NOT NULL,
    PRIMARY KEY (capture_id, protocol)
);

COMMENT ON TABLE traffic_capture_protocols IS 'Paquetes y bytes de una captura por protocolo.';
COMMENT ON COLUMN traffic_capture_protocols.capture_id IS 'Captura.';
COMMENT ON COLUMN traffic_capture_protocols.protocol IS
    'Protocolo reconocido por la cabecera y el puerto (TCP, UDP, ICMP, ARP, DNS, MDNS, DHCP, HTTPS, QUIC...; OTHER si no se reconoce).';
COMMENT ON COLUMN traffic_capture_protocols.packets IS 'Paquetes de ese protocolo.';
COMMENT ON COLUMN traffic_capture_protocols.bytes IS 'Bytes de esos paquetes.';
