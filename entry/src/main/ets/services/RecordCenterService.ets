import { AppColors } from '../styles/AppTheme';
import { ApiResponse } from '../models/ApiModels';
import {
  RecordCategory,
  RecordItem,
  RecordListResult,
  RecordQueryFilter
} from '../models/RecordCenterModels';
import { ApiClient } from './ApiClient';

const DEFAULT_RECORD_PAGE_SIZE = 50;

interface ApiOperationRecordItem {
  recordCategory: string;
  recordType: string;
  deviceCode?: string;
  taskNo?: string;
  operatorName?: string;
  occurredAt: string;
  businessStatus: string;
  description?: string;
}

interface ApiListResult {
  items: ApiOperationRecordItem[];
  total: number;
}

export class RecordCenterService {
  static async queryRecords(
    filter: RecordQueryFilter
  ): Promise<ApiResponse<RecordListResult>> {
    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<RecordListResult>();
    }

    const params: string[] = [];
    params.push(`category=${encodeURIComponent(filter.category)}`);
    params.push(`page=${filter.page}`);
    params.push(`pageSize=${filter.pageSize}`);

    const trimmedKeyword = filter.keyword.trim();
    if (trimmedKeyword.length > 0) {
      params.push(`keyword=${encodeURIComponent(trimmedKeyword)}`);
    }

    const trimmedType = filter.type.trim();
    if (trimmedType.length > 0) {
      params.push(`type=${encodeURIComponent(trimmedType)}`);
    }

    const query = params.join('&');
    const response = await ApiClient.request<ApiListResult>(
      `/api/v1/operation-records?${query}`,
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

    const items = response.data === undefined ? [] :
      response.data.items.map((item: ApiOperationRecordItem): RecordItem => {
        return RecordCenterService.mapApiItem(item, filter.category);
      });

    return {
      success: true,
      data: {
        items,
        total: response.data === undefined ? items.length : response.data.total
      },
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static formatStatus(status: string): string {
    switch (status) {
      case 'SUCCESS':
        return '成功';
      case 'FAILED':
        return '失败';
      case 'APPROVED':
        return '已通过';
      case 'REJECTED':
        return '已驳回';
      case 'PENDING_REVIEW':
        return '待审核';
      case 'PENDING_ACCEPTANCE':
        return '待接取';
      case 'ACCEPTED':
        return '已接取';
      case 'PENDING_REINSPECTION':
        return '待复检';
      case 'CLOSED':
        return '已完成';
      case 'UNDER_REPAIR':
        return '维修中';
      default:
        return status;
    }
  }

  static getStatusTone(status: string): string {
    switch (status) {
      case 'SUCCESS':
      case 'APPROVED':
      case 'CLOSED':
        return AppColors.Success;
      case 'FAILED':
      case 'REJECTED':
        return AppColors.Danger;
      case 'PENDING_REVIEW':
      case 'PENDING_ACCEPTANCE':
      case 'PENDING_REINSPECTION':
        return AppColors.Warning;
      default:
        return AppColors.TextSecondary;
    }
  }

  static formatTypeLabel(action: string): string {
    switch (action) {
      case 'DEVICE_CHANGE_REQUEST':
        return '档案变更';
      case 'DEVICE_CHANGE_REVIEW':
        return '档案审核';
      case 'CREATE':
        return '添加档案';
      case 'UPDATE':
        return '修改档案';
      case 'DELETE':
        return '删除档案';
      case 'DEVICE_VERIFICATION':
        return '设备核验';
      case 'FAULT_REPORT':
        return '设备报修';
      case 'REPAIR_TASK_ACCEPT':
        return '维修接取';
      case 'REPAIR_REPORT':
        return '维修报告';
      case 'REINSPECTION_RECORD':
        return '复检记录';
      default:
        return action;
    }
  }

  private static mapApiItem(item: ApiOperationRecordItem, category: RecordCategory): RecordItem {
    return {
      id: `${item.recordCategory}-${item.recordType}-${item.taskNo}-${item.occurredAt}`,
      category,
      type: item.recordType,
      typeLabel: RecordCenterService.formatTypeLabel(item.recordType),
      deviceCode: item.deviceCode ?? '-',
      taskNo: item.taskNo ?? '-',
      operatorName: item.operatorName ?? '-',
      occurredAt: item.occurredAt,
      status: item.businessStatus,
      statusLabel: RecordCenterService.formatStatus(item.businessStatus),
      description: item.description
    };
  }
}
