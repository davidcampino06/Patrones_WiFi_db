-- Assertions shared by every *_test.sql file (included with \ir). They live in pg_temp, so they disappear with the
-- session and never touch the real schema. A failed assertion raises an error and, with ON_ERROR_STOP, stops psql.
\set ON_ERROR_STOP on
SET client_min_messages = notice;

-- TRUE passes; FALSE and NULL (for example a row that does not exist) fail.
CREATE OR REPLACE FUNCTION pg_temp.assert_true(condition BOOLEAN, description TEXT) RETURNS VOID AS $$
BEGIN
    IF condition IS NOT TRUE THEN
        RAISE EXCEPTION 'FAILED: %', description;
    END IF;
    RAISE NOTICE 'PASSED: %', description;
END;
$$ LANGUAGE plpgsql;

-- The statement must be rejected by a constraint of the schema.
CREATE OR REPLACE FUNCTION pg_temp.assert_rejected(statement TEXT, description TEXT) RETURNS VOID AS $$
BEGIN
    BEGIN
        EXECUTE statement;
    EXCEPTION WHEN integrity_constraint_violation OR check_violation OR unique_violation
                   OR foreign_key_violation OR not_null_violation THEN
        RAISE NOTICE 'PASSED: %', description;
        RETURN;
    END;
    RAISE EXCEPTION 'FAILED: % (statement was accepted)', description;
END;
$$ LANGUAGE plpgsql;

-- The statement must be refused for lack of privileges (the application role trying to change the schema).
CREATE OR REPLACE FUNCTION pg_temp.assert_denied(statement TEXT, description TEXT) RETURNS VOID AS $$
BEGIN
    BEGIN
        EXECUTE statement;
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'PASSED: %', description;
        RETURN;
    END;
    RAISE EXCEPTION 'FAILED: % (statement was allowed)', description;
END;
$$ LANGUAGE plpgsql;

-- Query plan as text, to check that a query can use a given index (EXPLAIN does not run the query).
CREATE OR REPLACE FUNCTION pg_temp.plan_of(query TEXT) RETURNS TEXT AS $$
DECLARE
    line TEXT;
    plan TEXT := '';
BEGIN
    FOR line IN EXECUTE 'EXPLAIN ' || query LOOP
        plan := plan || line || E'\n';
    END LOOP;
    RETURN plan;
END;
$$ LANGUAGE plpgsql;
