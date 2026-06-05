CREATE TABLE IF NOT EXISTS token_sessions (
    id VARCHAR(64) PRIMARY KEY,
    token_hash CHAR(64) NOT NULL UNIQUE,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    client_device_id VARCHAR(128),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_token_sessions_user_expires ON token_sessions(user_id, expires_at DESC);
CREATE INDEX IF NOT EXISTS idx_token_sessions_expires ON token_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_token_sessions_revoked ON token_sessions(revoked_at);
