ALTER TABLE device_archive_requests
    ADD COLUMN IF NOT EXISTS initiated_at TIMESTAMPTZ;

UPDATE device_archive_requests
SET initiated_at = created_at
WHERE initiated_at IS NULL;

ALTER TABLE device_archive_requests
    ALTER COLUMN initiated_at SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_device_archive_requests_initiated_at
    ON device_archive_requests(initiated_at DESC);
