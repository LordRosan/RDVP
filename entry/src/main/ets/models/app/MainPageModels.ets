import { AppTone } from '../../styles/AppTheme';

export enum MainPageActionId {
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
  OperationsRecordQuery = 'OPERATIONS_RECORD_QUERY',
  ReviewRecordQuery = 'REVIEW_RECORD_QUERY',
  RecordQuery = 'RECORD_QUERY'
}

export interface MainPageAction {
  id: MainPageActionId;
  title: string;
  tone: AppTone;
}

export interface ArchiveDashboardStats {
  deviceTotal: number;
  archiveCreates: number;
  archiveDeletes: number;
  archiveUpdates: number;
  archiveQueries: number;
  archiveExports: number;
}

export interface OperationsDashboardStats {
  taskPoolTotal: number;
  verifications: number;
  faultReports: number;
  repairs: number;
  reinspections: number;
}

export interface ManagementDashboardStats {
  reviewedTotal?: number;
  pendingArchiveReviews?: number;
  pendingOperationsReviews?: number;
}

export interface MainPageDashboard {
  archive?: ArchiveDashboardStats;
  operations?: OperationsDashboardStats;
  management?: ManagementDashboardStats;
}

export interface DashboardMetric {
  label: string;
  value: number;
}
