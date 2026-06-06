ALTER TABLE device_change_requests
    ADD COLUMN IF NOT EXISTS initiated_at TIMESTAMPTZ;

UPDATE device_change_requests
SET initiated_at = created_at
WHERE initiated_at IS NULL;

ALTER TABLE device_change_requests
    ALTER COLUMN initiated_at SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_device_change_requests_initiated_at
    ON device_change_requests(initiated_at DESC);
