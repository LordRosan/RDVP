export enum OfflineSyncAuditRecordStatus {
  Succeeded = 'SUCCEEDED',
  Failed = 'FAILED'
}

export interface OfflineSyncAuditRecordSummary {
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

export interface OfflineSyncAuditListResult {
  items: OfflineSyncAuditRecordSummary[];
  total: number;
}
