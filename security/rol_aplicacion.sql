-- Least-privilege role for the backend: it reads and writes the data, but cannot create, change or drop tables, so
-- a bug or an SQL injection in the application can never alter the schema. Migrations keep running with the owner of
-- the database (in Railway, the user postgres), never with this role.
--
-- How to use it (docs/seguridad.md has the step by step):
--   1. Run this whole file as the owner of the database, after the migrations. It can be run again at any time.
--   2. Give it a password by hand (it is never stored in the repository), for example in DBeaver:
--          ALTER ROLE wifisense_app LOGIN PASSWORD 'una-contraseña-larga-y-aleatoria';
--   3. In Railway, point the backend to it: DATABASE_USERNAME=wifisense_app and DATABASE_PASSWORD=<la de arriba>.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'wifisense_app') THEN
        CREATE ROLE wifisense_app NOLOGIN;  -- without a password it cannot log in until step 2
    END IF;
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO wifisense_app', current_database());
END $$;

-- Nothing more than using the schema: no CREATE.
REVOKE ALL ON SCHEMA public FROM wifisense_app;
GRANT USAGE ON SCHEMA public TO wifisense_app;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- Data of every existing table and the sequences of the identity columns.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO wifisense_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO wifisense_app;

-- The history of the migrations belongs to whoever applies them, not to the application.
DO $$
BEGIN
    IF to_regclass('public.flyway_schema_history') IS NOT NULL THEN
        REVOKE ALL ON TABLE flyway_schema_history FROM wifisense_app;
    END IF;
END $$;

-- Tables created by future migrations (run by this same owner) get the same permissions automatically.
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO wifisense_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO wifisense_app;

-- A runaway query or a forgotten open transaction cannot hold the database: the backend never needs more.
ALTER ROLE wifisense_app SET statement_timeout = '30s';
ALTER ROLE wifisense_app SET idle_in_transaction_session_timeout = '60s';
