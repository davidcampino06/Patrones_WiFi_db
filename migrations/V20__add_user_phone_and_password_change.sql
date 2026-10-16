-- Contact data for account recovery and the moment the password last changed.
-- phone: optional, international format (+57 300 123 4567 is stored as +573001234567). It is kept for recovery by
--        SMS later; today the recovery link goes by email.
-- password_changed_at: sessions (tokens) issued before this moment stop working, so changing or resetting the
--        password closes every open session of that account.
ALTER TABLE users
    ADD COLUMN phone VARCHAR(16),
    ADD COLUMN password_changed_at TIMESTAMPTZ,
    ADD CONSTRAINT ck_users_phone CHECK (phone IS NULL OR phone ~ '^\+[1-9][0-9]{7,14}$');

-- Recovery looks the account up by email without caring about upper or lower case.
CREATE INDEX idx_users_email_lower ON users (lower(email));
