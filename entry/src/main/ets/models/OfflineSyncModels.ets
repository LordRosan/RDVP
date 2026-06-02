export enum OfflineSyncItemStatus {
  Pending = 'PENDING',
  Syncing = 'SYNCING',
  Synced = 'SYNCED',
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
  lastError?: string;
}

export interface OfflineSyncSummary {
  pendingCount: number;
  failedCount: number;
  latestUpdatedAt?: string;
}

