-- Probable cause of each anomaly, given by the AI diagnosis. Predictions saved before this version keep NULL
-- ("sin clasificar"): they were never diagnosed, and inventing a cause for them would be misleading.
ALTER TABLE ai_predictions
    ADD COLUMN anomaly_type VARCHAR(20),
    ADD CONSTRAINT ck_ai_predictions_anomaly_type CHECK (anomaly_type IN (
        'NONE', 'CONGESTION', 'INTERFERENCE', 'WEAK_COVERAGE', 'PROVIDER_ISSUE', 'SUSPICIOUS_TRAFFIC', 'UNKNOWN')),
    -- A detected anomaly always has a cause (UNKNOWN at worst); a normal result never has one.
    ADD CONSTRAINT ck_ai_predictions_anomaly_type_matches CHECK (
        anomaly_type IS NULL OR (anomaly_detected = (anomaly_type <> 'NONE')));

-- Anomalies grouped by cause over a period (summary for the team).
CREATE INDEX idx_ai_predictions_anomaly_type ON ai_predictions (anomaly_type, created_at DESC) WHERE anomaly_detected;
