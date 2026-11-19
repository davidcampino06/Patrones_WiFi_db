-- Avance 33: the team keeps two roles, ADMIN (manages the site) and ANALYST (watches and analyses); the read-only
-- VIEWER role is removed. USER stays for the end users who register themselves.
--
-- Nothing is deleted or changed silently: if an account still has VIEWER, the migration stops here and names it, so
-- the administrator decides (delete it or give it another role from Usuarios) and applies V48 again.
-- The audit keeps 'VIEWER' in actor_role: those rows are history and cannot be changed (V47).
DO $$
DECLARE
    remaining TEXT;
BEGIN
    SELECT string_agg(username, ', ' ORDER BY username) INTO remaining FROM users WHERE role = 'VIEWER';
    IF remaining IS NOT NULL THEN
        RAISE EXCEPTION 'V48: estas cuentas todavía tienen el rol VIEWER (observador): %. Bórralas o cámbiales el rol desde Usuarios y vuelve a aplicar V48.', remaining;
    END IF;
END $$;

ALTER TABLE users DROP CONSTRAINT ck_users_role;
ALTER TABLE users ADD CONSTRAINT ck_users_role CHECK (role IN ('ADMIN', 'ANALYST', 'USER'));
-- The old default was VIEWER; an account written without a role now gets the one with the least access.
ALTER TABLE users ALTER COLUMN role SET DEFAULT 'USER';

COMMENT ON TABLE users IS 'Cuentas: el equipo (ADMIN, ANALYST) y los usuarios finales que se registran (USER).';
COMMENT ON COLUMN users.role IS 'ADMIN (gestiona la sede) o ANALYST (vigila y analiza) en el equipo, o USER (usuario final).';
