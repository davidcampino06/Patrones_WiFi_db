-- Deletes every simulated piece of data so the team panel starts empty and only shows what the sensors measure.
-- Run mantenimiento/revisar_datos_simulados.sql first. Everything happens in one transaction: either all of it is
-- deleted or nothing is. Accounts, end-user networks (Mi Wi-Fi), their agents and reports are never touched.
BEGIN;

-- 1. Simulated networks with everything that hangs from them (ON DELETE CASCADE): devices and their traffic
--    sessions, measurements, traffic, protocol statistics, analyses, AI predictions and alerts.
DELETE FROM networks WHERE data_source_type = 'SIMULATION';

-- 2. Simulated measurements left in a network whose source was changed later.
DELETE FROM measurements WHERE source = 'SIMULATION';

-- 3. Analyses whose AI prediction was computed on simulated data (their alerts stay, without the link).
DELETE FROM analysis_results a
WHERE EXISTS (SELECT 1 FROM ai_predictions p WHERE p.analysis_result_id = a.id AND p.simulated_data);

-- 4. The demonstration locations of the seed data, with their zones, when no real network is left in them.
DELETE FROM locations l
WHERE l.name IN ('Main Campus', 'Downtown Office')
  AND NOT EXISTS (SELECT 1 FROM zones z JOIN networks n ON n.zone_id = z.id WHERE z.location_id = l.id);

COMMIT;

-- What is left (it must say 0 in the first three rows).
SELECT 'Redes simuladas' AS que, count(*) AS cantidad FROM networks WHERE data_source_type = 'SIMULATION'
UNION ALL
SELECT 'Mediciones simuladas', count(*) FROM measurements WHERE source = 'SIMULATION'
UNION ALL
SELECT 'Predicciones sobre datos simulados', count(*) FROM ai_predictions WHERE simulated_data
UNION ALL
SELECT 'Redes del equipo que quedan', count(*) FROM networks
UNION ALL
SELECT 'Cuentas', count(*) FROM users
UNION ALL
SELECT 'Redes de Mi Wi-Fi', count(*) FROM home_networks;
