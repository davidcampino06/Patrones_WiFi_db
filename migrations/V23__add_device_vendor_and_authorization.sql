-- The user now sees which devices are connected (as in a Bluetooth list) and can mark one as not allowed.
-- vendor:   maker of the device (Apple, Samsung...), read by the agent from the first bytes of the MAC (the OUI).
--           The MAC itself never leaves the user's computer, so this is at most "an Apple device", never which one.
-- hostname: the name the device announces on the network (for example "iPhone-de-Ana"), resolved by the agent by
--           reverse DNS or NetBIOS. It may be missing when the device does not announce a name.
-- authorized: FALSE means the user flagged it as "not mine". WiFiSense keeps warning while it is connected; the
--           real way to remove it (change the Wi-Fi password) is shown in Mi Wi-Fi, since an app cannot change the
--           router by itself.
ALTER TABLE agent_devices
    ADD COLUMN vendor     VARCHAR(40),
    ADD COLUMN hostname   VARCHAR(63),
    ADD COLUMN authorized BOOLEAN NOT NULL DEFAULT TRUE,
    ADD CONSTRAINT ck_agent_devices_vendor CHECK (vendor IS NULL OR length(btrim(vendor)) > 0),
    ADD CONSTRAINT ck_agent_devices_hostname CHECK (hostname IS NULL OR length(btrim(hostname)) > 0);

-- Unauthorized devices still connected: shown first in Mi Wi-Fi.
CREATE INDEX idx_agent_devices_unauthorized ON agent_devices (home_network_id) WHERE NOT authorized;
