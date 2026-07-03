ALTER TABLE operations_repair_tasks
    ALTER COLUMN maintainer_id DROP NOT NULL;

ALTER TABLE operations_repair_tasks
    ALTER COLUMN accepted_at DROP NOT NULL;

ALTER TABLE operations_repair_tasks
    ADD COLUMN IF NOT EXISTS parent_task_id VARCHAR(64);

CREATE INDEX IF NOT EXISTS idx_operations_repair_tasks_parent_task
    ON operations_repair_tasks(parent_task_id);
