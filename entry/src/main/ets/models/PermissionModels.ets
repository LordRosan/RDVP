export enum PermissionCode {
  ArchiveDeviceRead = 'ARCHIVE_DEVICE_READ',
  ArchiveDeviceCreate = 'ARCHIVE_DEVICE_CREATE',
  ArchiveDeviceDelete = 'ARCHIVE_DEVICE_DELETE',
  ArchiveChangeRequestCreate = 'ARCHIVE_CHANGE_REQUEST_CREATE',
  OpsDeviceVerify = 'OPS_DEVICE_VERIFY',
  OpsFaultReportCreate = 'OPS_FAULT_REPORT_CREATE',
  OpsRepairTaskAccept = 'OPS_REPAIR_TASK_ACCEPT',
  OpsRepairReportCreate = 'OPS_REPAIR_REPORT_CREATE',
  OpsReinspectionCreate = 'OPS_REINSPECTION_CREATE',
  MgmtArchiveChangeReview = 'MGMT_ARCHIVE_CHANGE_REVIEW',
  MgmtAuditLogRead = 'MGMT_AUDIT_LOG_READ'
}

export const ArchiveCenterPermissions: string[] = [
  PermissionCode.ArchiveDeviceRead,
  PermissionCode.ArchiveDeviceCreate,
  PermissionCode.ArchiveDeviceDelete,
  PermissionCode.ArchiveChangeRequestCreate
];

export const OperationsCenterPermissions: string[] = [
  PermissionCode.OpsDeviceVerify,
  PermissionCode.OpsFaultReportCreate,
  PermissionCode.OpsRepairTaskAccept,
  PermissionCode.OpsRepairReportCreate,
  PermissionCode.OpsReinspectionCreate
];

export const ManagementCenterPermissions: string[] = [
  PermissionCode.MgmtArchiveChangeReview,
  PermissionCode.MgmtAuditLogRead
];

export const AllPermissionCodes: string[] = [
  PermissionCode.ArchiveDeviceRead,
  PermissionCode.ArchiveDeviceCreate,
  PermissionCode.ArchiveDeviceDelete,
  PermissionCode.ArchiveChangeRequestCreate,
  PermissionCode.OpsDeviceVerify,
  PermissionCode.OpsFaultReportCreate,
  PermissionCode.OpsRepairTaskAccept,
  PermissionCode.OpsRepairReportCreate,
  PermissionCode.OpsReinspectionCreate,
  PermissionCode.MgmtArchiveChangeReview,
  PermissionCode.MgmtAuditLogRead
];
