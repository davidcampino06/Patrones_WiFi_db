-- Reversión de V48: vuelve a permitir el rol VIEWER (observador). Úsala solo si se vuelve a un backend anterior al
-- Avance 33. No cambia ninguna cuenta. Todo en una transacción: si algo falla, no cambia nada.
BEGIN;
ALTER TABLE users DROP CONSTRAINT ck_users_role;
ALTER TABLE users ADD CONSTRAINT ck_users_role CHECK (role IN ('ADMIN', 'ANALYST', 'VIEWER', 'USER'));
ALTER TABLE users ALTER COLUMN role SET DEFAULT 'VIEWER';
COMMENT ON TABLE users IS 'Cuentas: el equipo (ADMIN, ANALYST, VIEWER) y los usuarios finales que se registran (USER).';
COMMENT ON COLUMN users.role IS 'ADMIN, ANALYST o VIEWER (equipo) o USER (usuario final).';
DO $$ BEGIN
    IF to_regclass('flyway_schema_history') IS NOT NULL THEN
        DELETE FROM flyway_schema_history WHERE version = '48';
    END IF;
END $$;
COMMIT;
