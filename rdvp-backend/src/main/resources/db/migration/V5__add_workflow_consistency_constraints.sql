CREATE UNIQUE INDEX IF NOT EXISTS ux_reinspection_records_repair_report
    ON reinspection_records(repair_report_id);
