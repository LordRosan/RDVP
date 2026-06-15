export enum WorkbenchActionId {
  ArchiveCenter = 'ARCHIVE_CENTER',
  OperationsCenter = 'OPERATIONS_CENTER',
  ManagementCenter = 'MANAGEMENT_CENTER',
  DeviceArchiveQuery = 'DEVICE_ARCHIVE_QUERY',
  DeviceArchiveCreate = 'DEVICE_ARCHIVE_CREATE',
  DeviceVerification = 'DEVICE_VERIFICATION',
  RepairTaskPool = 'REPAIR_TASK_POOL',
  AcceptedRepairTask = 'ACCEPTED_REPAIR_TASK',
  ReinspectionTask = 'REINSPECTION_TASK',
  DeviceArchiveReview = 'DEVICE_ARCHIVE_REVIEW',
  ArchiveRecord = 'ARCHIVE_RECORD',
  OperationsRecord = 'OPERATIONS_RECORD',
  ReviewRecord = 'REVIEW_RECORD',
  RecordCenter = 'RECORD_CENTER'
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
  pendingDeviceArchiveChangeRequests: number;
  repairTaskPoolItems: number;
  acceptedRepairTasks: number;
  pendingReinspections: number;
}
