ALTER TABLE IF EXISTS device_verification_records
    RENAME TO device_verification_reports;

ALTER INDEX IF EXISTS idx_device_verification_records_device_created
    RENAME TO idx_device_verification_reports_device_created;

ALTER INDEX IF EXISTS idx_device_verification_records_operator_created
    RENAME TO idx_device_verification_reports_operator_created;

ALTER INDEX IF EXISTS idx_device_verification_records_result
    RENAME TO idx_device_verification_reports_result;
