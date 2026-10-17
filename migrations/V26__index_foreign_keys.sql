-- Avance 11: the last three foreign keys without an index of their own. Deleting the parent row (a user, a network or
-- an analysis) made PostgreSQL read the whole child table to apply ON DELETE, and the listings of predictions by
-- network had no index to start from. tests/optimizacion_test.sql fails if a foreign key without index appears again.

-- ON DELETE SET NULL when a team account is deleted. Partial: most rows have no requester (automatic monitoring).
CREATE INDEX idx_analysis_results_requested_by ON analysis_results (requested_by) WHERE requested_by IS NOT NULL;

-- ON DELETE CASCADE from networks, and the predictions of one network newest first.
CREATE INDEX idx_ai_predictions_network ON ai_predictions (network_id, created_at DESC);

-- ON DELETE SET NULL when an analysis is deleted. Partial: alerts created by hand have no analysis.
CREATE INDEX idx_alerts_analysis_result ON alerts (analysis_result_id) WHERE analysis_result_id IS NOT NULL;
