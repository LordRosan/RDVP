import { OfflineSyncItem, OfflineSyncItemStatus, OfflineSyncSummary } from '../models/OfflineSyncModels';
import { AppColors } from '../styles/AppTheme';
import { SessionStore } from '../stores/SessionStore';
import { WorkbenchRefreshStore } from '../stores/WorkbenchRefreshStore';

const OFFLINE_SYNC_QUEUE_STORAGE_KEY = 'rdvp_offline_sync_queue';
const DEFAULT_QUEUE_TEXT = '';

export class OfflineSyncService {
  private static initialized: boolean = false;
  private static items: OfflineSyncItem[] = [];

  static enqueue(operationType: string, payloadSummary: string, payloadJson: string): OfflineSyncItem {
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
      updatedAt: now
    };

    OfflineSyncService.items.unshift(item);
    OfflineSyncService.persistItems();
    WorkbenchRefreshStore.notifyChanged();
    return item;
  }

  static markSynced(id: string): void {
    OfflineSyncService.updateItemStatus(id, OfflineSyncItemStatus.Synced, '');
  }

  static markFailed(id: string, error: string): void {
    OfflineSyncService.updateItemStatus(id, OfflineSyncItemStatus.Failed, error.trim());
  }

  static getPendingCount(): number {
    return OfflineSyncService.getSummary().pendingCount;
  }

  static getSummary(): OfflineSyncSummary {
    OfflineSyncService.ensureInitialized();

    let pendingCount = 0;
    let failedCount = 0;
    let latestUpdatedAt = '';

    OfflineSyncService.items.forEach((item: OfflineSyncItem) => {
      if (item.status === OfflineSyncItemStatus.Pending || item.status === OfflineSyncItemStatus.Syncing) {
        pendingCount += 1;
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
      failedCount,
      latestUpdatedAt: latestUpdatedAt.length === 0 ? undefined : latestUpdatedAt
    };
  }

  static getStatusLabel(): string {
    const summary = OfflineSyncService.getSummary();
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
    if (summary.failedCount > 0) {
      return AppColors.Danger;
    }

    if (summary.pendingCount > 0) {
      return AppColors.Warning;
    }

    return AppColors.Success;
  }

  private static updateItemStatus(id: string, status: OfflineSyncItemStatus, error: string): void {
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
      const queueText = AppStorage.get<string>(OFFLINE_SYNC_QUEUE_STORAGE_KEY);
      OfflineSyncService.items = OfflineSyncService.parseItems(queueText);
    } catch (err) {
      OfflineSyncService.items = [];
    }
  }

  private static persistItems(): void {
    try {
      AppStorage.setOrCreate<string>(OFFLINE_SYNC_QUEUE_STORAGE_KEY, JSON.stringify(OfflineSyncService.items));
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
          items.push(item);
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

  private static isKnownStatus(status: OfflineSyncItemStatus): boolean {
    return status === OfflineSyncItemStatus.Pending ||
      status === OfflineSyncItemStatus.Syncing ||
      status === OfflineSyncItemStatus.Synced ||
      status === OfflineSyncItemStatus.Failed;
  }

  private static createItemId(): string {
    return `offline-sync-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;
  }
}

