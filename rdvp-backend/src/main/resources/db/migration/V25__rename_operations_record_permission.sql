UPDATE user_permissions
SET permission_code = 'MANAGEMENT_CENTER_OPERATIONS_RECORD_QUERY'
WHERE permission_code = 'MANAGEMENT_CENTER_OPERATION_RECORD_QUERY'
  AND NOT EXISTS (
    SELECT 1
    FROM user_permissions existing
    WHERE existing.user_id = user_permissions.user_id
      AND existing.permission_code = 'MANAGEMENT_CENTER_OPERATIONS_RECORD_QUERY'
  );

DELETE FROM user_permissions
WHERE permission_code = 'MANAGEMENT_CENTER_OPERATION_RECORD_QUERY';
