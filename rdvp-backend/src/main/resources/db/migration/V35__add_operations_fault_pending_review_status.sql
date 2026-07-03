DROP INDEX IF EXISTS ux_operations_fault_reports_active_device;

CREATE UNIQUE INDEX IF NOT EXISTS ux_operations_fault_reports_active_device
    ON operations_fault_reports(device_id)
    WHERE status <> 'CLOSED';
