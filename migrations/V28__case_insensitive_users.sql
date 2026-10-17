-- Avance 11: one account per username and per email, whatever the upper or lower case.
-- Before, "Ana" and "ana" (or Ana@Gmail.com and ana@gmail.com) could become two different accounts while the login,
-- the registration and the password recovery compare them ignoring case: the recovery could then find two accounts
-- for one email. Emails are now stored in lower case (accounts without email get "<username>@wifisense.local", which
-- kept the capitals of the username).

-- Stop with a clear message instead of failing halfway if the data already has such duplicates.
-- tests/revisar_antes_de_aplicar.sql lists them so they can be fixed first.
DO $$
DECLARE
    repeated TEXT;
BEGIN
    SELECT string_agg(value, ', ') INTO repeated FROM (
        SELECT 'usuario ' || lower(username) AS value FROM users GROUP BY lower(username) HAVING count(*) > 1
        UNION ALL
        SELECT 'correo ' || lower(email) FROM users GROUP BY lower(email) HAVING count(*) > 1
    ) AS duplicates;
    IF repeated IS NOT NULL THEN
        RAISE EXCEPTION 'V28: hay cuentas que solo se diferencian en mayúsculas (%). Unifícalas antes de aplicar.',
            repeated;
    END IF;
END $$;

UPDATE users SET email = lower(btrim(email)) WHERE email <> lower(btrim(email));

-- The case-insensitive unique indexes replace the exact ones for emails (and the plain lookup index of V20). The exact
-- unique constraint on username stays: the backend still finds an account by its exact name.
ALTER TABLE users DROP CONSTRAINT uq_users_email;
DROP INDEX idx_users_email_lower;
CREATE UNIQUE INDEX uq_users_email_lower ON users (lower(email));
CREATE UNIQUE INDEX uq_users_username_lower ON users (lower(username));

-- The database itself stores every email trimmed and in lower case, whoever writes it: the backend of Avance 10 still
-- builds "Pedro@wifisense.local" for accounts without email, and that registration must keep working.
CREATE FUNCTION normalize_user_email() RETURNS trigger AS $$
BEGIN
    NEW.email := lower(btrim(NEW.email));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_normalize_email
    BEFORE INSERT OR UPDATE OF email ON users
    FOR EACH ROW EXECUTE FUNCTION normalize_user_email();

ALTER TABLE users
    ADD CONSTRAINT ck_users_email_lower CHECK (email = lower(email)),
    ADD CONSTRAINT ck_users_email_format CHECK (email ~ '^[^@[:space:]]+@[^@[:space:]]+$');
