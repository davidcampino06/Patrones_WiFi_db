-- Avance 11: the rules that were only in the backend are now also in the database, so data loaded from DBeaver or a
-- script cannot break them either. Every row that the application wrote already follows them.

-- Places of the university networks: a name made only of spaces is not a name.
ALTER TABLE locations
    ADD CONSTRAINT ck_locations_name CHECK (length(btrim(name)) > 0),
    ADD CONSTRAINT ck_locations_address CHECK (address IS NULL OR length(btrim(address)) > 0),
    ADD CONSTRAINT ck_locations_city CHECK (city IS NULL OR length(btrim(city)) > 0);

-- Floors go from basements to tall buildings; anything outside is a typo.
ALTER TABLE zones
    ADD CONSTRAINT ck_zones_name CHECK (length(btrim(name)) > 0),
    ADD CONSTRAINT ck_zones_floor CHECK (floor IS NULL OR floor BETWEEN -10 AND 200);

-- The JSON columns always hold one object ({...}), never a bare number, text or list: the backend and the frontend
-- read named fields from them.
ALTER TABLE agent_reports
    ADD CONSTRAINT ck_agent_reports_details_object CHECK (jsonb_typeof(details) = 'object');
ALTER TABLE connection_tests
    ADD CONSTRAINT ck_connection_tests_quality_object
        CHECK (quality_details IS NULL OR jsonb_typeof(quality_details) = 'object');

-- Agent alerts carry a readable sentence for the user.
ALTER TABLE agent_alerts
    ADD CONSTRAINT ck_agent_alerts_detail CHECK (length(btrim(detail)) > 0);
