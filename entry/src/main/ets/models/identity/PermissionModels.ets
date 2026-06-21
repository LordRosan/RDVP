export enum PermissionCode {
  ArchiveCenterDeviceArchiveQuery = 'ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY',
  ArchiveCenterDeviceArchiveCreateRequestSubmit = 'ARCHIVE_CENTER_DEVICE_ARCHIVE_CREATE_REQUEST_SUBMIT',
  ArchiveCenterDeviceArchiveUpdateRequestSubmit = 'ARCHIVE_CENTER_DEVICE_ARCHIVE_UPDATE_REQUEST_SUBMIT',
  ArchiveCenterDeviceArchiveDeleteRequestSubmit = 'ARCHIVE_CENTER_DEVICE_ARCHIVE_DELETE_REQUEST_SUBMIT',
  ArchiveCenterDeviceArchiveExport = 'ARCHIVE_CENTER_DEVICE_ARCHIVE_EXPORT',
  OperationsCenterDeviceVerificationSubmit = 'OPERATIONS_CENTER_DEVICE_VERIFICATION_SUBMIT',
  OperationsCenterDeviceFaultReportSubmit = 'OPERATIONS_CENTER_DEVICE_FAULT_REPORT_SUBMIT',
  OperationsCenterRepairTaskAccept = 'OPERATIONS_CENTER_REPAIR_TASK_ACCEPT',
  OperationsCenterRepairReportSubmit = 'OPERATIONS_CENTER_REPAIR_REPORT_SUBMIT',
  OperationsCenterReinspectionTaskAccept = 'OPERATIONS_CENTER_REINSPECTION_TASK_ACCEPT',
  OperationsCenterReinspectionReportSubmit = 'OPERATIONS_CENTER_REINSPECTION_REPORT_SUBMIT',
  ManagementCenterDeviceArchiveRequestReview = 'MANAGEMENT_CENTER_DEVICE_ARCHIVE_REQUEST_REVIEW',
  ManagementCenterOperationsReview = 'MANAGEMENT_CENTER_OPERATIONS_REVIEW',
  ManagementCenterArchiveRecordQuery = 'MANAGEMENT_CENTER_ARCHIVE_RECORD_QUERY',
  ManagementCenterOperationRecordQuery = 'MANAGEMENT_CENTER_OPERATION_RECORD_QUERY',
  ManagementCenterReviewRecordQuery = 'MANAGEMENT_CENTER_REVIEW_RECORD_QUERY'
}

export const ArchiveCenterPermissions: string[] = [
  PermissionCode.ArchiveCenterDeviceArchiveQuery,
  PermissionCode.ArchiveCenterDeviceArchiveCreateRequestSubmit,
  PermissionCode.ArchiveCenterDeviceArchiveUpdateRequestSubmit,
  PermissionCode.ArchiveCenterDeviceArchiveDeleteRequestSubmit,
  PermissionCode.ArchiveCenterDeviceArchiveExport
];

export const OperationsCenterPermissions: string[] = [
  PermissionCode.OperationsCenterDeviceVerificationSubmit,
  PermissionCode.OperationsCenterDeviceFaultReportSubmit,
  PermissionCode.OperationsCenterRepairTaskAccept,
  PermissionCode.OperationsCenterRepairReportSubmit,
  PermissionCode.OperationsCenterReinspectionTaskAccept,
  PermissionCode.OperationsCenterReinspectionReportSubmit
];

export const ManagementCenterPermissions: string[] = [
  PermissionCode.ManagementCenterDeviceArchiveRequestReview,
  PermissionCode.ManagementCenterOperationsReview,
  PermissionCode.ManagementCenterArchiveRecordQuery,
  PermissionCode.ManagementCenterOperationRecordQuery,
  PermissionCode.ManagementCenterReviewRecordQuery
];

export const ManagementCenterRecordPermissions: string[] = [
  PermissionCode.ManagementCenterArchiveRecordQuery,
  PermissionCode.ManagementCenterOperationRecordQuery,
  PermissionCode.ManagementCenterReviewRecordQuery
];

export const AllPermissionCodes: string[] = [
  PermissionCode.ArchiveCenterDeviceArchiveQuery,
  PermissionCode.ArchiveCenterDeviceArchiveCreateRequestSubmit,
  PermissionCode.ArchiveCenterDeviceArchiveUpdateRequestSubmit,
  PermissionCode.ArchiveCenterDeviceArchiveDeleteRequestSubmit,
  PermissionCode.ArchiveCenterDeviceArchiveExport,
  PermissionCode.OperationsCenterDeviceVerificationSubmit,
  PermissionCode.OperationsCenterDeviceFaultReportSubmit,
  PermissionCode.OperationsCenterRepairTaskAccept,
  PermissionCode.OperationsCenterRepairReportSubmit,
  PermissionCode.OperationsCenterReinspectionTaskAccept,
  PermissionCode.OperationsCenterReinspectionReportSubmit,
  PermissionCode.ManagementCenterDeviceArchiveRequestReview,
  PermissionCode.ManagementCenterOperationsReview,
  PermissionCode.ManagementCenterArchiveRecordQuery,
  PermissionCode.ManagementCenterOperationRecordQuery,
  PermissionCode.ManagementCenterReviewRecordQuery
];


