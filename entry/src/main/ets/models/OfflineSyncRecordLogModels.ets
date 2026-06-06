export enum OfflineSyncRecordLogStatus {
  Succeeded = 'SUCCEEDED',
  Failed = 'FAILED'
}

export interface OfflineSyncRecordLogSummary {
  batchId: string;
  clientBatchId: string;
  batchStatus: string;
  userId: string;
  operatorName: string;
  clientRecordId: string;
  recordType: string;
  status: string;
  serverRecordId?: string;
  errorCode?: string;
  errorMessage?: string;
  createdOfflineAt: string;
  submittedAt: string;
  processedAt?: string;
}

export interface OfflineSyncRecordLogListResult {
  items: OfflineSyncRecordLogSummary[];
  total: number;
}
