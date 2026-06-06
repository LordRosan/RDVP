import { ApiErrorCode, ApiResponse } from '../models/ApiModels';
import { DeviceArchiveChangeRequestStatus } from '../models/DeviceArchiveChangeModels';
import {
  OfflineSyncBatchRequest,
  OfflineSyncBatchResult,
  OfflineSyncExecutionResult,
  OfflineSyncItem,
  OfflineSyncOperationType,
  OfflineSyncRecordRequest,
  OfflineSyncRecordResult
} from '../models/OfflineSyncModels';
import { ApiClient } from './ApiClient';
import { LocalDeviceArchiveRepository } from './LocalDeviceArchiveRepository';
import { OfflineSyncService } from './OfflineSyncService';
import { DeviceArchiveFlowStore } from '../stores/DeviceArchiveFlowStore';

const DEFAULT_SYNC_BATCH_LIMIT = 5;

interface ArchiveOfflineSyncPayload {
  deviceCode: string;
}

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
      const validItems: OfflineSyncItem[] = [];
      const records: OfflineSyncRecordRequest[] = [];
      items.forEach((item: OfflineSyncItem) => {
        const record = OfflineSyncProcessorService.toRecordRequest(item);
        if (record === undefined) {
          OfflineSyncProcessorService.releaseLocalArchiveLockIfNeeded(item);
          OfflineSyncService.markFailedPermanently(item.id, '离线同步内容无法解析');
          failedCount += 1;
          return;
        }

        OfflineSyncService.markSyncing(item.id);
        validItems.push(item);
        records.push(record);
      });

      if (records.length === 0) {
        return {
          processedCount: items.length,
          syncedCount,
          failedCount,
          skippedCount,
          message: OfflineSyncProcessorService.createResultMessage(items.length, syncedCount, failedCount, skippedCount)
        };
      }

      const response = await OfflineSyncProcessorService.submitBatch(records);
      if (!response.success || response.data === undefined) {
        const message = response.error === undefined ? '同步失败' : response.error.message;
        validItems.forEach((item: OfflineSyncItem) => {
          if (OfflineSyncProcessorService.shouldRetry(response)) {
            OfflineSyncService.markFailed(item.id, message);
          } else {
            OfflineSyncProcessorService.releaseLocalArchiveLockIfNeeded(item);
            OfflineSyncService.markFailedPermanently(item.id, message);
          }
          failedCount += 1;
        });
      } else {
        const resultMap = OfflineSyncProcessorService.indexResults(response.data.results);
        validItems.forEach((item: OfflineSyncItem) => {
          const result = resultMap.get(item.id);
          if (result === undefined) {
            OfflineSyncService.markFailed(item.id, '后端未返回该离线记录的同步结果');
            failedCount += 1;
            return;
          }

          if (result.success) {
            OfflineSyncProcessorService.applySuccessfulLocalArchiveSync(item, result);
            OfflineSyncService.markSynced(item.id);
            syncedCount += 1;
            return;
          }

          const errorMessage = OfflineSyncProcessorService.formatRecordError(result);
          if (OfflineSyncProcessorService.shouldRetryRecord(result)) {
            OfflineSyncService.markFailed(item.id, errorMessage);
          } else {
            OfflineSyncProcessorService.releaseLocalArchiveLockIfNeeded(item);
            OfflineSyncService.markFailedPermanently(item.id, errorMessage);
          }
          failedCount += 1;
        });
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

  private static async submitBatch(records: OfflineSyncRecordRequest[]): Promise<ApiResponse<OfflineSyncBatchResult>> {
    const request: OfflineSyncBatchRequest = {
      clientBatchId: OfflineSyncProcessorService.createClientBatchId(),
      records
    };
    return ApiClient.request<OfflineSyncBatchResult>(
      '/api/v1/sync/offline-records',
      'POST',
      true,
      JSON.stringify(request),
      true
    );
  }

  private static toRecordRequest(item: OfflineSyncItem): OfflineSyncRecordRequest | undefined {
    try {
      const payload = JSON.parse(item.payloadJson) as object;
      return {
        clientRecordId: item.id,
        recordType: item.operationType,
        payload,
        createdOfflineAt: item.createdAt
      };
    } catch (err) {
      return undefined;
    }
  }

  private static indexResults(results: OfflineSyncRecordResult[]): Map<string, OfflineSyncRecordResult> {
    const resultMap = new Map<string, OfflineSyncRecordResult>();
    results.forEach((result: OfflineSyncRecordResult) => {
      resultMap.set(result.clientRecordId, result);
    });
    return resultMap;
  }

  private static formatRecordError(result: OfflineSyncRecordResult): string {
    const message = result.errorMessage === undefined || result.errorMessage.trim().length === 0 ?
      '同步失败' :
      result.errorMessage.trim();
    if (result.errorCode === undefined || result.errorCode.trim().length === 0) {
      return message;
    }

    return `${result.errorCode.trim()}：${message}`;
  }

  private static shouldRetryRecord(result: OfflineSyncRecordResult): boolean {
    const errorCode = result.errorCode === undefined ? '' : result.errorCode.trim();
    return errorCode === ApiErrorCode.InternalError ||
      errorCode === ApiErrorCode.ServiceUnavailable ||
      errorCode === ApiErrorCode.RateLimited;
  }

  private static shouldRetry(response: ApiResponse<OfflineSyncBatchResult>): boolean {
    if (response.error === undefined) {
      return false;
    }

    const code = `${response.error.code}`;
    return code === ApiErrorCode.ServiceUnavailable || code === ApiErrorCode.RateLimited;
  }

  private static applySuccessfulLocalArchiveSync(item: OfflineSyncItem, result: OfflineSyncRecordResult): void {
    if (item.operationType !== OfflineSyncOperationType.DeviceArchiveUpdateRequestCreate &&
      item.operationType !== OfflineSyncOperationType.DeviceArchiveDeleteRequestCreate) {
      return;
    }

    const deviceCode = OfflineSyncProcessorService.readArchivePayloadDeviceCode(item.payloadJson);
    if (deviceCode.length === 0) {
      return;
    }

    const requestId = result.serverRecordId === undefined || result.serverRecordId.trim().length === 0 ?
      item.id : result.serverRecordId.trim();
    LocalDeviceArchiveRepository.markChangePending(deviceCode, requestId);
    DeviceArchiveFlowStore.markCurrentDeviceChangePendingByCode(
      deviceCode,
      requestId,
      DeviceArchiveChangeRequestStatus.PendingReview
    );
  }

  private static releaseLocalArchiveLockIfNeeded(item: OfflineSyncItem): void {
    if (item.operationType !== OfflineSyncOperationType.DeviceArchiveUpdateRequestCreate &&
      item.operationType !== OfflineSyncOperationType.DeviceArchiveDeleteRequestCreate) {
      return;
    }

    const deviceCode = OfflineSyncProcessorService.readArchivePayloadDeviceCode(item.payloadJson);
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

  private static normalizeLimit(limit: number): number {
    if (limit !== limit || limit < 1) {
      return DEFAULT_SYNC_BATCH_LIMIT;
    }

    return Math.min(20, Math.floor(limit));
  }

  private static createClientBatchId(): string {
    return `offline-batch-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;
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
      return `已同步提交${syncedCount}项`;
    }

    return `已处理${processedCount}项，已同步提交${syncedCount}项，失败${failedCount}项`;
  }
}
