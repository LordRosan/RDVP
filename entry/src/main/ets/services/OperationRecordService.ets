import { ApiResponse } from '../models/ApiModels';
import {
  OperationRecordListResult,
  OperationRecordStatus,
  OperationRecordType
} from '../models/OperationRecordModels';
import { ApiClient } from './ApiClient';
import { LocalOperationRecordRepository } from './LocalOperationRecordRepository';

export class OperationRecordService {
  static queryRecentRecords(): ApiResponse<OperationRecordListResult> {
    if (!ApiClient.isConfigured()) {
      return {
        success: true,
        data: LocalOperationRecordRepository.queryRecentRecords(),
        requestId: 'local-operation-records',
        timestamp: new Date().toISOString()
      };
    }

    return ApiClient.createServiceUnavailableResponse<OperationRecordListResult>();
  }

  static formatRecordType(type: OperationRecordType): string {
    switch (type) {
      case OperationRecordType.AuthLogin:
        return '登录';
      case OperationRecordType.DeviceVerification:
        return '状态核验';
      case OperationRecordType.DeviceChangeRequest:
        return '档案变更';
      case OperationRecordType.FaultReport:
        return '故障报告';
      case OperationRecordType.RepairTaskAccept:
        return '维修接取';
      case OperationRecordType.RepairReport:
        return '维修报告';
      case OperationRecordType.ReinspectionRecord:
        return '复检记录';
      default:
        return '-';
    }
  }

  static formatRecordStatus(status: OperationRecordStatus): string {
    switch (status) {
      case OperationRecordStatus.Success:
        return '成功';
      case OperationRecordStatus.Failed:
        return '失败';
      default:
        return '-';
    }
  }

  static getRecordStatusTone(status: OperationRecordStatus): string {
    switch (status) {
      case OperationRecordStatus.Success:
        return '#087F5B';
      case OperationRecordStatus.Failed:
        return '#D9480F';
      default:
        return '#374151';
    }
  }
}
