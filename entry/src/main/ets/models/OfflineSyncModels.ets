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
  waitingForNetworkStability: boolean;
  networkPaused: boolean;
  logThrottleEnabled: boolean;
  recoveryReadyAt?: string;
  latestUpdatedAt?: string;
}

export interface OfflineSyncRuntimeState {
  networkPaused: boolean;
  logThrottleEnabled: boolean;
  onlineRecoveryReadyAt?: string;
  lastTransitionAt?: string;
  lastTransitionReason?: string;
}

export interface OfflineSyncTransitionPreparation {
  success: boolean;
  message: string;
  waitingForNetworkStability: boolean;
}
