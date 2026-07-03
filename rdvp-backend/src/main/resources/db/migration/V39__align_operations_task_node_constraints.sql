DROP INDEX IF EXISTS ux_operations_repair_tasks_active_fault;

CREATE UNIQUE INDEX IF NOT EXISTS ux_operations_repair_tasks_active_fault_node
    ON operations_repair_tasks(fault_report_id)
    WHERE status IN ('AVAILABLE', 'ACCEPTED', 'PROCESSING');

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_operations_repair_tasks_parent_task'
    ) THEN
        ALTER TABLE operations_repair_tasks
            ADD CONSTRAINT fk_operations_repair_tasks_parent_task
            FOREIGN KEY (parent_task_id)
            REFERENCES operations_repair_tasks(id);
    END IF;
END
$$;
