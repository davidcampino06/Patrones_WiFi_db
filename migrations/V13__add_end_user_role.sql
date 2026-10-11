-- End users register themselves with the USER role; ADMIN, ANALYST and VIEWER remain the team's roles.
ALTER TABLE users DROP CONSTRAINT ck_users_role;
ALTER TABLE users ADD CONSTRAINT ck_users_role CHECK (role IN ('ADMIN', 'ANALYST', 'VIEWER', 'USER'));
