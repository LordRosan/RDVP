export enum PermissionCode {
  DeviceRead = 'DEVICE_READ',
  DeviceVerify = 'DEVICE_VERIFY',
  DeviceChangeRequestCreate = 'DEVICE_CHANGE_REQUEST_CREATE',
  DeviceChangeReview = 'DEVICE_CHANGE_REVIEW',
  FaultReportCreate = 'FAULT_REPORT_CREATE',
  RepairTaskAccept = 'REPAIR_TASK_ACCEPT',
  RepairReportCreate = 'REPAIR_REPORT_CREATE',
  ReinspectionCreate = 'REINSPECTION_CREATE',
  AuditLogRead = 'AUDIT_LOG_READ'
}

export const ArchiveCenterPermissions: string[] = [
  PermissionCode.DeviceRead
];

export const OperationsCenterPermissions: string[] = [
  PermissionCode.DeviceVerify,
  PermissionCode.FaultReportCreate,
  PermissionCode.RepairTaskAccept,
  PermissionCode.RepairReportCreate,
  PermissionCode.ReinspectionCreate
];

export const ManagementCenterPermissions: string[] = [
  PermissionCode.DeviceChangeReview,
  PermissionCode.AuditLogRead
];
