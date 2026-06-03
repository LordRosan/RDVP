CREATE TABLE IF NOT EXISTS device_verification_records (
    id VARCHAR(64) PRIMARY KEY,
    device_id VARCHAR(64) NOT NULL REFERENCES devices(id),
    operator_id VARCHAR(64) NOT NULL,
    result VARCHAR(32) NOT NULL,
    description TEXT NOT NULL,
    remark TEXT,
    verified_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_device_verification_records_device_created
    ON device_verification_records(device_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_device_verification_records_operator_created
    ON device_verification_records(operator_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_device_verification_records_result
    ON device_verification_records(result);
