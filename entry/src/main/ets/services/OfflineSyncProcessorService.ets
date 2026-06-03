import { ApiErrorCode, ApiResponse } from '../models/ApiModels';
import {
  OfflineSyncExecutionResult,
  OfflineSyncItem,
  OfflineSyncOperationType
} from '../models/OfflineSyncModels';
import { ApiClient } from './ApiClient';
import { DeviceVerificationService } from './DeviceVerificationService';
import { FaultReportService } from './FaultReportService';
import { OfflineSyncService } from './OfflineSyncService';

const DEFAULT_SYNC_BATCH_LIMIT = 5;

export class OfflineSyncProcessorService {
  private static syncInProgress: boolean = false;

  static async syncReadyItems(limit: number = DEFAULT_SYNC_BATCH_LIMIT): Promise<OfflineSyncExecutionResult> {
    if (OfflineSyncProcessorService.syncInProgress) {
      return {
        processedCount: 0,
        syncedCount: 0,
        failedCount: 0,
        skippedCount: 0,
        message: '同步任务正在执行'
      };
    }

    if (!ApiClient.isConfigured()) {
      return {
        processedCount: 0,
        syncedCount: 0,
        failedCount: 0,
        skippedCount: 0,
        message: '当前未连接后端服务'
      };
    }

    const items = OfflineSyncService.getReadyPendingItems(OfflineSyncProcessorService.normalizeLimit(limit));
    if (items.length === 0) {
      return {
        processedCount: 0,
        syncedCount: 0,
        failedCount: 0,
        skippedCount: 0,
        message: '暂无可同步项目'
      };
    }

    OfflineSyncProcessorService.syncInProgress = true;
    let syncedCount = 0;
    let failedCount = 0;
    let skippedCount = 0;

    try {
      for (let index = 0; index < items.length; index += 1) {
        const item = items[index];
        OfflineSyncService.markSyncing(item.id);

        const response = await OfflineSyncProcessorService.executeItem(item);
        if (response.success) {
          OfflineSyncService.markSynced(item.id);
          syncedCount += 1;
          continue;
        }

        const message = response.error === undefined ? '同步失败' : response.error.message;
        if (OfflineSyncProcessorService.shouldRetry(response)) {
          OfflineSyncService.markFailed(item.id, message);
        } else {
          OfflineSyncService.markFailedPermanently(item.id, message);
        }
        failedCount += 1;
      }
    } finally {
      OfflineSyncProcessorService.syncInProgress = false;
    }

    return {
      processedCount: items.length,
      syncedCount,
      failedCount,
      skippedCount,
      message: OfflineSyncProcessorService.createResultMessage(items.length, syncedCount, failedCount, skippedCount)
    };
  }

  private static async executeItem(item: OfflineSyncItem): Promise<ApiResponse<string>> {
    if (item.operationType === OfflineSyncOperationType.FaultReportCreate) {
      const response = await FaultReportService.submitQueuedFaultReport(item.payloadJson);
      if (response.success) {
        return {
          success: true,
          data: item.id,
          requestId: response.requestId,
          timestamp: response.timestamp
        };
      }

      return {
        success: false,
        error: response.error,
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    if (item.operationType === OfflineSyncOperationType.DeviceVerificationCreate) {
      const response = await DeviceVerificationService.submitQueuedVerification(item.payloadJson);
      if (response.success) {
        return {
          success: true,
          data: item.id,
          requestId: response.requestId,
          timestamp: response.timestamp
        };
      }

      return {
        success: false,
        error: response.error,
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: false,
      error: {
        code: 'OFFLINE_SYNC_OPERATION_UNSUPPORTED',
        message: '暂不支持的离线同步操作类型'
      },
      timestamp: new Date().toISOString()
    };
  }

  private static shouldRetry(response: ApiResponse<string>): boolean {
    if (response.error === undefined) {
      return false;
    }

    const code = `${response.error.code}`;
    return code === ApiErrorCode.ServiceUnavailable || code === ApiErrorCode.RateLimited;
  }

  private static normalizeLimit(limit: number): number {
    if (limit !== limit || limit < 1) {
      return DEFAULT_SYNC_BATCH_LIMIT;
    }

    return Math.min(20, Math.floor(limit));
  }

  private static createResultMessage(
    processedCount: number,
    syncedCount: number,
    failedCount: number,
    skippedCount: number
  ): string {
    if (processedCount === 0) {
      return '暂无可同步项目';
    }

    if (failedCount === 0 && skippedCount === 0) {
      return `已同步${syncedCount}项`;
    }

    return `已处理${processedCount}项，同步成功${syncedCount}项，失败${failedCount}项`;
  }
}
