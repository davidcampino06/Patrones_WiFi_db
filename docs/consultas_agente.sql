-- Consultas para revisar en DBeaver lo que envía el agente WiFiSense (solo lectura).
-- Selecciona una consulta y ejecútala con Ctrl + Enter.

-- 1. Redes con agente: clave (solo su inicio), último reporte y si está conectado (reportó en los últimos 15 min).
SELECT h.id, h.name AS red, u.username AS dueno, k.key_prefix AS clave, k.created_at AS creada,
       k.last_seen_at AS ultimo_reporte, k.last_seen_at > NOW() - INTERVAL '15 minutes' AS conectado
FROM agent_keys k
JOIN home_networks h ON h.id = k.home_network_id
JOIN users u ON u.id = h.owner_id
ORDER BY k.last_seen_at DESC NULLS LAST;

-- 2. Últimos 20 reportes con lo que concluyó la IA.
SELECT r.received_at, h.name AS red, r.ssid, r.authentication, r.band, r.channel, r.signal_dbm,
       r.latency_ms, r.packet_loss_pct, r.device_count, r.new_device_count,
       r.security_score, r.security_grade, r.quality_score, r.anomaly_detected, r.anomaly_type
FROM agent_reports r
JOIN home_networks h ON h.id = r.home_network_id
ORDER BY r.received_at DESC
LIMIT 20;

-- 3. Vulnerabilidades encontradas en el último reporte de cada red (detalle de la auditoría de la IA).
SELECT h.name AS red, r.received_at, f->>'severity' AS gravedad, f->>'title' AS hallazgo, f->>'action' AS que_hacer
FROM (SELECT DISTINCT ON (home_network_id) * FROM agent_reports ORDER BY home_network_id, received_at DESC) r
JOIN home_networks h ON h.id = r.home_network_id
CROSS JOIN LATERAL jsonb_array_elements(r.details->'security'->'findings') AS f
ORDER BY h.name, (f->>'penalty')::int DESC;

-- 4. Equipos vistos por red: cuántos hay, cuántos aparecieron en las últimas 24 horas.
SELECT h.name AS red, count(*) AS equipos,
       count(*) FILTER (WHERE d.first_seen_at > NOW() - INTERVAL '24 hours') AS nuevos_24h,
       max(d.last_seen_at) AS ultimo_visto
FROM agent_devices d
JOIN home_networks h ON h.id = d.home_network_id
GROUP BY h.name
ORDER BY equipos DESC;

-- 5. Tamaño que ocupan los reportes (se borran solos a los 30 días).
SELECT count(*) AS reportes, min(received_at) AS mas_antiguo,
       pg_size_pretty(pg_total_relation_size('agent_reports')) AS tamano
FROM agent_reports;
