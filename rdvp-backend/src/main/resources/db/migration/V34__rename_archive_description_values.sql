UPDATE log_entries
SET description = replace(description, '设备档案', '档案')
WHERE description LIKE '%设备档案%';
