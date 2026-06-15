ALTER TABLE IF EXISTS device_change_requests
    RENAME TO device_archive_change_requests;

ALTER INDEX IF EXISTS device_change_requests_pkey
    RENAME TO device_archive_change_requests_pkey;
ALTER INDEX IF EXISTS idx_device_change_requests_device_status
    RENAME TO idx_device_archive_change_requests_device_status;
ALTER INDEX IF EXISTS idx_device_change_requests_freeze_until
    RENAME TO idx_device_archive_change_requests_freeze_until;
ALTER INDEX IF EXISTS ux_device_change_requests_pending_device
    RENAME TO ux_device_archive_change_requests_pending_device;
ALTER INDEX IF EXISTS ux_device_change_requests_pending_target_code
    RENAME TO ux_device_archive_change_requests_pending_target_code;
ALTER INDEX IF EXISTS idx_device_change_requests_initiated_at
    RENAME TO idx_device_archive_change_requests_initiated_at;

CREATE INDEX IF NOT EXISTS idx_device_archive_change_requests_device_status
    ON device_archive_change_requests(device_id, status);
CREATE INDEX IF NOT EXISTS idx_device_archive_change_requests_freeze_until
    ON device_archive_change_requests(freeze_until);
CREATE UNIQUE INDEX IF NOT EXISTS ux_device_archive_change_requests_pending_device
    ON device_archive_change_requests(device_id)
    WHERE status = 'PENDING_REVIEW';
CREATE UNIQUE INDEX IF NOT EXISTS ux_device_archive_change_requests_pending_target_code
    ON device_archive_change_requests(target_device_code)
    WHERE status = 'PENDING_REVIEW';
CREATE INDEX IF NOT EXISTS idx_device_archive_change_requests_initiated_at
    ON device_archive_change_requests(initiated_at DESC);

INSERT INTO user_permissions (user_id, permission_code)
SELECT user_id, 'ARCHIVE_DEVICE_CHANGE_REQUEST_CREATE'
FROM user_permissions
WHERE permission_code = 'ARCHIVE_CHANGE_REQUEST_CREATE'
ON CONFLICT (user_id, permission_code) DO NOTHING;

INSERT INTO user_permissions (user_id, permission_code)
SELECT user_id, 'MGMT_DEVICE_ARCHIVE_CHANGE_REQUEST_REVIEW'
FROM user_permissions
WHERE permission_code = 'MGMT_ARCHIVE_CHANGE_REVIEW'
ON CONFLICT (user_id, permission_code) DO NOTHING;

DELETE FROM user_permissions
WHERE permission_code IN ('ARCHIVE_CHANGE_REQUEST_CREATE', 'MGMT_ARCHIVE_CHANGE_REVIEW');
