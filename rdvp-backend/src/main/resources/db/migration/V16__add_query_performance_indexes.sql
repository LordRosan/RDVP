CREATE INDEX IF NOT EXISTS idx_devices_location_geography
    ON devices USING GIST ((ST_MakePoint(longitude, latitude)::geography))
    WHERE longitude IS NOT NULL AND latitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_offline_sync_records_processed_created
    ON offline_sync_records(processed_at DESC NULLS LAST, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_fault_reports_status_updated
    ON fault_reports(status, updated_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_repair_reports_fault_created
    ON repair_reports(fault_report_id, created_at DESC);
