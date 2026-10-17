-- Indexes (V26, V27): every foreign key has an index and the nightly cleanup by date can use one.
-- Runs inside a transaction that is rolled back: it leaves the database exactly as it was.
\ir _asserts.sql
BEGIN;

SELECT pg_temp.assert_true(
    NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        WHERE c.contype = 'f' AND c.connamespace = 'public'::regnamespace
          AND NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.conrelid AND i.indkey[0] = c.conkey[1])),
    'every foreign key has an index that starts with it (deleting a parent never reads a whole child table)');

-- With sequential scans disabled the planner must still find an index: proof that one fits the query.
SET LOCAL enable_seqscan = off;

SELECT pg_temp.assert_true(
    pg_temp.plan_of($$DELETE FROM measurements WHERE measured_at < NOW() - INTERVAL '90 days'$$)
        LIKE '%idx_measurements_measured_at%',
    'old measurements are deleted through idx_measurements_measured_at');
SELECT pg_temp.assert_true(
    pg_temp.plan_of($$DELETE FROM traffic_observations WHERE observed_at < NOW() - INTERVAL '90 days'$$)
        LIKE '%idx_traffic_observations_observed_at%',
    'old traffic observations are deleted through their date index');
SELECT pg_temp.assert_true(
    pg_temp.plan_of($$DELETE FROM traffic_sessions WHERE started_at < NOW() - INTERVAL '90 days'$$)
        LIKE '%idx_traffic_sessions_started_at%',
    'old traffic sessions are deleted through their date index');
SELECT pg_temp.assert_true(
    pg_temp.plan_of($$DELETE FROM protocol_statistics WHERE period_start < NOW() - INTERVAL '90 days'$$)
        LIKE '%idx_protocol_statistics_period_start%',
    'old protocol statistics are deleted through their date index');
SELECT pg_temp.assert_true(
    pg_temp.plan_of($$DELETE FROM analysis_results WHERE created_at < NOW() - INTERVAL '90 days'$$)
        LIKE '%idx_analysis_results_created_at%',
    'old analyses are deleted through their date index');
SELECT pg_temp.assert_true(
    pg_temp.plan_of($$DELETE FROM alerts WHERE status = 'RESOLVED' AND resolved_at < NOW() - INTERVAL '90 days'$$)
        LIKE '%idx_alerts_resolved_at%',
    'only resolved alerts are cleaned, through a partial index');
SELECT pg_temp.assert_true(
    pg_temp.plan_of($$DELETE FROM agent_alerts WHERE created_at < NOW() - INTERVAL '30 days'$$)
        LIKE '%idx_agent_alerts_created_at%',
    'old agent alerts are deleted through their date index');
SELECT pg_temp.assert_true(
    pg_temp.plan_of($$DELETE FROM agent_pairing_codes WHERE expires_at < NOW()$$)
        LIKE '%idx_agent_pairing_codes_expires_at%',
    'expired installation codes are deleted through their date index');
SELECT pg_temp.assert_true(
    pg_temp.plan_of($$DELETE FROM refresh_tokens WHERE expires_at < NOW()$$)
        LIKE '%idx_refresh_tokens_expires_at%',
    'expired refresh tokens are deleted through their date index');

-- The three foreign keys that had no index (V26).
SELECT pg_temp.assert_true(
    pg_temp.plan_of($$SELECT * FROM ai_predictions WHERE network_id = 1 ORDER BY created_at DESC LIMIT 20$$)
        LIKE '%idx_ai_predictions_network%',
    'the predictions of one network come from idx_ai_predictions_network');
SELECT pg_temp.assert_true(
    pg_temp.plan_of($$UPDATE analysis_results SET requested_by = NULL WHERE requested_by = 1$$)
        LIKE '%idx_analysis_results_requested_by%',
    'deleting an account finds its analyses through an index');
SELECT pg_temp.assert_true(
    pg_temp.plan_of($$UPDATE alerts SET analysis_result_id = NULL WHERE analysis_result_id = 1$$)
        LIKE '%idx_alerts_analysis_result%',
    'deleting an analysis finds its alerts through an index');

ROLLBACK;
