INSERT INTO user_permissions (user_id, permission_code)
SELECT user_id, 'LOG_CENTER_OPERATIONS_REVIEW_LOG_QUERY'
FROM user_permissions
WHERE permission_code = 'LOG_CENTER_REVIEW_LOG_QUERY'
ON CONFLICT (user_id, permission_code) DO NOTHING;

UPDATE user_permissions
SET permission_code = CASE permission_code
    WHEN 'LOG_CENTER_ARCHIVE_LOG_QUERY' THEN 'LOG_CENTER_ARCHIVE_OPERATION_LOG_QUERY'
    WHEN 'LOG_CENTER_OPERATIONS_LOG_QUERY' THEN 'LOG_CENTER_OPERATIONS_OPERATION_LOG_QUERY'
    WHEN 'LOG_CENTER_REVIEW_LOG_QUERY' THEN 'LOG_CENTER_ARCHIVE_REVIEW_LOG_QUERY'
    ELSE permission_code
END
WHERE permission_code IN (
    'LOG_CENTER_ARCHIVE_LOG_QUERY',
    'LOG_CENTER_OPERATIONS_LOG_QUERY',
    'LOG_CENTER_REVIEW_LOG_QUERY'
);

DELETE FROM user_permissions stale
USING user_permissions kept
WHERE stale.ctid < kept.ctid
  AND stale.user_id = kept.user_id
  AND stale.permission_code = kept.permission_code;
