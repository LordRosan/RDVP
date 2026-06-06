import { AppColors } from '../styles/AppTheme';
import { ApiResponse } from '../models/ApiModels';
import {
  OfflineSyncRecordLogListResult,
  OfflineSyncRecordLogStatus,
  OfflineSyncRecordLogSummary
} from '../models/OfflineSyncRecordLogModels';
import { ApiClient } from './ApiClient';
import { DeviceService } from './DeviceService';

const DEFAULT_SYNC_RECORD_LOG_PAGE_SIZE = 50;

interface ApiListResult<T> {
  items: T[];
  total: number;
}

export class OfflineSyncRecordLogService {
  static async queryRecentRecordsRemoteFirst(): Promise<ApiResponse<OfflineSyncRecordLogListResult>> {
    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<OfflineSyncRecordLogListResult>();
    }

    const response = await ApiClient.request<ApiListResult<OfflineSyncRecordLogSummary>>(
      `/api/v1/sync/offline-records/processing-records?page=1&pageSize=${DEFAULT_SYNC_RECORD_LOG_PAGE_SIZE}`,
      'GET',
      true
    );

    if (!response.success) {
      return {
        success: false,
        error: response.error,
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: {
        items: response.data === undefined ? [] : response.data.items,
        total: response.data === undefined ? 0 : response.data.total
      },
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static formatRecordType(recordType: string): string {
    switch (recordType) {
      case 'FAULT_REPORT_CREATE':
        return '故障报告同步';
      case 'DEVICE_VERIFICATION_CREATE':
        return '设备核验同步';
      case 'DEVICE_VERIFICATION_FAULT_REPORT_CREATE':
        return '设备核验与报修同步';
      case 'DEVICE_ARCHIVE_UPDATE_REQUEST_CREATE':
        return '档案变更申请同步';
      case 'DEVICE_ARCHIVE_CREATE_REQUEST_CREATE':
        return '档案新增申请同步';
      case 'DEVICE_ARCHIVE_DELETE_REQUEST_CREATE':
        return '档案删除申请同步';
      default:
        return '离线内容同步';
    }
  }

  static formatStatus(status: string): string {
    switch (status) {
      case OfflineSyncRecordLogStatus.Succeeded:
        return '已同步';
      case OfflineSyncRecordLogStatus.Failed:
        return '同步失败';
      default:
        return '-';
    }
  }

  static getStatusTone(status: string): string {
    switch (status) {
      case OfflineSyncRecordLogStatus.Succeeded:
        return AppColors.Success;
      case OfflineSyncRecordLogStatus.Failed:
        return AppColors.Danger;
      default:
        return AppColors.TextSecondary;
    }
  }

  static formatTime(value: string): string {
    return DeviceService.formatTimestampForDisplay(value);
  }
}
