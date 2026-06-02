WITH duplicate_active_faults AS (
    SELECT id
    FROM (
        SELECT
            id,
            ROW_NUMBER() OVER (
                PARTITION BY device_id
                ORDER BY updated_at DESC, created_at DESC, id DESC
            ) AS row_number
        FROM fault_reports
        WHERE status <> 'CLOSED'
    ) ranked_faults
    WHERE row_number > 1
)
UPDATE repair_tasks
SET status = 'REPORT_SUBMITTED',
    completed_at = COALESCE(completed_at, NOW()),
    updated_at = NOW()
WHERE fault_report_id IN (SELECT id FROM duplicate_active_faults)
  AND status <> 'REPORT_SUBMITTED';

WITH duplicate_active_faults AS (
    SELECT id
    FROM (
        SELECT
            id,
            ROW_NUMBER() OVER (
                PARTITION BY device_id
                ORDER BY updated_at DESC, created_at DESC, id DESC
            ) AS row_number
        FROM fault_reports
        WHERE status <> 'CLOSED'
    ) ranked_faults
    WHERE row_number > 1
)
UPDATE fault_reports
SET status = 'CLOSED',
    accepted_task_id = NULL,
    closed_at = COALESCE(closed_at, NOW()),
    updated_at = NOW()
WHERE id IN (SELECT id FROM duplicate_active_faults);

CREATE UNIQUE INDEX IF NOT EXISTS ux_fault_reports_active_device
    ON fault_reports(device_id)
    WHERE status <> 'CLOSED';
