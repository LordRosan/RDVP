CREATE TABLE IF NOT EXISTS operations_review_requests (
    id VARCHAR(64) PRIMARY KEY,
    request_type VARCHAR(32) NOT NULL,
    target_id VARCHAR(64) NOT NULL,
    target_no VARCHAR(64) NOT NULL,
    fault_report_id VARCHAR(64) NOT NULL REFERENCES fault_reports(id),
    device_id VARCHAR(64) NOT NULL REFERENCES devices(id),
    operator_id VARCHAR(64) NOT NULL,
    summary TEXT NOT NULL,
    status VARCHAR(32) NOT NULL,
    submitted_at TIMESTAMPTZ NOT NULL,
    review_operator_id VARCHAR(64),
    review_comment TEXT,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_operations_review_requests_target
    ON operations_review_requests(request_type, target_id);
CREATE INDEX IF NOT EXISTS idx_operations_review_requests_status_submitted
    ON operations_review_requests(status, submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_operations_review_requests_review_operator
    ON operations_review_requests(review_operator_id, reviewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_operations_review_requests_fault
    ON operations_review_requests(fault_report_id);
