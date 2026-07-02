ALTER TABLE IF EXISTS reinspection_records
    RENAME TO reinspection_reports;

ALTER TABLE IF EXISTS reinspection_reports
    RENAME COLUMN reinspection_record_no TO reinspection_report_no;

ALTER INDEX IF EXISTS idx_reinspection_records_fault
    RENAME TO idx_reinspection_reports_fault;

ALTER INDEX IF EXISTS idx_reinspection_records_repair_report
    RENAME TO idx_reinspection_reports_repair_report;

ALTER INDEX IF EXISTS idx_reinspection_records_reinspector
    RENAME TO idx_reinspection_reports_reinspector;

ALTER INDEX IF EXISTS idx_reinspection_records_result
    RENAME TO idx_reinspection_reports_result;

ALTER INDEX IF EXISTS ux_reinspection_records_repair_report
    RENAME TO ux_reinspection_reports_repair_report;

UPDATE audit_logs
SET action = 'REINSPECTION_REPORT'
WHERE action = 'REINSPECTION_RECORD';
