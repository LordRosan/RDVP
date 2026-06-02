import { AppColors } from '../styles/AppTheme';
import { ApiResponse } from '../models/ApiModels';
import {
  OperationRecordListResult,
  OperationRecordSummary,
  OperationRecordStatus,
  OperationRecordType
} from '../models/OperationRecordModels';
import { ApiClient } from './ApiClient';
import { LocalOperationRecordRepository } from './LocalOperationRecordRepository';

interface OperationRecordApiSummary {
  id: string;
  action: string;
  targetId?: string;
  targetNo?: string;
  actorName?: string;
  occurredAt: string;
  status: string;
  description: string;
}

interface ApiListResult<T> {
  items: T[];
  total: number;
}

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

  static async queryRecentRecordsRemoteFirst(): Promise<ApiResponse<OperationRecordListResult>> {
    if (!ApiClient.isConfigured()) {
      return {
        success: true,
        data: LocalOperationRecordRepository.queryRecentRecords(),
        requestId: 'local-operation-records',
        timestamp: new Date().toISOString()
      };
    }

    const response = await ApiClient.request<ApiListResult<OperationRecordApiSummary>>('/api/v1/audit-logs', 'GET', true);

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
        items: response.data === undefined ? [] : response.data.items.map((item: OperationRecordApiSummary): OperationRecordSummary => {
          return OperationRecordService.mapApiRecord(item);
        }),
        total: response.data === undefined ? 0 : response.data.total
      },
      requestId: response.requestId,
      timestamp: response.timestamp
    };
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
        return AppColors.Success;
      case OperationRecordStatus.Failed:
        return AppColors.Danger;
      default:
        return AppColors.TextSecondary;
    }
  }

  private static mapApiRecord(item: OperationRecordApiSummary): OperationRecordSummary {
    const type = OperationRecordService.mapActionToType(item.action);
    return {
      id: item.id,
      type,
      title: OperationRecordService.formatActionTitle(item.action, type),
      targetNo: item.targetNo === undefined ? (item.targetId === undefined ? '-' : item.targetId) : item.targetNo,
      operatorName: item.actorName === undefined ? '-' : item.actorName,
      occurredAt: item.occurredAt,
      status: item.status as OperationRecordStatus,
      description: OperationRecordService.formatApiDescription(item.action, item.status as OperationRecordStatus)
    };
  }

  private static mapActionToType(action: string): OperationRecordType {
    switch (action) {
      case 'AUTH_LOGIN':
        return OperationRecordType.AuthLogin;
      case 'DEVICE_VERIFICATION':
        return OperationRecordType.DeviceVerification;
      case 'DEVICE_CHANGE_REQUEST':
      case 'DEVICE_CHANGE_REVIEW':
        return OperationRecordType.DeviceChangeRequest;
      case 'FAULT_REPORT':
        return OperationRecordType.FaultReport;
      case 'REPAIR_TASK_ACCEPT':
        return OperationRecordType.RepairTaskAccept;
      case 'REPAIR_REPORT':
        return OperationRecordType.RepairReport;
      case 'REINSPECTION_RECORD':
        return OperationRecordType.ReinspectionRecord;
      default:
        return OperationRecordType.DeviceVerification;
    }
  }

  private static formatActionTitle(action: string, type: OperationRecordType): string {
    if (action === 'DEVICE_CHANGE_REVIEW') {
      return '档案审核';
    }

    return OperationRecordService.formatRecordType(type);
  }

  private static formatApiDescription(action: string, status: OperationRecordStatus): string {
    switch (action) {
      case 'AUTH_LOGIN':
        return status === OperationRecordStatus.Success ? '登录成功' : '登录失败';
      case 'DEVICE_CHANGE_REQUEST':
        return '提交设备档案变更申请';
      case 'DEVICE_CHANGE_REVIEW':
        return '完成设备档案变更审核';
      case 'DEVICE_VERIFICATION':
        return '提交设备状态核验记录';
      case 'FAULT_REPORT':
        return '提交故障报告';
      case 'REPAIR_TASK_ACCEPT':
        return '接取维修任务';
      case 'REPAIR_REPORT':
        return '提交维修报告';
      case 'REINSPECTION_RECORD':
        return '提交复检记录';
      default:
        return status === OperationRecordStatus.Success ? '操作成功' : '操作失败';
    }
  }
}
