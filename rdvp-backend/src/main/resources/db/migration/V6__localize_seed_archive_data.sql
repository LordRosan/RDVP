UPDATE devices
SET name = '冷却泵A-01',
    manufacturer = '北方设备',
    address = '一号厂房动力区',
    updated_at = NOW()
WHERE id = 'device-local-0001'
  AND name = 'Cooling Pump A-01'
  AND manufacturer = 'North Equipment'
  AND address = 'Plant 1 Power Area';

UPDATE devices
SET name = '输送线B-02',
    manufacturer = '南部自动化',
    address = '二号厂房包装区',
    updated_at = NOW()
WHERE id = 'device-local-0002'
  AND name = 'Conveyor Line B-02'
  AND manufacturer = 'South Automation'
  AND address = 'Plant 2 Packaging Area';

UPDATE devices
SET name = '储能柜C-03',
    manufacturer = '东部能源',
    address = '三号厂房储能区',
    updated_at = NOW()
WHERE id = 'device-local-0003'
  AND name = 'Energy Cabinet C-03'
  AND manufacturer = 'East Energy'
  AND address = 'Plant 3 Energy Storage Area';

UPDATE device_change_requests
SET reason = '现场标识位置需要修正档案。',
    changes = '{"location.address":{"oldValue":"二号厂房包装区","newValue":"二号厂房包装区A段"}}'::jsonb,
    updated_at = NOW()
WHERE id = 'DCR-LOCAL-0002'
  AND reason = 'Site marker location requires archive correction.'
  AND changes = '{"location.address":{"oldValue":"Plant 2 Packaging Area","newValue":"Plant 2 Packaging Area Section A"}}'::jsonb;
