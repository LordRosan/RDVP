import { AppColors } from '../../styles/AppTheme';
import { ApiResponse } from '../../models/common/ApiModels';
import {
  RecordCategory,
  RecordItem,
  RecordListResult,
  RecordQueryFilter
} from '../../models/management/RecordQueryModels';
import { ApiClient } from '../common/ApiClient';

const DEFAULT_RECORD_PAGE_SIZE = 50;

interface ApiManagementRecordItem {
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
  items: ApiManagementRecordItem[];
  total: number;
}

export class RecordQueryService {
  static async queryRecords(
    filter: RecordQueryFilter
  ): Promise<ApiResponse<RecordListResult>> {
    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<RecordListResult>();
    }

    const response = await ApiClient.request<ApiListResult>(
      RecordQueryService.buildRecordQueryPath(filter),
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
      response.data.items.map((item: ApiManagementRecordItem): RecordItem => {
        return RecordQueryService.mapApiItem(item, filter.category);
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

  static buildRecordQueryPath(filter: RecordQueryFilter): string {
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

    const trimmedStartDate = filter.startDate === undefined ? '' : filter.startDate.trim();
    if (trimmedStartDate.length > 0) {
      params.push(`startDate=${encodeURIComponent(trimmedStartDate)}`);
    }

    const trimmedEndDate = filter.endDate === undefined ? '' : filter.endDate.trim();
    if (trimmedEndDate.length > 0) {
      params.push(`endDate=${encodeURIComponent(trimmedEndDate)}`);
    }

    return `/api/v1/management-records?${params.join('&')}`;
  }

  static formatStatus(status: string): string {
    switch (status) {
      case 'SUCCESS':
        return '成功';
      case 'FAILED':
        return '失败';
      case 'NORMAL':
        return '正常';
      case 'ABNORMAL':
        return '异常';
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
      case 'PROCESSING':
        return '维修中';
      case 'REPORT_SUBMITTED':
        return '报告已提交';
      case 'PENDING_REINSPECTION':
        return '待复检';
      case 'CLOSED':
        return '已完成';
      case 'UNDER_REPAIR':
        return '维修中';
      case 'REPAIRED':
        return '已修复';
      case 'TEMPORARY_RESTORED':
        return '临时修复';
      case 'UNRESOLVED':
        return '未修复';
      case 'PASSED':
        return '通过';
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

  static formatTypeLabel(action: string, category?: RecordCategory): string {
    switch (action) {
      case 'DEVICE_ARCHIVE_REQUEST':
        return '档案申请';
      case 'DEVICE_ARCHIVE_REVIEW':
        return '档案审核';
      case 'DEVICE_ARCHIVE_QUERY':
        return '档案查询';
      case 'DEVICE_ARCHIVE_EXPORT':
        return '档案导出';
      case 'CREATE':
        return category === RecordCategory.Archive ? '档案添加' : '添加档案';
      case 'UPDATE':
        return category === RecordCategory.Archive ? '档案修改' : '修改档案';
      case 'DELETE':
        return category === RecordCategory.Archive ? '档案删除' : '删除档案';
      case 'DEVICE_VERIFICATION':
      case 'DEVICE_VERIFICATION_REPORT':
        return '核验报告';
      case 'FAULT_REPORT':
        return '报修报告';
      case 'REPAIR_TASK_ACCEPT':
        return '任务接取';
      case 'REPAIR_REPORT':
        return '维修报告';
      case 'REINSPECTION_REPORT':
        return '复检报告';
      case 'REINSPECTION_RECORD':
        return '复检报告';
      default:
        return action;
    }
  }

  private static mapApiItem(item: ApiManagementRecordItem, category: RecordCategory): RecordItem {
    return {
      id: `${item.recordCategory}-${item.recordType}-${item.taskNo}-${item.occurredAt}`,
      category,
      type: item.recordType,
      typeLabel: RecordQueryService.formatTypeLabel(item.recordType, category),
      deviceCode: item.deviceCode ?? '-',
      taskNo: item.taskNo ?? '-',
      operatorName: item.operatorName ?? '-',
      occurredAt: RecordQueryService.formatTimestampForDisplay(item.occurredAt),
      status: item.businessStatus,
      statusLabel: RecordQueryService.formatStatus(item.businessStatus),
      description: item.description
    };
  }

  private static formatTimestampForDisplay(value: string): string {
    const normalized = value.trim();
    if (normalized.length === 0) {
      return '-';
    }

    const date = new Date(normalized);
    if (Number.isNaN(date.getTime())) {
      return normalized.replace('T', ' ').replace('Z', '').split('.')[0];
    }

    return `${date.getFullYear()}-${RecordQueryService.pad2(date.getMonth() + 1)}-${RecordQueryService.pad2(date.getDate())} ` +
      `${RecordQueryService.pad2(date.getHours())}:${RecordQueryService.pad2(date.getMinutes())}:${RecordQueryService.pad2(date.getSeconds())}`;
  }

  private static pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
