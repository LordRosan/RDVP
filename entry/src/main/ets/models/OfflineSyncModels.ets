export enum OfflineSyncItemStatus {
  Pending = 'PENDING',
  Syncing = 'SYNCING',
  Synced = 'SYNCED',
  Failed = 'FAILED'
}

export enum OfflineSyncOperationType {
  FaultReportCreate = 'FAULT_REPORT_CREATE',
  DeviceVerificationCreate = 'DEVICE_VERIFICATION_CREATE',
  DeviceVerificationFaultReportCreate = 'DEVICE_VERIFICATION_FAULT_REPORT_CREATE'
}

export enum OfflineSyncBatchStatus {
  Completed = 'COMPLETED',
  PartiallyFailed = 'PARTIALLY_FAILED',
  Failed = 'FAILED'
}

export interface OfflineSyncItem {
  id: string;
  operationType: string;
  payloadSummary: string;
  payloadJson: string;
  operatorName: string;
  status: OfflineSyncItemStatus;
  createdAt: string;
  updatedAt: string;
  retryCount: number;
  nextRetryAt?: string;
  conflictKey?: string;
  serverVersion?: string;
  lastError?: string;
}

export interface OfflineSyncSummary {
  pendingCount: number;
  syncingCount: number;
  failedCount: number;
  readyToSyncCount: number;
  autoSyncEnabled: boolean;
  autoSyncBatchLimit: number;
  waitingForNetworkStability: boolean;
  networkPaused: boolean;
  logThrottleEnabled: boolean;
  recoveryReadyAt?: string;
  latestUpdatedAt?: string;
}

export interface OfflineSyncRuntimeState {
  networkPaused: boolean;
  logThrottleEnabled: boolean;
  autoSyncEnabled: boolean;
  autoSyncBatchLimit: number;
  onlineRecoveryReadyAt?: string;
  lastTransitionAt?: string;
  lastTransitionReason?: string;
}

export interface OfflineSyncSettings {
  autoSyncEnabled: boolean;
  autoSyncBatchLimit: number;
}

export interface OfflineSyncTransitionPreparation {
  success: boolean;
  message: string;
  waitingForNetworkStability: boolean;
}

export interface FaultReportOfflineSyncPayload {
  deviceCode: string;
  faultType: string;
  severity: string;
  occurredAt: string;
  description: string;
  sceneCondition: string;
  localReportNo: string;
  queuedAt: string;
}

export interface DeviceVerificationOfflineSyncPayload {
  deviceCode: string;
  result: string;
  description: string;
  remark: string;
  verifiedAt: string;
  localRecordId: string;
  queuedAt: string;
}

export interface DeviceVerificationFaultReportOfflineSyncPayload {
  deviceCode: string;
  result: string;
  description: string;
  remark: string;
  verifiedAt: string;
  faultType: string;
  severity: string;
  occurredAt: string;
  faultDescription: string;
  sceneCondition: string;
  localRecordId: string;
  localReportNo: string;
  queuedAt: string;
}

export interface OfflineSyncExecutionResult {
  processedCount: number;
  syncedCount: number;
  failedCount: number;
  skippedCount: number;
  message: string;
}

export interface OfflineSyncRecordRequest {
  clientRecordId: string;
  recordType: string;
  payload: object;
  createdOfflineAt: string;
}

export interface OfflineSyncBatchRequest {
  clientBatchId: string;
  records: OfflineSyncRecordRequest[];
}

export interface OfflineSyncRecordResult {
  clientRecordId: string;
  recordType: string;
  success: boolean;
  serverRecordId?: string;
  errorCode?: string;
  errorMessage?: string;
}

export interface OfflineSyncBatchResult {
  clientBatchId: string;
  status: OfflineSyncBatchStatus;
  results: OfflineSyncRecordResult[];
}
