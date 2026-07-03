export enum PermissionCode {
  ArchiveCenterArchiveQuery = 'ARCHIVE_CENTER_ARCHIVE_QUERY',
  ArchiveCenterArchiveCreateRequestSubmit = 'ARCHIVE_CENTER_ARCHIVE_CREATE_REQUEST_SUBMIT',
  ArchiveCenterArchiveUpdateRequestSubmit = 'ARCHIVE_CENTER_ARCHIVE_UPDATE_REQUEST_SUBMIT',
  ArchiveCenterArchiveDeleteRequestSubmit = 'ARCHIVE_CENTER_ARCHIVE_DELETE_REQUEST_SUBMIT',
  ArchiveCenterArchiveExport = 'ARCHIVE_CENTER_ARCHIVE_EXPORT',
  OperationsCenterDeviceVerificationSubmit = 'OPERATIONS_CENTER_DEVICE_VERIFICATION_SUBMIT',
  OperationsCenterDeviceFaultReportSubmit = 'OPERATIONS_CENTER_DEVICE_FAULT_REPORT_SUBMIT',
  OperationsCenterRepairTaskAccept = 'OPERATIONS_CENTER_REPAIR_TASK_ACCEPT',
  OperationsCenterRepairReportSubmit = 'OPERATIONS_CENTER_REPAIR_REPORT_SUBMIT',
  OperationsCenterReinspectionTaskAccept = 'OPERATIONS_CENTER_REINSPECTION_TASK_ACCEPT',
  OperationsCenterReinspectionReportSubmit = 'OPERATIONS_CENTER_REINSPECTION_REPORT_SUBMIT',
  ReviewCenterArchiveRequestReview = 'REVIEW_CENTER_ARCHIVE_REQUEST_REVIEW',
  ReviewCenterOperationsReview = 'REVIEW_CENTER_OPERATIONS_REVIEW',
  LogCenterArchiveOperationLogQuery = 'LOG_CENTER_ARCHIVE_OPERATION_LOG_QUERY',
  LogCenterArchiveReviewLogQuery = 'LOG_CENTER_ARCHIVE_REVIEW_LOG_QUERY',
  LogCenterOperationsOperationLogQuery = 'LOG_CENTER_OPERATIONS_OPERATION_LOG_QUERY',
  LogCenterOperationsReviewLogQuery = 'LOG_CENTER_OPERATIONS_REVIEW_LOG_QUERY'
}

export const ArchiveCenterPermissions: string[] = [
  PermissionCode.ArchiveCenterArchiveQuery,
  PermissionCode.ArchiveCenterArchiveCreateRequestSubmit,
  PermissionCode.ArchiveCenterArchiveUpdateRequestSubmit,
  PermissionCode.ArchiveCenterArchiveDeleteRequestSubmit,
  PermissionCode.ArchiveCenterArchiveExport
];

export const OperationsCenterPermissions: string[] = [
  PermissionCode.OperationsCenterDeviceVerificationSubmit,
  PermissionCode.OperationsCenterDeviceFaultReportSubmit,
  PermissionCode.OperationsCenterRepairTaskAccept,
  PermissionCode.OperationsCenterRepairReportSubmit,
  PermissionCode.OperationsCenterReinspectionTaskAccept,
  PermissionCode.OperationsCenterReinspectionReportSubmit
];

export const ReviewCenterPermissions: string[] = [
  PermissionCode.ReviewCenterArchiveRequestReview,
  PermissionCode.ReviewCenterOperationsReview
];

export const LogCenterPermissions: string[] = [
  PermissionCode.LogCenterArchiveOperationLogQuery,
  PermissionCode.LogCenterArchiveReviewLogQuery,
  PermissionCode.LogCenterOperationsOperationLogQuery,
  PermissionCode.LogCenterOperationsReviewLogQuery
];

export const AllPermissionCodes: string[] = [
  PermissionCode.ArchiveCenterArchiveQuery,
  PermissionCode.ArchiveCenterArchiveCreateRequestSubmit,
  PermissionCode.ArchiveCenterArchiveUpdateRequestSubmit,
  PermissionCode.ArchiveCenterArchiveDeleteRequestSubmit,
  PermissionCode.ArchiveCenterArchiveExport,
  PermissionCode.OperationsCenterDeviceVerificationSubmit,
  PermissionCode.OperationsCenterDeviceFaultReportSubmit,
  PermissionCode.OperationsCenterRepairTaskAccept,
  PermissionCode.OperationsCenterRepairReportSubmit,
  PermissionCode.OperationsCenterReinspectionTaskAccept,
  PermissionCode.OperationsCenterReinspectionReportSubmit,
  PermissionCode.ReviewCenterArchiveRequestReview,
  PermissionCode.ReviewCenterOperationsReview,
  PermissionCode.LogCenterArchiveOperationLogQuery,
  PermissionCode.LogCenterArchiveReviewLogQuery,
  PermissionCode.LogCenterOperationsOperationLogQuery,
  PermissionCode.LogCenterOperationsReviewLogQuery
];


