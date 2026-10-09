-- Usernames may be an email address, so the limit grows from 20 to 40 characters.
ALTER TABLE users DROP CONSTRAINT ck_users_username_max_length;
ALTER TABLE users ADD CONSTRAINT ck_users_username_max_length CHECK (char_length(username) <= 40);
