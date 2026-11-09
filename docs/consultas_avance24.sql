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
