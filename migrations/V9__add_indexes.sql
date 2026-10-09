-- Indexes follow the backend's real query paths (history by network and time range).
CREATE INDEX idx_zones_location ON zones (location_id);
CREATE INDEX idx_networks_zone ON networks (zone_id);
CREATE INDEX idx_networks_status ON networks (status);
CREATE INDEX idx_devices_network ON devices (network_id);
CREATE INDEX idx_measurements_network_time ON measurements (network_id, measured_at DESC);
CREATE INDEX idx_traffic_observations_network_time ON traffic_observations (network_id, observed_at DESC);
CREATE INDEX idx_traffic_sessions_device_time ON traffic_sessions (device_id, started_at DESC);
CREATE INDEX idx_protocol_statistics_network_time ON protocol_statistics (network_id, period_start DESC);
CREATE INDEX idx_analysis_results_network_time ON analysis_results (network_id, created_at DESC);
CREATE INDEX idx_ai_predictions_anomalies ON ai_predictions (created_at DESC) WHERE anomaly_detected;
CREATE INDEX idx_alerts_open ON alerts (status, created_at DESC);
CREATE INDEX idx_alerts_network ON alerts (network_id);
