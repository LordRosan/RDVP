CREATE TABLE IF NOT EXISTS fault_reports (
    id VARCHAR(64) PRIMARY KEY,
    fault_report_no VARCHAR(64) NOT NULL UNIQUE,
    device_id VARCHAR(64) NOT NULL REFERENCES devices(id),
    reporter_id VARCHAR(64) NOT NULL,
    fault_type VARCHAR(32) NOT NULL,
    severity VARCHAR(32) NOT NULL,
    status VARCHAR(32) NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    description TEXT NOT NULL,
    scene_condition TEXT,
    longitude NUMERIC(10, 7),
    latitude NUMERIC(10, 7),
    accepted_task_id VARCHAR(64),
    closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_fault_reports_device_status ON fault_reports(device_id, status);
CREATE INDEX IF NOT EXISTS idx_fault_reports_status_created ON fault_reports(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fault_reports_severity ON fault_reports(severity);
CREATE INDEX IF NOT EXISTS idx_fault_reports_reporter ON fault_reports(reporter_id);

CREATE TABLE IF NOT EXISTS repair_tasks (
    id VARCHAR(64) PRIMARY KEY,
    repair_task_no VARCHAR(64) NOT NULL UNIQUE,
    fault_report_id VARCHAR(64) NOT NULL REFERENCES fault_reports(id),
    maintainer_id VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL,
    accepted_longitude NUMERIC(10, 7),
    accepted_latitude NUMERIC(10, 7),
    accepted_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_repair_tasks_maintainer_status ON repair_tasks(maintainer_id, status);
CREATE INDEX IF NOT EXISTS idx_repair_tasks_fault_status ON repair_tasks(fault_report_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS ux_repair_tasks_active_fault
    ON repair_tasks(fault_report_id)
    WHERE status <> 'REPORT_SUBMITTED';

CREATE TABLE IF NOT EXISTS repair_reports (
    id VARCHAR(64) PRIMARY KEY,
    repair_report_no VARCHAR(64) NOT NULL UNIQUE,
    repair_task_id VARCHAR(64) NOT NULL UNIQUE REFERENCES repair_tasks(id),
    fault_report_id VARCHAR(64) NOT NULL REFERENCES fault_reports(id),
    maintainer_id VARCHAR(64) NOT NULL,
    result VARCHAR(32) NOT NULL,
    repaired_at TIMESTAMPTZ NOT NULL,
    process_description TEXT NOT NULL,
    parts_used TEXT,
    requires_reinspection BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_repair_reports_fault ON repair_reports(fault_report_id);
CREATE INDEX IF NOT EXISTS idx_repair_reports_maintainer ON repair_reports(maintainer_id);
CREATE INDEX IF NOT EXISTS idx_repair_reports_result ON repair_reports(result);

CREATE TABLE IF NOT EXISTS reinspection_records (
    id VARCHAR(64) PRIMARY KEY,
    reinspection_record_no VARCHAR(64) NOT NULL UNIQUE,
    fault_report_id VARCHAR(64) NOT NULL REFERENCES fault_reports(id),
    repair_report_id VARCHAR(64) NOT NULL REFERENCES repair_reports(id),
    reinspector_id VARCHAR(64) NOT NULL,
    result VARCHAR(32) NOT NULL,
    reinspected_at TIMESTAMPTZ NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_reinspection_records_fault ON reinspection_records(fault_report_id);
CREATE INDEX IF NOT EXISTS idx_reinspection_records_repair_report ON reinspection_records(repair_report_id);
CREATE INDEX IF NOT EXISTS idx_reinspection_records_reinspector ON reinspection_records(reinspector_id);
CREATE INDEX IF NOT EXISTS idx_reinspection_records_result ON reinspection_records(result);
