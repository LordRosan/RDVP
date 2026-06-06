import {
  OfflineSyncItem,
  OfflineSyncItemStatus,
  OfflineSyncOperationType,
  OfflineSyncRuntimeState,
  OfflineSyncSettings,
  OfflineSyncSummary,
  OfflineSyncTransitionPreparation
} from '../models/OfflineSyncModels';
import { AppColors } from '../styles/AppTheme';
import { SessionStore } from '../stores/SessionStore';
import { WorkbenchRefreshStore } from '../stores/WorkbenchRefreshStore';
import { DeviceArchiveFlowStore } from '../stores/DeviceArchiveFlowStore';
import { LocalDeviceArchiveRepository } from './LocalDeviceArchiveRepository';

const OFFLINE_SYNC_QUEUE_STORAGE_KEY = 'rdvp_offline_sync_queue';
const OFFLINE_SYNC_RUNTIME_STORAGE_KEY = 'rdvp_offline_sync_runtime';
const DEFAULT_QUEUE_TEXT = '';
const DEFAULT_RUNTIME_TEXT = '';
const ONLINE_STABILITY_DELAY_MS = 1500;
const TRANSITION_DEBOUNCE_MS = 1000;
const MAX_SYNC_RETRY_COUNT = 3;
const BASE_RETRY_DELAY_MS = 2000;
const DEFAULT_AUTO_SYNC_BATCH_LIMIT = 5;
const MIN_AUTO_SYNC_BATCH_LIMIT = 1;
const MAX_AUTO_SYNC_BATCH_LIMIT = 5;

interface ArchiveOfflineSyncPayload {
  deviceCode: string;
}

export class OfflineSyncService {
  private static initialized: boolean = false;
  private static items: OfflineSyncItem[] = [];
  private static runtimeState: OfflineSyncRuntimeState = OfflineSyncService.createDefaultRuntimeState();

  static enqueue(
    operationType: string,
    payloadSummary: string,
    payloadJson: string,
    conflictKey?: string,
    serverVersion?: string
  ): OfflineSyncItem {
    OfflineSyncService.ensureInitialized();

    const now = new Date().toISOString();
    const item: OfflineSyncItem = {
      id: OfflineSyncService.createItemId(),
      operationType: operationType.trim(),
      payloadSummary: payloadSummary.trim(),
      payloadJson,
      operatorName: SessionStore.getCurrentOperatorName(),
      status: OfflineSyncItemStatus.Pending,
      createdAt: now,
      updatedAt: now,
      retryCount: 0,
      conflictKey,
      serverVersion
    };

    OfflineSyncService.items.unshift(item);
    OfflineSyncService.persistItems();
    WorkbenchRefreshStore.notifyChanged();
    return item;
  }

  static hasActiveConflict(operationType: string, conflictKey: string): boolean {
    OfflineSyncService.ensureInitialized();
    const normalizedOperationType = operationType.trim();
    const normalizedConflictKey = conflictKey.trim();
    if (normalizedOperationType.length === 0 || normalizedConflictKey.length === 0) {
      return false;
    }

    return OfflineSyncService.items.some((item: OfflineSyncItem) => {
      return item.operationType === normalizedOperationType &&
        item.conflictKey === normalizedConflictKey &&
        (item.status === OfflineSyncItemStatus.Pending || item.status === OfflineSyncItemStatus.Syncing);
    });
  }

  static hasActiveConflictKey(conflictKey: string): boolean {
    OfflineSyncService.ensureInitialized();
    const normalizedConflictKey = conflictKey.trim();
    if (normalizedConflictKey.length === 0) {
      return false;
    }

    return OfflineSyncService.items.some((item: OfflineSyncItem) => {
      return item.conflictKey === normalizedConflictKey &&
        (item.status === OfflineSyncItemStatus.Pending || item.status === OfflineSyncItemStatus.Syncing);
    });
  }

  static markSyncing(id: string): void {
    OfflineSyncService.updateItemStatus(id, OfflineSyncItemStatus.Syncing, '');
  }

  static markSynced(id: string): void {
    OfflineSyncService.updateItemStatus(id, OfflineSyncItemStatus.Synced, '');
  }

  static markFailedPermanently(id: string, error: string, errorCode?: string): void {
    OfflineSyncService.updateItemStatus(id, OfflineSyncItemStatus.Failed, error, errorCode);
  }

  static markFailed(id: string, error: string, errorCode?: string): void {
    OfflineSyncService.ensureInitialized();

    const now = new Date();
    const nextItems: OfflineSyncItem[] = [];
    OfflineSyncService.items.forEach((item: OfflineSyncItem) => {
      if (item.id !== id) {
        nextItems.push(item);
        return;
      }

      const nextRetryCount = item.retryCount + 1;
      const retryExhausted = nextRetryCount >= MAX_SYNC_RETRY_COUNT;
      if (retryExhausted) {
        OfflineSyncService.releaseProvisionalArchiveLock(item);
      }

      nextItems.push({
        id: item.id,
        operationType: item.operationType,
        payloadSummary: item.payloadSummary,
        payloadJson: item.payloadJson,
        operatorName: item.operatorName,
        status: retryExhausted ? OfflineSyncItemStatus.Failed : OfflineSyncItemStatus.Pending,
        createdAt: item.createdAt,
        updatedAt: now.toISOString(),
        retryCount: nextRetryCount,
        nextRetryAt: retryExhausted ? undefined : new Date(now.getTime() + OfflineSyncService.getRetryDelayMs(nextRetryCount)).toISOString(),
        conflictKey: item.conflictKey,
        serverVersion: item.serverVersion,
        lastErrorCode: OfflineSyncService.normalizeOptionalErrorCode(errorCode, item.lastErrorCode),
        lastError: error.trim().length === 0 ? undefined : error.trim()
      });
    });

    OfflineSyncService.items = nextItems;
    OfflineSyncService.persistItems();
    WorkbenchRefreshStore.notifyChanged();
  }

  static getItems(): OfflineSyncItem[] {
    OfflineSyncService.ensureInitialized();
    return OfflineSyncService.items.map((item: OfflineSyncItem): OfflineSyncItem => {
      return OfflineSyncService.copyItem(item);
    });
  }

  static withdrawPendingItem(id: string): boolean {
    OfflineSyncService.ensureInitialized();
    const normalizedId = id.trim();
    let removed = false;
    const nextItems: OfflineSyncItem[] = [];
    OfflineSyncService.items.forEach((item: OfflineSyncItem) => {
      if (item.id === normalizedId && item.status === OfflineSyncItemStatus.Pending) {
        removed = true;
        OfflineSyncService.releaseProvisionalArchiveLock(item);
        return;
      }

      nextItems.push(item);
    });

    if (!removed) {
      return false;
    }

    OfflineSyncService.items = nextItems;
    OfflineSyncService.persistItems();
    WorkbenchRefreshStore.notifyChanged();
    return true;
  }

  static archiveFailedItem(id: string): boolean {
    OfflineSyncService.ensureInitialized();
    const normalizedId = id.trim();
    let removed = false;
    const nextItems: OfflineSyncItem[] = [];
    OfflineSyncService.items.forEach((item: OfflineSyncItem) => {
      if (item.id === normalizedId && item.status === OfflineSyncItemStatus.Failed) {
        removed = true;
        OfflineSyncService.releaseProvisionalArchiveLock(item);
        return;
      }

      nextItems.push(item);
    });

    if (!removed) {
      return false;
    }

    OfflineSyncService.items = nextItems;
    OfflineSyncService.persistItems();
    WorkbenchRefreshStore.notifyChanged();
    return true;
  }

  static getPendingCount(): number {
    return OfflineSyncService.getSummary().pendingCount;
  }

  static getSettings(): OfflineSyncSettings {
    OfflineSyncService.ensureInitialized();
    return {
      autoSyncEnabled: OfflineSyncService.runtimeState.autoSyncEnabled,
      autoSyncBatchLimit: OfflineSyncService.runtimeState.autoSyncBatchLimit
    };
  }

  static setAutoSyncSettings(enabled: boolean, batchLimit: number): OfflineSyncSettings {
    OfflineSyncService.ensureInitialized();
    OfflineSyncService.runtimeState = {
      networkPaused: OfflineSyncService.runtimeState.networkPaused,
      logThrottleEnabled: OfflineSyncService.runtimeState.logThrottleEnabled,
      autoSyncEnabled: enabled,
      autoSyncBatchLimit: OfflineSyncService.normalizeAutoSyncBatchLimit(batchLimit),
      onlineRecoveryReadyAt: OfflineSyncService.runtimeState.onlineRecoveryReadyAt,
      lastTransitionAt: OfflineSyncService.runtimeState.lastTransitionAt,
      lastTransitionReason: OfflineSyncService.runtimeState.lastTransitionReason
    };
    OfflineSyncService.persistRuntimeState();
    WorkbenchRefreshStore.notifyChanged();
    return OfflineSyncService.getSettings();
  }

  static isAutoSyncEnabled(): boolean {
    return OfflineSyncService.getSettings().autoSyncEnabled;
  }

  static getAutoSyncBatchLimit(): number {
    return OfflineSyncService.getSettings().autoSyncBatchLimit;
  }

  static getSummary(): OfflineSyncSummary {
    OfflineSyncService.ensureInitialized();

    let pendingCount = 0;
    let syncingCount = 0;
    let failedCount = 0;
    let readyToSyncCount = 0;
    let latestUpdatedAt = '';
    const now = Date.now();

    OfflineSyncService.items.forEach((item: OfflineSyncItem) => {
      if (item.status === OfflineSyncItemStatus.Pending || item.status === OfflineSyncItemStatus.Syncing) {
        pendingCount += 1;
      }

      if (item.status === OfflineSyncItemStatus.Syncing) {
        syncingCount += 1;
      }

      if (item.status === OfflineSyncItemStatus.Pending && OfflineSyncService.isRetryReady(item, now)) {
        readyToSyncCount += 1;
      }

      if (item.status === OfflineSyncItemStatus.Failed) {
        failedCount += 1;
      }

      if (latestUpdatedAt.length === 0 || Date.parse(item.updatedAt) > Date.parse(latestUpdatedAt)) {
        latestUpdatedAt = item.updatedAt;
      }
    });

    return {
      pendingCount,
      syncingCount,
      failedCount,
      readyToSyncCount,
      autoSyncEnabled: OfflineSyncService.runtimeState.autoSyncEnabled,
      autoSyncBatchLimit: OfflineSyncService.runtimeState.autoSyncBatchLimit,
      waitingForNetworkStability: OfflineSyncService.isWaitingForNetworkStability(),
      networkPaused: OfflineSyncService.runtimeState.networkPaused,
      logThrottleEnabled: OfflineSyncService.runtimeState.logThrottleEnabled,
      recoveryReadyAt: OfflineSyncService.runtimeState.onlineRecoveryReadyAt,
      latestUpdatedAt: latestUpdatedAt.length === 0 ? undefined : latestUpdatedAt
    };
  }

  static getStatusLabel(): string {
    const summary = OfflineSyncService.getSummary();
    if (summary.waitingForNetworkStability) {
      return '等待网络稳定';
    }

    if (summary.networkPaused) {
      return '离线队列保留中';
    }

    if (summary.syncingCount > 0) {
      return `${summary.syncingCount}项同步中`;
    }

    if (summary.failedCount > 0) {
      return `${summary.failedCount}项同步失败`;
    }

    if (summary.pendingCount > 0) {
      return `${summary.pendingCount}项待同步`;
    }

    return '无待同步';
  }

  static getStatusTone(): string {
    const summary = OfflineSyncService.getSummary();
    if (summary.waitingForNetworkStability) {
      return AppColors.Primary;
    }

    if (summary.failedCount > 0) {
      return AppColors.Danger;
    }

    if (summary.pendingCount > 0) {
      return AppColors.Warning;
    }

    return AppColors.Success;
  }

  static prepareForOfflineTransition(reason: string): OfflineSyncTransitionPreparation {
    OfflineSyncService.ensureInitialized();
    if (OfflineSyncService.isTransitionDebounced()) {
      return {
        success: false,
        message: '服务模式切换过于频繁，请稍后再试',
        waitingForNetworkStability: false
      };
    }

    OfflineSyncService.items = OfflineSyncService.items.map((item: OfflineSyncItem): OfflineSyncItem => {
      if (item.status !== OfflineSyncItemStatus.Syncing) {
        return item;
      }

      return OfflineSyncService.copyItemWithStatus(item, OfflineSyncItemStatus.Pending, '网络已切换至离线，等待恢复后继续同步');
    });

    OfflineSyncService.runtimeState = {
      networkPaused: true,
      logThrottleEnabled: true,
      autoSyncEnabled: OfflineSyncService.runtimeState.autoSyncEnabled,
      autoSyncBatchLimit: OfflineSyncService.runtimeState.autoSyncBatchLimit,
      lastTransitionAt: new Date().toISOString(),
      lastTransitionReason: reason
    };
    OfflineSyncService.persistItems();
    OfflineSyncService.persistRuntimeState();
    WorkbenchRefreshStore.notifyChanged();

    return {
      success: true,
      message: '已进入离线模式，待提交内容将保留在本地队列',
      waitingForNetworkStability: false
    };
  }

  static prepareForOnlineRecovery(reason: string): OfflineSyncTransitionPreparation {
    OfflineSyncService.ensureInitialized();
    if (OfflineSyncService.isTransitionDebounced()) {
      return {
        success: false,
        message: '服务模式切换过于频繁，请稍后再试',
        waitingForNetworkStability: false
      };
    }

    const readyAt = new Date(Date.now() + ONLINE_STABILITY_DELAY_MS).toISOString();
    OfflineSyncService.runtimeState = {
      networkPaused: false,
      logThrottleEnabled: false,
      autoSyncEnabled: OfflineSyncService.runtimeState.autoSyncEnabled,
      autoSyncBatchLimit: OfflineSyncService.runtimeState.autoSyncBatchLimit,
      onlineRecoveryReadyAt: readyAt,
      lastTransitionAt: new Date().toISOString(),
      lastTransitionReason: reason
    };
    OfflineSyncService.persistRuntimeState();
    WorkbenchRefreshStore.notifyChanged();

    return {
      success: true,
      message: '已进入在线恢复准备，系统将等待网络稳定后处理同步队列',
      waitingForNetworkStability: true
    };
  }

  static getReadyPendingItems(limit: number): OfflineSyncItem[] {
    OfflineSyncService.ensureInitialized();

    const now = Date.now();
    const items: OfflineSyncItem[] = [];
    OfflineSyncService.items.forEach((item: OfflineSyncItem) => {
      if (items.length >= limit) {
        return;
      }

      if (item.status === OfflineSyncItemStatus.Pending && OfflineSyncService.isRetryReady(item, now)) {
        items.push(item);
      }
    });

    return items;
  }

  private static updateItemStatus(
    id: string,
    status: OfflineSyncItemStatus,
    error: string,
    errorCode?: string
  ): void {
    OfflineSyncService.ensureInitialized();

    const now = new Date().toISOString();
    const nextItems: OfflineSyncItem[] = [];
    OfflineSyncService.items.forEach((item: OfflineSyncItem) => {
      if (item.id !== id) {
        nextItems.push(item);
        return;
      }

      nextItems.push({
        id: item.id,
        operationType: item.operationType,
        payloadSummary: item.payloadSummary,
        payloadJson: item.payloadJson,
        operatorName: item.operatorName,
        status,
        createdAt: item.createdAt,
        updatedAt: now,
        retryCount: status === OfflineSyncItemStatus.Synced ? 0 : item.retryCount,
        nextRetryAt: undefined,
        conflictKey: item.conflictKey,
        serverVersion: item.serverVersion,
        lastErrorCode: error.length === 0 ? undefined :
          OfflineSyncService.normalizeOptionalErrorCode(errorCode, item.lastErrorCode),
        lastError: error.length === 0 ? undefined : error
      });
    });

    OfflineSyncService.items = nextItems;
    OfflineSyncService.persistItems();
    WorkbenchRefreshStore.notifyChanged();
  }

  private static ensureInitialized(): void {
    if (OfflineSyncService.initialized) {
      return;
    }

    OfflineSyncService.initialized = true;
    try {
      PersistentStorage.persistProp<string>(OFFLINE_SYNC_QUEUE_STORAGE_KEY, DEFAULT_QUEUE_TEXT);
      PersistentStorage.persistProp<string>(OFFLINE_SYNC_RUNTIME_STORAGE_KEY, DEFAULT_RUNTIME_TEXT);
      const queueText = AppStorage.get<string>(OFFLINE_SYNC_QUEUE_STORAGE_KEY);
      const runtimeText = AppStorage.get<string>(OFFLINE_SYNC_RUNTIME_STORAGE_KEY);
      OfflineSyncService.items = OfflineSyncService.parseItems(queueText);
      OfflineSyncService.runtimeState = OfflineSyncService.parseRuntimeState(runtimeText);
    } catch (err) {
      OfflineSyncService.items = [];
      OfflineSyncService.runtimeState = OfflineSyncService.createDefaultRuntimeState();
    }
  }

  private static persistItems(): void {
    try {
      AppStorage.setOrCreate<string>(OFFLINE_SYNC_QUEUE_STORAGE_KEY, JSON.stringify(OfflineSyncService.items));
    } catch (err) {
    }
  }

  private static persistRuntimeState(): void {
    try {
      AppStorage.setOrCreate<string>(OFFLINE_SYNC_RUNTIME_STORAGE_KEY, JSON.stringify(OfflineSyncService.runtimeState));
    } catch (err) {
    }
  }

  private static parseItems(queueText: string | undefined): OfflineSyncItem[] {
    if (queueText === undefined || queueText.trim().length === 0) {
      return [];
    }

    try {
      const parsedItems = JSON.parse(queueText) as OfflineSyncItem[];
      const items: OfflineSyncItem[] = [];
      parsedItems.forEach((item: OfflineSyncItem) => {
        if (OfflineSyncService.isValidItem(item)) {
          items.push(OfflineSyncService.normalizeItem(item));
        }
      });

      return items;
    } catch (err) {
      return [];
    }
  }

  private static isValidItem(item: OfflineSyncItem): boolean {
    return item.id.length > 0 &&
      item.operationType.length > 0 &&
      item.createdAt.length > 0 &&
      item.updatedAt.length > 0 &&
      OfflineSyncService.isKnownStatus(item.status);
  }

  private static normalizeItem(item: OfflineSyncItem): OfflineSyncItem {
    return {
      id: item.id,
      operationType: item.operationType,
      payloadSummary: item.payloadSummary,
      payloadJson: item.payloadJson,
      operatorName: item.operatorName,
      status: item.status,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      retryCount: item.retryCount === undefined || item.retryCount !== item.retryCount || item.retryCount < 0 ? 0 : Math.floor(item.retryCount),
      nextRetryAt: item.nextRetryAt,
      conflictKey: item.conflictKey,
      serverVersion: item.serverVersion,
      lastErrorCode: item.lastErrorCode,
      lastError: item.lastError
    };
  }

  private static parseRuntimeState(runtimeText: string | undefined): OfflineSyncRuntimeState {
    if (runtimeText === undefined || runtimeText.trim().length === 0) {
      return OfflineSyncService.createDefaultRuntimeState();
    }

    try {
      const runtimeState = JSON.parse(runtimeText) as OfflineSyncRuntimeState;
      return {
        networkPaused: runtimeState.networkPaused === true,
        logThrottleEnabled: runtimeState.logThrottleEnabled === true,
        autoSyncEnabled: runtimeState.autoSyncEnabled === true,
        autoSyncBatchLimit: OfflineSyncService.normalizeAutoSyncBatchLimit(runtimeState.autoSyncBatchLimit),
        onlineRecoveryReadyAt: runtimeState.onlineRecoveryReadyAt,
        lastTransitionAt: runtimeState.lastTransitionAt,
        lastTransitionReason: runtimeState.lastTransitionReason
      };
    } catch (err) {
      return OfflineSyncService.createDefaultRuntimeState();
    }
  }

  private static createDefaultRuntimeState(): OfflineSyncRuntimeState {
    return {
      networkPaused: false,
      logThrottleEnabled: false,
      autoSyncEnabled: false,
      autoSyncBatchLimit: DEFAULT_AUTO_SYNC_BATCH_LIMIT
    };
  }

  private static isKnownStatus(status: OfflineSyncItemStatus): boolean {
    return status === OfflineSyncItemStatus.Pending ||
      status === OfflineSyncItemStatus.Syncing ||
      status === OfflineSyncItemStatus.Synced ||
      status === OfflineSyncItemStatus.Failed;
  }

  private static isTransitionDebounced(): boolean {
    const lastTransitionAt = OfflineSyncService.runtimeState.lastTransitionAt;
    if (lastTransitionAt === undefined || lastTransitionAt.length === 0) {
      return false;
    }

    const timestamp = Date.parse(lastTransitionAt);
    return timestamp === timestamp && Date.now() - timestamp < TRANSITION_DEBOUNCE_MS;
  }

  private static isWaitingForNetworkStability(): boolean {
    const readyAt = OfflineSyncService.runtimeState.onlineRecoveryReadyAt;
    if (readyAt === undefined || readyAt.length === 0) {
      return false;
    }

    const timestamp = Date.parse(readyAt);
    return timestamp === timestamp && timestamp > Date.now();
  }

  private static isRetryReady(item: OfflineSyncItem, now: number): boolean {
    if (OfflineSyncService.runtimeState.networkPaused) {
      return false;
    }

    if (OfflineSyncService.isWaitingForNetworkStability()) {
      return false;
    }

    if (item.nextRetryAt === undefined || item.nextRetryAt.length === 0) {
      return true;
    }

    const timestamp = Date.parse(item.nextRetryAt);
    return timestamp !== timestamp || timestamp <= now;
  }

  private static getRetryDelayMs(retryCount: number): number {
    const normalizedRetryCount = Math.max(1, retryCount);
    return BASE_RETRY_DELAY_MS * Math.pow(2, normalizedRetryCount - 1);
  }

  private static normalizeAutoSyncBatchLimit(value: number | undefined): number {
    if (value === undefined || value !== value || value < MIN_AUTO_SYNC_BATCH_LIMIT) {
      return DEFAULT_AUTO_SYNC_BATCH_LIMIT;
    }

    return Math.min(MAX_AUTO_SYNC_BATCH_LIMIT, Math.floor(value));
  }

  private static copyItem(item: OfflineSyncItem): OfflineSyncItem {
    return {
      id: item.id,
      operationType: item.operationType,
      payloadSummary: item.payloadSummary,
      payloadJson: item.payloadJson,
      operatorName: item.operatorName,
      status: item.status,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      retryCount: item.retryCount,
      nextRetryAt: item.nextRetryAt,
      conflictKey: item.conflictKey,
      serverVersion: item.serverVersion,
      lastErrorCode: item.lastErrorCode,
      lastError: item.lastError
    };
  }

  private static copyItemWithStatus(item: OfflineSyncItem, status: OfflineSyncItemStatus, error: string): OfflineSyncItem {
    return {
      id: item.id,
      operationType: item.operationType,
      payloadSummary: item.payloadSummary,
      payloadJson: item.payloadJson,
      operatorName: item.operatorName,
      status,
      createdAt: item.createdAt,
      updatedAt: new Date().toISOString(),
      retryCount: item.retryCount,
      nextRetryAt: item.nextRetryAt,
      conflictKey: item.conflictKey,
      serverVersion: item.serverVersion,
      lastErrorCode: item.lastErrorCode,
      lastError: error.length === 0 ? item.lastError : error
    };
  }

  private static normalizeOptionalErrorCode(value: string | undefined, fallback: string | undefined): string | undefined {
    const normalized = value === undefined ? '' : value.trim();
    if (normalized.length > 0) {
      return normalized;
    }

    return fallback;
  }

  private static createItemId(): string {
    return `offline-sync-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;
  }

  private static releaseProvisionalArchiveLock(item: OfflineSyncItem): void {
    if (item.operationType !== OfflineSyncOperationType.DeviceArchiveUpdateRequestCreate &&
      item.operationType !== OfflineSyncOperationType.DeviceArchiveDeleteRequestCreate) {
      return;
    }

    const deviceCode = OfflineSyncService.readArchivePayloadDeviceCode(item.payloadJson);
    if (deviceCode.length === 0) {
      return;
    }

    LocalDeviceArchiveRepository.releaseChangeLock(deviceCode);
    DeviceArchiveFlowStore.releaseCurrentDeviceChangeLockByCode(deviceCode);
  }

  private static readArchivePayloadDeviceCode(payloadJson: string): string {
    try {
      const payload = JSON.parse(payloadJson) as ArchiveOfflineSyncPayload;
      return payload.deviceCode === undefined ? '' : payload.deviceCode.trim();
    } catch (err) {
      return '';
    }
  }
}
