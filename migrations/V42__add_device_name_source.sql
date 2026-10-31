-- Avance 24: where the name of each device came from, so the page never presents a guess as a fact.
--
-- The agent (2.0.0) sends, with each name it found, how it found it:
--   CONFIRMED  two independent sources gave the same name (for example the device announced it and the router's
--              DNS answered it too);
--   ANNOUNCED  the device said it itself (mDNS/Bonjour, UPnP, NetBIOS or the host name in its DHCP request);
--   ROUTER     the router of the network answered it (its own DNS knows the names it handed out by DHCP);
--   DNS        a reverse DNS lookup on the system's DNS server.
-- The alias the user writes stays in label, and the maker (vendor) and kind are estimates. A device with none of
-- these is "unknown": the page says so instead of inventing a name. Old agents send no source: it stays NULL.
ALTER TABLE agent_devices
    ADD COLUMN name_source VARCHAR(10),
    ADD CONSTRAINT ck_agent_devices_name_source
        CHECK (name_source IS NULL OR name_source IN ('CONFIRMED', 'ANNOUNCED', 'ROUTER', 'DNS'));

COMMENT ON COLUMN agent_devices.name_source IS
    'De dónde salió el nombre (hostname): CONFIRMED (dos fuentes coinciden), ANNOUNCED (lo dijo el equipo), ROUTER (el DNS del router) o DNS; NULL si no hay nombre o el agente es anterior a 2.0.0.';
