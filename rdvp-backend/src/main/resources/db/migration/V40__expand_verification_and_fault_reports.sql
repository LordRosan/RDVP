ALTER TABLE operations_device_verification_reports
    ADD COLUMN IF NOT EXISTS verification_type VARCHAR(32) NOT NULL DEFAULT 'ROUTINE',
    ADD COLUMN IF NOT EXISTS device_status VARCHAR(32) NOT NULL DEFAULT 'UNKNOWN',
    ADD COLUMN IF NOT EXISTS verification_method VARCHAR(32) NOT NULL DEFAULT 'ONSITE_OBSERVATION';

CREATE TABLE IF NOT EXISTS operations_device_verification_report_items (
    verification_report_id VARCHAR(64) NOT NULL,
    item_code VARCHAR(64) NOT NULL,
    item_name VARCHAR(100) NOT NULL,
    result VARCHAR(32) NOT NULL,
    display_order INTEGER NOT NULL,
    CONSTRAINT pk_operations_device_verification_report_items
        PRIMARY KEY (verification_report_id, item_code),
    CONSTRAINT fk_operations_device_verification_report_items_report
        FOREIGN KEY (verification_report_id)
        REFERENCES operations_device_verification_reports(id)
        ON DELETE CASCADE,
    CONSTRAINT ck_operations_device_verification_report_items_result
        CHECK (result IN ('PASSED', 'FAILED', 'NOT_APPLICABLE')),
    CONSTRAINT ck_operations_device_verification_report_items_display_order
        CHECK (display_order > 0)
);

CREATE INDEX IF NOT EXISTS idx_operations_device_verification_report_items_report_order
    ON operations_device_verification_report_items(verification_report_id, display_order);

ALTER TABLE operations_fault_reports
    ADD COLUMN IF NOT EXISTS fault_subtype VARCHAR(64) NOT NULL DEFAULT 'OTHER';
