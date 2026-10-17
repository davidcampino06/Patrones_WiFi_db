-- Avance 10: better identification of the devices and the team panel with real data.
--
-- private_mac: TRUE when the device uses a random ("private") MAC address. Phones and tablets do it on every Wi-Fi
--   network (iPhone since iOS 14, Android since 10) so that they cannot be tracked; their maker cannot be known from
--   the MAC, but Mi Wi-Fi can still say "probably a phone or tablet" instead of "unknown device". The agent only sends
--   the flag (a bit of the address): the MAC itself never leaves the user's computer.
ALTER TABLE agent_devices
    ADD COLUMN private_mac BOOLEAN NOT NULL DEFAULT FALSE;

-- Team panel (ADMIN and ANALYST): how many home networks had an anomaly in the last 24 hours, without reading every
-- report. The best-channel recommendation needs no column: it is saved with the rest of the AI verdicts in
-- agent_reports.details.
CREATE INDEX idx_agent_reports_anomalies ON agent_reports (received_at) WHERE anomaly_detected;
