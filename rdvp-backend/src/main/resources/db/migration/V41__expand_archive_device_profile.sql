ALTER TABLE archive_devices
    ADD COLUMN IF NOT EXISTS image_uri VARCHAR(512),
    ADD COLUMN IF NOT EXISTS device_type VARCHAR(80),
    ADD COLUMN IF NOT EXISTS commissioned_at DATE,
    ADD COLUMN IF NOT EXISTS management_department VARCHAR(120);

UPDATE archive_devices
SET image_uri = CASE id
        WHEN 'device-local-0001' THEN 'rdvp://archive/images/RDVP-DEVICE-0001'
        WHEN 'device-local-0002' THEN 'rdvp://archive/images/RDVP-DEVICE-0002'
        WHEN 'device-local-0003' THEN 'rdvp://archive/images/RDVP-DEVICE-0003'
        ELSE image_uri
    END,
    device_type = CASE id
        WHEN 'device-local-0001' THEN '动力设备'
        WHEN 'device-local-0002' THEN '传输设备'
        WHEN 'device-local-0003' THEN '能源设备'
        ELSE COALESCE(NULLIF(device_type, ''), '通用设备')
    END,
    commissioned_at = CASE id
        WHEN 'device-local-0001' THEN DATE '2024-03-15'
        WHEN 'device-local-0002' THEN DATE '2024-04-10'
        WHEN 'device-local-0003' THEN DATE '2024-05-20'
        ELSE COALESCE(commissioned_at, created_at::date)
    END,
    management_department = CASE id
        WHEN 'device-local-0001' THEN '设备管理部'
        WHEN 'device-local-0002' THEN '运营管理部'
        WHEN 'device-local-0003' THEN '能源管理部'
        ELSE COALESCE(NULLIF(management_department, ''), '设备管理部')
    END,
    updated_at = NOW()
WHERE device_type IS NULL
   OR commissioned_at IS NULL
   OR management_department IS NULL
   OR id IN ('device-local-0001', 'device-local-0002', 'device-local-0003');

ALTER TABLE archive_devices
    ALTER COLUMN device_type SET NOT NULL,
    ALTER COLUMN commissioned_at SET NOT NULL,
    ALTER COLUMN management_department SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_archive_devices_type
    ON archive_devices(device_type);

CREATE INDEX IF NOT EXISTS idx_archive_devices_management_department
    ON archive_devices(management_department);
