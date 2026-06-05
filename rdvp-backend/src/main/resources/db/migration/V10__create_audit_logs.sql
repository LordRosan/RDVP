CREATE TABLE IF NOT EXISTS audit_logs (
    id VARCHAR(64) PRIMARY KEY,
    action VARCHAR(64) NOT NULL,
    target_id VARCHAR(128),
    target_no VARCHAR(128),
    actor_id VARCHAR(64),
    actor_name VARCHAR(128),
    status VARCHAR(32) NOT NULL,
    description VARCHAR(500),
    occurred_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_occurred_at ON audit_logs(occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action_occurred_at ON audit_logs(action, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_occurred_at ON audit_logs(actor_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON audit_logs(target_id, target_no);
