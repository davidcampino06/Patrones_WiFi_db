-- Avance 11: data dictionary inside the database (part 2 of 3: analyses, AI predictions and team alerts).

COMMENT ON TABLE analysis_results IS 'Análisis de una red: por umbrales, estadístico o detección de anomalías con IA (patrón Strategy).';
COMMENT ON COLUMN analysis_results.id IS 'Identificador del análisis.';
COMMENT ON COLUMN analysis_results.network_id IS 'Red analizada.';
COMMENT ON COLUMN analysis_results.requested_by IS 'Cuenta que lo pidió; NULL si lo hizo el monitoreo automático o si la cuenta se borró.';
COMMENT ON COLUMN analysis_results.analysis_type IS 'THRESHOLD, STATISTICAL o ANOMALY_DETECTION.';
COMMENT ON COLUMN analysis_results.detected_status IS 'Estado que concluyó: NORMAL, WARNING o CRITICAL.';
COMMENT ON COLUMN analysis_results.score IS 'Gravedad de 0 a 1.';
COMMENT ON COLUMN analysis_results.summary IS 'Resumen legible del resultado.';
COMMENT ON COLUMN analysis_results.measurement_count IS 'Mediciones usadas.';
COMMENT ON COLUMN analysis_results.created_at IS 'Momento del análisis.';

COMMENT ON TABLE ai_predictions IS 'Veredicto del servicio de IA (Isolation Forest) para un análisis de detección de anomalías.';
COMMENT ON COLUMN ai_predictions.id IS 'Identificador.';
COMMENT ON COLUMN ai_predictions.analysis_result_id IS 'Análisis al que pertenece; uno por análisis.';
COMMENT ON COLUMN ai_predictions.network_id IS 'Red analizada.';
COMMENT ON COLUMN ai_predictions.anomaly_detected IS 'TRUE si la IA encontró una anomalía.';
COMMENT ON COLUMN ai_predictions.anomaly_score IS 'Puntaje de anomalía de 0 a 1 (más alto, más raro).';
COMMENT ON COLUMN ai_predictions.severity IS 'NONE, LOW, MEDIUM o HIGH.';
COMMENT ON COLUMN ai_predictions.message IS 'Explicación del resultado.';
COMMENT ON COLUMN ai_predictions.recommendation IS 'Qué hacer; por reglas o generado con Claude.';
COMMENT ON COLUMN ai_predictions.model_version IS 'Versión del modelo que respondió.';
COMMENT ON COLUMN ai_predictions.simulated_data IS 'TRUE si los datos analizados eran simulados.';
COMMENT ON COLUMN ai_predictions.created_at IS 'Momento de la predicción.';
COMMENT ON COLUMN ai_predictions.recommendation_source IS 'RULES (reglas) o CLAUDE (IA generativa).';
COMMENT ON COLUMN ai_predictions.anomaly_type IS 'Causa probable (CONGESTION, INTERFERENCE...); NULL en predicciones anteriores al diagnóstico.';

COMMENT ON TABLE alerts IS 'Alertas para el equipo sobre las redes de la universidad: OPEN, ACKNOWLEDGED o RESOLVED.';
COMMENT ON COLUMN alerts.id IS 'Identificador.';
COMMENT ON COLUMN alerts.network_id IS 'Red afectada.';
COMMENT ON COLUMN alerts.analysis_result_id IS 'Análisis que la generó, si lo hubo.';
COMMENT ON COLUMN alerts.severity IS 'INFO, WARNING o CRITICAL.';
COMMENT ON COLUMN alerts.message IS 'Texto de la alerta.';
COMMENT ON COLUMN alerts.status IS 'OPEN, ACKNOWLEDGED o RESOLVED; solo cambia por las transiciones válidas.';
COMMENT ON COLUMN alerts.created_at IS 'Momento en que se generó.';
COMMENT ON COLUMN alerts.resolved_at IS 'Momento en que se resolvió; solo existe si está RESOLVED.';
