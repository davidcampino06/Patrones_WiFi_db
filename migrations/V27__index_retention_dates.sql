-- Avance 11: indexes by date for the nightly cleanup of old data. The monitoring writes measurements and traffic of
-- every university network every few seconds; the backend deletes what is older than the retention period with
-- "DELETE ... WHERE <date> < :limit" over all networks at once. The existing indexes start with the network, so they
-- cannot answer "everything before this date"; without these the cleanup would read each table completely every night.
CREATE INDEX idx_measurements_measured_at ON measurements (measured_at);
CREATE INDEX idx_traffic_observations_observed_at ON traffic_observations (observed_at);
CREATE INDEX idx_traffic_sessions_started_at ON traffic_sessions (started_at);
CREATE INDEX idx_protocol_statistics_period_start ON protocol_statistics (period_start);
CREATE INDEX idx_analysis_results_created_at ON analysis_results (created_at);
CREATE INDEX idx_agent_alerts_created_at ON agent_alerts (created_at);
CREATE INDEX idx_agent_pairing_codes_expires_at ON agent_pairing_codes (expires_at);

-- Only resolved alerts are ever deleted: open and acknowledged ones stay until someone resolves them.
CREATE INDEX idx_alerts_resolved_at ON alerts (resolved_at) WHERE status = 'RESOLVED';
