CREATE TABLE IF NOT EXISTS offline_sync_batches (
    id VARCHAR(64) PRIMARY KEY,
    client_batch_id VARCHAR(128) NOT NULL,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id),
    status VARCHAR(32) NOT NULL,
    submitted_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    UNIQUE (user_id, client_batch_id)
);

CREATE INDEX IF NOT EXISTS idx_offline_sync_batches_user_submitted
    ON offline_sync_batches(user_id, submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_offline_sync_batches_status_submitted
    ON offline_sync_batches(status, submitted_at DESC);

CREATE TABLE IF NOT EXISTS offline_sync_records (
    id VARCHAR(64) PRIMARY KEY,
    batch_id VARCHAR(64) NOT NULL REFERENCES offline_sync_batches(id) ON DELETE CASCADE,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id),
    client_record_id VARCHAR(128) NOT NULL,
    record_type VARCHAR(64) NOT NULL,
    payload JSONB NOT NULL,
    payload_hash VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL,
    server_record_id VARCHAR(128),
    error_code VARCHAR(100),
    error_message VARCHAR(500),
    created_offline_at TIMESTAMPTZ NOT NULL,
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL,
    UNIQUE (batch_id, client_record_id)
);

CREATE INDEX IF NOT EXISTS idx_offline_sync_records_user_client_record
    ON offline_sync_records(user_id, client_record_id, processed_at DESC);
CREATE INDEX IF NOT EXISTS idx_offline_sync_records_batch_created
    ON offline_sync_records(batch_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_offline_sync_records_type_status
    ON offline_sync_records(record_type, status);
