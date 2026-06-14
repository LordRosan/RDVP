ALTER TABLE repair_tasks ADD COLUMN IF NOT EXISTS task_type VARCHAR(16) NOT NULL DEFAULT 'REPAIR';
CREATE INDEX IF NOT EXISTS idx_repair_tasks_maintainer_status_type ON repair_tasks(maintainer_id, status, task_type);
