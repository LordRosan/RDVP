UPDATE user_roles
SET role_code = 'superadmin'
WHERE role_code = 'SYSTEM_ADMIN';

UPDATE user_roles
SET role_code = 'archiveadmin'
WHERE role_code = 'ARCHIVE_ADMIN';

UPDATE user_roles
SET role_code = 'archivestaff'
WHERE role_code = 'ARCHIVIST';

UPDATE user_roles
SET role_code = 'operationsadmin'
WHERE role_code = 'OPERATIONS_ADMIN';

UPDATE user_roles
SET role_code = 'operationsstaff'
WHERE role_code = 'OPERATIONS_OPERATOR';

UPDATE user_roles
SET role_code = 'admin'
WHERE role_code = 'GENERAL_MANAGER';
