-- Avance 11: data dictionary inside the database (part 1 of 3: accounts and monitoring of the university networks).
-- DBeaver shows these descriptions next to each table and column. tests/diccionario_test.sql fails if a table or a
-- column is left without one, so the dictionary cannot fall behind the schema.

COMMENT ON TABLE users IS 'Cuentas: el equipo (ADMIN, ANALYST, VIEWER) y los usuarios finales que se registran (USER).';
COMMENT ON COLUMN users.id IS 'Identificador de la cuenta.';
COMMENT ON COLUMN users.username IS 'Nombre de usuario (3 a 40 caracteres, puede ser un correo). Único sin importar mayúsculas.';
COMMENT ON COLUMN users.email IS 'Correo de recuperación, en minúsculas y único. Sin correo real: <usuario>@wifisense.local.';
COMMENT ON COLUMN users.password_hash IS 'Hash BCrypt de la contraseña; la contraseña nunca se guarda.';
COMMENT ON COLUMN users.role IS 'ADMIN, ANALYST o VIEWER (equipo) o USER (usuario final).';
COMMENT ON COLUMN users.enabled IS 'FALSE impide iniciar sesión sin borrar la cuenta.';
COMMENT ON COLUMN users.created_at IS 'Fecha de creación de la cuenta.';
COMMENT ON COLUMN users.updated_at IS 'Último cambio de la cuenta.';
COMMENT ON COLUMN users.phone IS 'Celular en formato internacional (+573001234567), opcional; reservado para recuperación por SMS.';
COMMENT ON COLUMN users.password_changed_at IS 'Último cambio de contraseña: las sesiones anteriores a esta fecha dejan de valer.';

COMMENT ON TABLE locations IS 'Sedes de la universidad donde están las redes monitoreadas.';
COMMENT ON COLUMN locations.id IS 'Identificador de la sede.';
COMMENT ON COLUMN locations.name IS 'Nombre de la sede, único.';
COMMENT ON COLUMN locations.address IS 'Dirección, opcional.';
COMMENT ON COLUMN locations.city IS 'Ciudad, opcional.';
COMMENT ON COLUMN locations.created_at IS 'Fecha de registro.';

COMMENT ON TABLE zones IS 'Zonas dentro de una sede (biblioteca, cafetería, un piso).';
COMMENT ON COLUMN zones.id IS 'Identificador de la zona.';
COMMENT ON COLUMN zones.location_id IS 'Sede a la que pertenece; al borrar la sede se borran sus zonas.';
COMMENT ON COLUMN zones.name IS 'Nombre de la zona, único dentro de la sede.';
COMMENT ON COLUMN zones.floor IS 'Piso (de -10 a 200), opcional.';
COMMENT ON COLUMN zones.created_at IS 'Fecha de registro.';

COMMENT ON TABLE networks IS 'Redes Wi-Fi de la universidad que monitorea el equipo (puntos de acceso).';
COMMENT ON COLUMN networks.id IS 'Identificador de la red.';
COMMENT ON COLUMN networks.zone_id IS 'Zona donde está; no se puede borrar una zona con redes.';
COMMENT ON COLUMN networks.ssid IS 'Nombre de la red que ven los usuarios.';
COMMENT ON COLUMN networks.bssid IS 'Dirección MAC del punto de acceso (AA:BB:CC:DD:EE:FF), única.';
COMMENT ON COLUMN networks.frequency_band IS 'Banda: 2.4GHz, 5GHz o 6GHz.';
COMMENT ON COLUMN networks.channel IS 'Canal Wi-Fi (1 a 233).';
COMMENT ON COLUMN networks.security_type IS 'Seguridad: OPEN, WPA2, WPA3 o WPA2_ENTERPRISE.';
COMMENT ON COLUMN networks.status IS 'Estado según el último análisis: NORMAL, WARNING o CRITICAL (patrón State).';
COMMENT ON COLUMN networks.data_source_type IS 'De dónde salen sus datos: SIMULATION, SYSTEM, ROUTER_API, SNMP o TRAFFIC_CAPTURE.';
COMMENT ON COLUMN networks.last_collected_at IS 'Última vez que el monitoreo tomó una medición.';
COMMENT ON COLUMN networks.created_at IS 'Fecha de registro.';
COMMENT ON COLUMN networks.updated_at IS 'Último cambio.';

COMMENT ON TABLE devices IS 'Dispositivos conectados a las redes de la universidad.';
COMMENT ON COLUMN devices.id IS 'Identificador del dispositivo.';
COMMENT ON COLUMN devices.network_id IS 'Red a la que está conectado.';
COMMENT ON COLUMN devices.hostname IS 'Nombre del equipo en la red, opcional.';
COMMENT ON COLUMN devices.ip_address IS 'Dirección IP (IPv4 o IPv6).';
COMMENT ON COLUMN devices.mac_address IS 'Dirección MAC en mayúsculas (AA:BB:CC:DD:EE:FF), única.';
COMMENT ON COLUMN devices.device_type IS 'LAPTOP, PHONE, TABLET, IOT, ACCESS_POINT o UNKNOWN.';
COMMENT ON COLUMN devices.connection_status IS 'CONNECTED, IDLE o DISCONNECTED.';
COMMENT ON COLUMN devices.signal_strength IS 'Señal en dBm (-100 a 0), opcional.';
COMMENT ON COLUMN devices.last_seen_at IS 'Última vez que se vio conectado.';
COMMENT ON COLUMN devices.created_at IS 'Primera vez que se registró.';

COMMENT ON TABLE measurements IS 'Mediciones periódicas de cada red. Se borran las más antiguas que el periodo de retención.';
COMMENT ON COLUMN measurements.id IS 'Identificador de la medición.';
COMMENT ON COLUMN measurements.network_id IS 'Red medida.';
COMMENT ON COLUMN measurements.latency_ms IS 'Latencia en milisegundos.';
COMMENT ON COLUMN measurements.jitter_ms IS 'Variación de la latencia (jitter) en milisegundos.';
COMMENT ON COLUMN measurements.packet_loss_pct IS 'Pérdida de paquetes, de 0 a 100 %.';
COMMENT ON COLUMN measurements.bandwidth_mbps IS 'Ancho de banda en Mbps; no todas las fuentes lo dan.';
COMMENT ON COLUMN measurements.signal_strength_dbm IS 'Señal en dBm (-100 a 0); no todas las fuentes la dan.';
COMMENT ON COLUMN measurements.connected_devices IS 'Dispositivos conectados en ese momento; opcional.';
COMMENT ON COLUMN measurements.source IS 'Fuente que la tomó (SIMULATION es simulada y así se muestra).';
COMMENT ON COLUMN measurements.measured_at IS 'Momento de la medición.';
COMMENT ON COLUMN measurements.created_at IS 'Momento en que se guardó.';

COMMENT ON TABLE traffic_observations IS 'Volumen de tráfico de cada red por intervalo; entrada de la detección de anomalías.';
COMMENT ON COLUMN traffic_observations.id IS 'Identificador.';
COMMENT ON COLUMN traffic_observations.network_id IS 'Red observada.';
COMMENT ON COLUMN traffic_observations.traffic_volume_mb IS 'Tráfico del intervalo en megabytes.';
COMMENT ON COLUMN traffic_observations.packet_count IS 'Paquetes del intervalo.';
COMMENT ON COLUMN traffic_observations.observed_at IS 'Momento de la observación.';
COMMENT ON COLUMN traffic_observations.created_at IS 'Momento en que se guardó.';

COMMENT ON TABLE traffic_sessions IS 'Sesiones de tráfico de un dispositivo (protocolo, puerto y bytes).';
COMMENT ON COLUMN traffic_sessions.id IS 'Identificador.';
COMMENT ON COLUMN traffic_sessions.device_id IS 'Dispositivo de la sesión.';
COMMENT ON COLUMN traffic_sessions.protocol IS 'Protocolo (HTTPS, DNS, QUIC...).';
COMMENT ON COLUMN traffic_sessions.destination_port IS 'Puerto de destino (0 a 65535), opcional.';
COMMENT ON COLUMN traffic_sessions.bytes_sent IS 'Bytes enviados.';
COMMENT ON COLUMN traffic_sessions.bytes_received IS 'Bytes recibidos.';
COMMENT ON COLUMN traffic_sessions.started_at IS 'Inicio de la sesión.';
COMMENT ON COLUMN traffic_sessions.ended_at IS 'Fin de la sesión; NULL si sigue abierta.';

COMMENT ON TABLE protocol_statistics IS 'Paquetes por protocolo de cada red en un periodo; uno por red, protocolo y periodo.';
COMMENT ON COLUMN protocol_statistics.id IS 'Identificador.';
COMMENT ON COLUMN protocol_statistics.network_id IS 'Red de la que se cuentan los paquetes.';
COMMENT ON COLUMN protocol_statistics.protocol IS 'Protocolo contado.';
COMMENT ON COLUMN protocol_statistics.packet_count IS 'Paquetes del periodo.';
COMMENT ON COLUMN protocol_statistics.period_start IS 'Inicio del periodo.';
COMMENT ON COLUMN protocol_statistics.period_end IS 'Fin del periodo.';
