export enum WorkbenchActionId {
  ArchiveCenter = 'ARCHIVE_CENTER',
  OperationsCenter = 'OPERATIONS_CENTER',
  ManagementCenter = 'MANAGEMENT_CENTER',
  DeviceArchiveQuery = 'DEVICE_ARCHIVE_QUERY',
  DeviceArchiveCreateRequest = 'DEVICE_ARCHIVE_CREATE_REQUEST',
  DeviceVerification = 'DEVICE_VERIFICATION',
  TaskAcceptance = 'TASK_ACCEPTANCE',
  RepairReport = 'REPAIR_REPORT',
  ReinspectionReport = 'REINSPECTION_REPORT',
  DeviceArchiveReview = 'DEVICE_ARCHIVE_REVIEW',
  OperationsReview = 'OPERATIONS_REVIEW',
  ArchiveRecordQuery = 'ARCHIVE_RECORD_QUERY',
  OperationRecordQuery = 'OPERATION_RECORD_QUERY',
  ReviewRecordQuery = 'REVIEW_RECORD_QUERY',
  RecordQuery = 'RECORD_QUERY'
}

export interface WorkbenchAction {
  id: WorkbenchActionId;
  title: string;
  tone: string;
}

export interface WorkbenchMetric {
  id: string;
  label: string;
  value: string;
  status: string;
  tone: string;
}

export interface WorkbenchStatusItem {
  id: string;
  name: string;
  value: string;
  tone: string;
}

export interface WorkbenchSummary {
  pendingDeviceArchiveRequests: number;
  taskAcceptanceItems: number;
  repairTasks: number;
  pendingReinspections: number;
}
