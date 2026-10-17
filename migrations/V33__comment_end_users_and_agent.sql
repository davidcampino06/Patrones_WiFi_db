-- Avance 11: data dictionary inside the database (part 3 of 3: end users, the WiFiSense agent and sessions).

COMMENT ON TABLE home_networks IS 'Redes que registra cada usuario final (Mi Wi-Fi); nunca se mezclan con las de la universidad.';
COMMENT ON COLUMN home_networks.id IS 'Identificador.';
COMMENT ON COLUMN home_networks.owner_id IS 'Usuario dueño; al borrar la cuenta se borran sus redes.';
COMMENT ON COLUMN home_networks.name IS 'Nombre que le dio el usuario (2 a 40 caracteres), único por usuario.';
COMMENT ON COLUMN home_networks.provider IS 'Proveedor de internet, opcional.';
COMMENT ON COLUMN home_networks.contracted_mbps IS 'Velocidad contratada en Mbps, opcional.';
COMMENT ON COLUMN home_networks.created_at IS 'Fecha de registro.';
COMMENT ON COLUMN home_networks.updated_at IS 'Último cambio.';

COMMENT ON TABLE connection_tests IS 'Pruebas de conexión que hace el usuario en Mi Wi-Fi, calificadas por la IA.';
COMMENT ON COLUMN connection_tests.id IS 'Identificador.';
COMMENT ON COLUMN connection_tests.home_network_id IS 'Red probada.';
COMMENT ON COLUMN connection_tests.latency_ms IS 'Latencia en milisegundos.';
COMMENT ON COLUMN connection_tests.jitter_ms IS 'Jitter en milisegundos.';
COMMENT ON COLUMN connection_tests.download_mbps IS 'Bajada en Mbps.';
COMMENT ON COLUMN connection_tests.upload_mbps IS 'Subida en Mbps.';
COMMENT ON COLUMN connection_tests.quality_score IS 'Calidad de 0 a 100 dada por la IA; NULL si no respondió.';
COMMENT ON COLUMN connection_tests.quality_grade IS 'EXCELLENT, GOOD, FAIR o POOR.';
COMMENT ON COLUMN connection_tests.quality_details IS 'Detalle de la calificación (objeto JSON: métricas, actividades y consejos).';
COMMENT ON COLUMN connection_tests.created_at IS 'Momento de la prueba.';

COMMENT ON TABLE agent_keys IS 'Clave del agente de cada red del usuario; solo se guarda su SHA-256.';
COMMENT ON COLUMN agent_keys.id IS 'Identificador.';
COMMENT ON COLUMN agent_keys.home_network_id IS 'Red del agente; una clave por red.';
COMMENT ON COLUMN agent_keys.key_hash IS 'SHA-256 de la clave (64 hex). La clave no se puede recuperar.';
COMMENT ON COLUMN agent_keys.key_prefix IS 'Primeros caracteres de la clave, para reconocerla.';
COMMENT ON COLUMN agent_keys.created_at IS 'Momento en que se creó (instalación del agente).';
COMMENT ON COLUMN agent_keys.last_seen_at IS 'Último reporte del agente; define si está conectado.';

COMMENT ON TABLE agent_reports IS 'Reportes del agente cada 5 minutos con los veredictos de la IA. Se borran después de 30 días.';
COMMENT ON COLUMN agent_reports.id IS 'Identificador.';
COMMENT ON COLUMN agent_reports.home_network_id IS 'Red que reporta.';
COMMENT ON COLUMN agent_reports.received_at IS 'Momento en que llegó.';
COMMENT ON COLUMN agent_reports.agent_version IS 'Versión del agente.';
COMMENT ON COLUMN agent_reports.ssid IS 'Nombre del Wi-Fi; NULL si el computador está por cable.';
COMMENT ON COLUMN agent_reports.authentication IS 'Seguridad del Wi-Fi: OPEN, WEP, WPA, WPA2, WPA3 o UNKNOWN.';
COMMENT ON COLUMN agent_reports.band IS 'Banda en GHz: 2.4, 5 o 6.';
COMMENT ON COLUMN agent_reports.channel IS 'Canal del router.';
COMMENT ON COLUMN agent_reports.signal_dbm IS 'Señal en dBm (-100 a 0).';
COMMENT ON COLUMN agent_reports.latency_ms IS 'Latencia hacia internet en ms.';
COMMENT ON COLUMN agent_reports.jitter_ms IS 'Jitter hacia internet en ms.';
COMMENT ON COLUMN agent_reports.packet_loss_pct IS 'Pérdida hacia internet, de 0 a 100 %.';
COMMENT ON COLUMN agent_reports.gateway_latency_ms IS 'Latencia hasta el router en ms.';
COMMENT ON COLUMN agent_reports.device_count IS 'Equipos conectados.';
COMMENT ON COLUMN agent_reports.new_device_count IS 'Equipos vistos por primera vez en este reporte.';
COMMENT ON COLUMN agent_reports.security_score IS 'Seguridad de 0 a 100 según la IA.';
COMMENT ON COLUMN agent_reports.security_grade IS 'SECURE, ACCEPTABLE, AT_RISK o CRITICAL.';
COMMENT ON COLUMN agent_reports.quality_score IS 'Calidad de la conexión de 0 a 100 según la IA.';
COMMENT ON COLUMN agent_reports.anomaly_detected IS 'TRUE si la IA vio un comportamiento raro.';
COMMENT ON COLUMN agent_reports.anomaly_type IS 'Causa probable de la anomalía.';
COMMENT ON COLUMN agent_reports.details IS 'Objeto JSON con el detalle: Wi-Fi, puertos, hallazgos de seguridad, calidad, anomalía y canal recomendado.';

COMMENT ON TABLE agent_devices IS 'Equipos que vio el agente en la red del usuario, como en una lista de Bluetooth. Nunca se guarda la MAC.';
COMMENT ON COLUMN agent_devices.home_network_id IS 'Red del usuario.';
COMMENT ON COLUMN agent_devices.fingerprint IS 'Huella SHA-256 con sal de la MAC (24 hex): distingue equipos sin revelar su MAC.';
COMMENT ON COLUMN agent_devices.label IS 'Nombre que le puso el usuario; tiene prioridad sobre el que anuncia el equipo.';
COMMENT ON COLUMN agent_devices.first_seen_at IS 'Primera vez que se vio.';
COMMENT ON COLUMN agent_devices.last_seen_at IS 'Última vez que se vio. Los no vistos en 30 días se borran.';
COMMENT ON COLUMN agent_devices.vendor IS 'Fabricante según el prefijo (OUI) de la MAC.';
COMMENT ON COLUMN agent_devices.hostname IS 'Nombre que anuncia el equipo en la red (iPhone-de-Ana).';
COMMENT ON COLUMN agent_devices.authorized IS 'FALSE si el usuario lo marcó como no suyo; se avisa mientras siga conectado.';
COMMENT ON COLUMN agent_devices.private_mac IS 'TRUE si usa una MAC aleatoria (celular o tableta): su fabricante no se puede saber.';

COMMENT ON TABLE agent_pairing_codes IS 'Códigos de 8 caracteres para instalar el agente; un uso y 15 minutos. Solo se guarda su SHA-256.';
COMMENT ON COLUMN agent_pairing_codes.id IS 'Identificador.';
COMMENT ON COLUMN agent_pairing_codes.home_network_id IS 'Red donde se instalará el agente; un código vigente por red.';
COMMENT ON COLUMN agent_pairing_codes.code_hash IS 'SHA-256 del código.';
COMMENT ON COLUMN agent_pairing_codes.created_at IS 'Momento en que se generó.';
COMMENT ON COLUMN agent_pairing_codes.expires_at IS 'Momento en que vence.';

COMMENT ON TABLE agent_alerts IS 'Historial de avisos de cada red del usuario (equipo nuevo, seguridad, anomalía) y control de repetición del correo.';
COMMENT ON COLUMN agent_alerts.id IS 'Identificador.';
COMMENT ON COLUMN agent_alerts.home_network_id IS 'Red del aviso.';
COMMENT ON COLUMN agent_alerts.type IS 'NEW_DEVICE, UNAUTHORIZED_DEVICE, SECURITY o ANOMALY.';
COMMENT ON COLUMN agent_alerts.detail IS 'Frase que ve el usuario.';
COMMENT ON COLUMN agent_alerts.created_at IS 'Momento del aviso.';
COMMENT ON COLUMN agent_alerts.emailed IS 'TRUE si se envió por correo.';

COMMENT ON TABLE alert_preferences IS 'Qué avisos quiere recibir por correo cada usuario; sin fila, todos encendidos.';
COMMENT ON COLUMN alert_preferences.user_id IS 'Usuario dueño de las preferencias; una fila por usuario.';
COMMENT ON COLUMN alert_preferences.email_new_device IS 'Avisar equipos nuevos o no autorizados.';
COMMENT ON COLUMN alert_preferences.email_security IS 'Avisar cuando la seguridad baja a crítica.';
COMMENT ON COLUMN alert_preferences.email_anomaly IS 'Avisar anomalías de la conexión.';

COMMENT ON TABLE password_reset_tokens IS 'Enlaces de un solo uso para cambiar la contraseña, enviados por correo. Solo se guarda su SHA-256.';
COMMENT ON COLUMN password_reset_tokens.id IS 'Identificador.';
COMMENT ON COLUMN password_reset_tokens.user_id IS 'Cuenta a la que pertenece.';
COMMENT ON COLUMN password_reset_tokens.token_hash IS 'SHA-256 del enlace.';
COMMENT ON COLUMN password_reset_tokens.created_at IS 'Momento en que se pidió.';
COMMENT ON COLUMN password_reset_tokens.expires_at IS 'Vencimiento (30 minutos).';
COMMENT ON COLUMN password_reset_tokens.used_at IS 'Momento en que se usó; NULL si sigue pendiente.';

COMMENT ON TABLE refresh_tokens IS 'Tokens para renovar la sesión sin pedir la contraseña; rotan en cada uso. Solo se guarda su SHA-256.';
COMMENT ON COLUMN refresh_tokens.id IS 'Identificador.';
COMMENT ON COLUMN refresh_tokens.user_id IS 'Cuenta de la sesión.';
COMMENT ON COLUMN refresh_tokens.family_id IS 'Familia: todos los tokens que salen de un mismo inicio de sesión.';
COMMENT ON COLUMN refresh_tokens.token_hash IS 'SHA-256 del token.';
COMMENT ON COLUMN refresh_tokens.created_at IS 'Momento en que se emitió.';
COMMENT ON COLUMN refresh_tokens.expires_at IS 'Vencimiento.';
COMMENT ON COLUMN refresh_tokens.used_at IS 'Momento en que se cambió por uno nuevo; volver a usarlo revoca la familia.';
COMMENT ON COLUMN refresh_tokens.revoked_at IS 'Momento en que se revocó (cierre de sesión, cambio de contraseña o robo detectado).';

COMMENT ON FUNCTION normalize_user_email() IS 'Guarda el correo de cada cuenta sin espacios y en minúsculas (disparador trg_users_normalize_email).';

