CREATE TABLE IF NOT EXISTS password_verification_attempts (
    user_id VARCHAR(64) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    failed_count INTEGER NOT NULL CHECK (failed_count >= 0),
    locked_until TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_password_verification_attempts_locked_until
    ON password_verification_attempts(locked_until);
