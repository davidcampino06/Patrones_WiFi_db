-- Devices the agent has seen on each home network. The agent never sends a MAC address, only a salted SHA-256
-- fingerprint (24 hex characters), so this table says "a device", never which one. It is what makes
-- "new device on your network" possible, and lets the user give each device a name.
CREATE TABLE agent_devices (
    home_network_id  BIGINT      NOT NULL,
    fingerprint      CHAR(24)    NOT NULL,
    label            VARCHAR(40),
    first_seen_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (home_network_id, fingerprint),
    CONSTRAINT fk_agent_devices_network FOREIGN KEY (home_network_id) REFERENCES home_networks (id) ON DELETE CASCADE,
    CONSTRAINT ck_agent_devices_fingerprint CHECK (fingerprint ~ '^[0-9a-f]{24}$'),
    CONSTRAINT ck_agent_devices_label CHECK (label IS NULL OR length(btrim(label)) > 0),
    CONSTRAINT ck_agent_devices_seen CHECK (last_seen_at >= first_seen_at)
);

-- Deletion of devices that have not been seen for the retention period.
CREATE INDEX idx_agent_devices_last_seen ON agent_devices (last_seen_at);
