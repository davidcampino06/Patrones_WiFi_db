-- The demo accounts had a password published in the repository. Real accounts are created by the backend
-- (administrator from ADMIN_USERNAME / ADMIN_PASSWORD, the rest from the Usuarios page, three at most).
DELETE FROM users
WHERE email IN ('admin@wifisense.local', 'analyst@wifisense.local', 'viewer@wifisense.local')
  AND password_hash = '$2b$10$g0clS2PDVTPgj6azrUjz.uYqNkO/vHsEOKaja/dN4CLemn1OCwSe2';

UPDATE alerts SET message = 'La red entró en estado de advertencia'
WHERE message = 'Network entered WARNING state';

ALTER TABLE users ADD CONSTRAINT ck_users_username_max_length CHECK (char_length(username) <= 20);
