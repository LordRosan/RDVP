ALTER TABLE devices
    ADD COLUMN IF NOT EXISTS deleted_reason TEXT;

ALTER TABLE device_archive_requests
    ADD COLUMN IF NOT EXISTS request_type VARCHAR(32) NOT NULL DEFAULT 'UPDATE';

ALTER TABLE device_archive_requests
    ADD COLUMN IF NOT EXISTS target_device_code VARCHAR(64);

UPDATE device_archive_requests cr
SET target_device_code = d.device_code
FROM devices d
WHERE cr.device_id = d.id
  AND cr.target_device_code IS NULL;

ALTER TABLE device_archive_requests
    ALTER COLUMN device_id DROP NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_device_archive_requests_pending_target_code
    ON device_archive_requests(target_device_code)
    WHERE status = 'PENDING_REVIEW';
