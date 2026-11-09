-- Consultas de solo lectura para revisar en DBeaver lo que guarda el Avance 24 (escaneos de redes cercanas, capturas
-- técnicas y auditoría). Ninguna cambia datos. Selecciona una consulta y ejecútala con Ctrl + Enter.

-- 1. Últimos 20 escaneos de redes cercanas: de qué red, quién lo pidió, cómo terminó y por qué falló si falló.
SELECT s.id, h.name AS red, s.origin AS origen, u.username AS pedido_por, s.status AS estado, s.failure_reason AS motivo,
       s.requested_at AS pedido, s.finished_at AS terminado, s.network_count AS redes, s.access_point_count AS puntos,
       s.scan_tool AS herramienta, s.duration_ms AS duracion_ms
FROM wifi_scan_sessions s
JOIN home_networks h ON h.id = s.home_network_id
LEFT JOIN users u ON u.id = s.requested_by
ORDER BY s.requested_at DESC
LIMIT 20;

-- 2. Lo que vio el último escaneo completado de cada red (sin BSSID: solo su último byte), la señal más fuerte primero.
SELECT h.name AS red, s.finished_at AS escaneo, a.ssid AS red_vista, a.hidden AS oculta, a.bssid_suffix AS final_bssid,
       a.vendor AS fabricante, o.signal_percent AS senal_pct, o.channel AS canal, o.band AS banda,
       o.authentication AS seguridad, o.connected AS conectado
FROM (SELECT DISTINCT ON (home_network_id) * FROM wifi_scan_sessions WHERE status = 'COMPLETED'
      ORDER BY home_network_id, finished_at DESC) s
JOIN home_networks h ON h.id = s.home_network_id
JOIN wifi_scan_observations o ON o.scan_id = s.id
JOIN wifi_access_points a ON a.id = o.access_point_id
ORDER BY h.name, o.signal_percent DESC NULLS LAST;

-- 3. Qué puede hacer el computador de cada agente (lo informa el agente 2.0.0): permiso local, herramientas y modo monitor.
SELECT COALESCE(h.name, n.ssid) AS red, CASE WHEN c.network_id IS NULL THEN 'Mi Wi-Fi' ELSE 'Sensor del equipo' END AS tipo,
       c.platform AS sistema, c.agent_version AS version, c.elevated AS administrador, c.capture_consent AS permiso,
       c.npcap, c.pktmon, c.raw_socket, c.packet_socket, c.monitor_mode AS modo_monitor, c.reported_at AS revisado
FROM agent_capabilities c
LEFT JOIN home_networks h ON h.id = c.home_network_id
LEFT JOIN networks n ON n.id = c.network_id
ORDER BY c.reported_at DESC;

-- 4. Últimas 20 capturas técnicas: propósito, quién la pidió, límites, cómo terminó y cuánto capturó.
SELECT c.id, n.ssid AS red, u.username AS pedida_por, c.purpose AS proposito, c.status AS estado,
       c.failure_reason AS motivo, c.stop_reason AS se_detuvo_por, c.capture_tool AS herramienta,
       c.max_seconds AS max_s, c.max_packets AS max_paquetes, c.packet_count AS paquetes, c.byte_count AS bytes,
       c.dropped_by_tool AS perdidos_herramienta, c.analyzed_with AS analizada_con, c.requested_at AS pedida
FROM traffic_captures c
JOIN networks n ON n.id = c.network_id
LEFT JOIN users u ON u.id = c.requested_by
ORDER BY c.requested_at DESC
LIMIT 20;

-- 5. Protocolos de la última captura completada de cada red, con su parte del total.
SELECT n.ssid AS red, c.id AS captura, p.protocol AS protocolo, p.packets AS paquetes, p.bytes,
       round(100.0 * p.packets / NULLIF(c.packet_count, 0), 1) AS porcentaje
FROM (SELECT DISTINCT ON (network_id) * FROM traffic_captures WHERE status = 'COMPLETED'
      ORDER BY network_id, finished_at DESC) c
JOIN networks n ON n.id = c.network_id
JOIN traffic_capture_protocols p ON p.capture_id = c.id
ORDER BY n.ssid, p.packets DESC;
