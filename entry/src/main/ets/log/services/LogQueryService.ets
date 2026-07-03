import { AppColors } from '../../shared/theme/AppTheme';
import { ApiResponse } from '../../shared/models/ApiModels';
import {
  LogCategory,
  LogItem,
  LogListResult,
  LogQueryFilter,
  LogQueryTab
} from '../models/LogQueryModels';
import { ApiClient } from '../../shared/services/ApiClient';

const DEFAULT_LOG_PAGE_SIZE = 50;
const ARCHIVE_OPERATION_TYPE_OPTIONS: string[] = ['全部', '档案添加', '档案删除', '档案修改', '档案查询', '档案导出'];
const ARCHIVE_OPERATION_TYPE_VALUES: string[] = ['', 'CREATE', 'DELETE', 'UPDATE', 'DEVICE_ARCHIVE_QUERY',
  'DEVICE_ARCHIVE_EXPORT'];
const ARCHIVE_REVIEW_TYPE_OPTIONS: string[] = ['全部', '添加档案', '删除档案', '修改档案'];
const ARCHIVE_REVIEW_TYPE_VALUES: string[] = ['', 'CREATE', 'DELETE', 'UPDATE'];
const OPERATIONS_OPERATION_TYPE_OPTIONS: string[] = ['全部', '核验报告', '报修报告', '任务接取', '维修报告', '复检报告'];
const OPERATIONS_OPERATION_TYPE_VALUES: string[] = ['', 'DEVICE_VERIFICATION', 'FAULT_REPORT',
  'REPAIR_TASK_ACCEPT', 'REPAIR_REPORT', 'REINSPECTION_REPORT'];
const OPERATIONS_REVIEW_TYPE_OPTIONS: string[] = ['全部', '核验报告', '报修报告', '维修报告', '复检报告'];
const OPERATIONS_REVIEW_TYPE_VALUES: string[] = ['', 'DEVICE_VERIFICATION_REPORT', 'FAULT_REPORT',
  'REPAIR_REPORT', 'REINSPECTION_REPORT'];

interface ApiLogItem {
  logCategory: string;
  logType: string;
  deviceCode?: string;
  taskNo?: string;
  operatorName?: string;
  occurredAt: string;
  businessStatus: string;
  description?: string;
}

interface ApiListResult {
  items: ApiLogItem[];
  total: number;
}

export class LogQueryService {
  static async queryLogs(
    filter: LogQueryFilter
  ): Promise<ApiResponse<LogListResult>> {
    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<LogListResult>();
    }

    const response = await ApiClient.request<ApiListResult>(
      LogQueryService.buildLogQueryPath(filter),
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
      response.data.items.map((item: ApiLogItem): LogItem => {
        return LogQueryService.mapApiItem(item, filter.category);
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

  static buildLogQueryPath(filter: LogQueryFilter): string {
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

    return `/api/v1/log-center/logs?${params.join('&')}`;
  }

  static resolveArchiveCategory(tab: LogQueryTab): LogCategory {
    return tab === LogQueryTab.Review ? LogCategory.ArchiveReview : LogCategory.ArchiveOperation;
  }

  static resolveOperationsCategory(tab: LogQueryTab): LogCategory {
    return tab === LogQueryTab.Review ? LogCategory.OperationsReview : LogCategory.OperationsOperation;
  }

  static getArchiveLogTypeOptions(tab: LogQueryTab): string[] {
    return tab === LogQueryTab.Review ? [...ARCHIVE_REVIEW_TYPE_OPTIONS] : [...ARCHIVE_OPERATION_TYPE_OPTIONS];
  }

  static getArchiveLogTypeValues(tab: LogQueryTab): string[] {
    return tab === LogQueryTab.Review ? [...ARCHIVE_REVIEW_TYPE_VALUES] : [...ARCHIVE_OPERATION_TYPE_VALUES];
  }

  static getOperationsLogTypeOptions(tab: LogQueryTab): string[] {
    return tab === LogQueryTab.Review ? [...OPERATIONS_REVIEW_TYPE_OPTIONS] : [...OPERATIONS_OPERATION_TYPE_OPTIONS];
  }

  static getOperationsLogTypeValues(tab: LogQueryTab): string[] {
    return tab === LogQueryTab.Review ? [...OPERATIONS_REVIEW_TYPE_VALUES] : [...OPERATIONS_OPERATION_TYPE_VALUES];
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

  static formatTypeLabel(action: string, category?: LogCategory): string {
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
        return category === LogCategory.ArchiveOperation ? '档案添加' : '添加档案';
      case 'UPDATE':
        return category === LogCategory.ArchiveOperation ? '档案修改' : '修改档案';
      case 'DELETE':
        return category === LogCategory.ArchiveOperation ? '档案删除' : '删除档案';
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
      default:
        return action;
    }
  }

  static formatPageTitle(category: LogCategory): string {
    switch (category) {
      case LogCategory.ArchiveReview:
        return '档案审核日志';
      case LogCategory.OperationsOperation:
        return '运维操作日志';
      case LogCategory.OperationsReview:
        return '运维审核日志';
      case LogCategory.ArchiveOperation:
      default:
        return '档案操作日志';
    }
  }

  static formatListTitle(category: LogCategory): string {
    return `${LogQueryService.formatPageTitle(category)}列表`;
  }

  private static mapApiItem(item: ApiLogItem, category: LogCategory): LogItem {
    return {
      id: `${item.logCategory}-${item.logType}-${item.taskNo}-${item.occurredAt}`,
      category,
      type: item.logType,
      typeLabel: LogQueryService.formatTypeLabel(item.logType, category),
      deviceCode: item.deviceCode ?? '-',
      taskNo: item.taskNo ?? '-',
      operatorName: item.operatorName ?? '-',
      occurredAt: LogQueryService.formatTimestampForDisplay(item.occurredAt),
      status: item.businessStatus,
      statusLabel: LogQueryService.formatStatus(item.businessStatus),
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

    return `${date.getFullYear()}-${LogQueryService.pad2(date.getMonth() + 1)}-${LogQueryService.pad2(date.getDate())} ` +
      `${LogQueryService.pad2(date.getHours())}:${LogQueryService.pad2(date.getMinutes())}:${LogQueryService.pad2(date.getSeconds())}`;
  }

  private static pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
