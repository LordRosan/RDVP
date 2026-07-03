import { AppTone } from '../../shared/theme/AppTheme';

export enum HomeActionId {
  ArchiveCenter = 'ARCHIVE_CENTER',
  OperationsCenter = 'OPERATIONS_CENTER',
  ReviewCenter = 'REVIEW_CENTER',
  LogCenter = 'LOG_CENTER',
  DeviceArchiveQuery = 'DEVICE_ARCHIVE_QUERY',
  DeviceArchiveCreateRequest = 'DEVICE_ARCHIVE_CREATE_REQUEST',
  DeviceVerificationAndFaultReport = 'DEVICE_VERIFICATION_AND_FAULT_REPORT',
  TaskAcceptance = 'TASK_ACCEPTANCE',
  RepairAndReinspection = 'REPAIR_AND_REINSPECTION',
  DeviceArchiveReview = 'DEVICE_ARCHIVE_REVIEW',
  OperationsReview = 'OPERATIONS_REVIEW',
  ArchiveLogQuery = 'ARCHIVE_LOG_QUERY',
  OperationsLogQuery = 'OPERATIONS_LOG_QUERY'
}

export interface HomeAction {
  id: HomeActionId;
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

export interface ReviewDashboardStats {
  reviewedTotal?: number;
  pendingArchiveReviews?: number;
  pendingOperationsReviews?: number;
}

export interface LogDashboardStats {
  logTotal: number;
  archiveOperationLogs?: number;
  archiveReviewLogs?: number;
  operationsOperationLogs?: number;
  operationsReviewLogs?: number;
}

export interface HomeDashboard {
  archive?: ArchiveDashboardStats;
  operations?: OperationsDashboardStats;
  review?: ReviewDashboardStats;
  log?: LogDashboardStats;
}

export interface DashboardMetric {
  label: string;
  value: number;
}
