import { AppColors } from '../../styles/AppTheme';
import { ApiResponse } from '../../models/common/ApiModels';
import { DeviceArchiveRequestStatus } from '../../models/archive/DeviceArchiveRequestModels';
import {
  DeviceArchiveRequestFieldDiff,
  DeviceArchiveReviewDecision,
  DeviceArchiveReviewForm,
  DeviceArchiveReviewItem,
  DeviceArchiveReviewListResult,
  DeviceArchiveReviewRequestType,
  DeviceArchiveReviewResult
} from '../../models/archive/DeviceArchiveReviewModels';
import { ApiClient } from '../common/ApiClient';
import { DateTimeFormatUtil } from '../../utils/DateTimeFormatUtil';

interface ApiListResult<T> {
  items: T[];
  total: number;
}

interface DeviceArchiveUpdateApiValue {
  oldValue?: string;
  newValue?: string;
}

interface DeviceArchiveReviewApiItem {
  id: string;
  type?: DeviceArchiveReviewRequestType;
  deviceId?: string;
  deviceCode: string;
  deviceName: string;
  operatorId?: string;
  operatorName?: string;
  reason: string;
  status: DeviceArchiveRequestStatus;
  initiatedAt?: string;
  createdAt: string;
  submittedAt?: string;
  changes: Record<string, DeviceArchiveUpdateApiValue>;
}

export class DeviceArchiveReviewService {
  static async listPendingReviewsRemoteFirst(): Promise<ApiResponse<DeviceArchiveReviewListResult>> {
    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<DeviceArchiveReviewListResult>();
    }

    const response = await ApiClient.request<ApiListResult<DeviceArchiveReviewApiItem>>(
      '/api/v1/device-archive-requests?status=PENDING_REVIEW',
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

    const items = response.data === undefined ? [] : response.data.items.map((item: DeviceArchiveReviewApiItem): DeviceArchiveReviewItem => {
      return DeviceArchiveReviewService.mapApiItem(item);
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

  static async reviewArchiveRequestRemoteFirst(form: DeviceArchiveReviewForm): Promise<ApiResponse<DeviceArchiveReviewResult>> {
    if (form.requestId.trim().length === 0) {
      return {
        success: false,
        error: {
          code: 'ARCHIVE_REQUEST_REVIEW_REQUEST_INVALID',
          message: '缺少档案申请编号'
        }
      };
    }

    if (form.decision === DeviceArchiveReviewDecision.Rejected && form.reviewComment.trim().length === 0) {
      return {
        success: false,
        error: {
          code: 'ARCHIVE_REQUEST_REVIEW_COMMENT_REQUIRED',
          message: '驳回申请时必须填写审核意见'
        }
      };
    }

    const reviewedAt = DeviceArchiveReviewService.toApiReviewedAt(form.reviewedAt);
    if (reviewedAt.length === 0) {
      return {
        success: false,
        error: {
          code: 'ARCHIVE_REQUEST_REVIEW_TIME_INVALID',
          message: '请选择审核时间'
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<DeviceArchiveReviewResult>();
    }

    return ApiClient.request<DeviceArchiveReviewResult>(
      `/api/v1/device-archive-requests/${encodeURIComponent(form.requestId)}/review`,
      'POST',
      true,
      JSON.stringify({
        decision: form.decision,
        reviewedAt,
        reviewComment: form.reviewComment.trim()
      })
    );
  }

  static formatRequestType(type: DeviceArchiveReviewRequestType): string {
    switch (type) {
      case DeviceArchiveReviewRequestType.Create:
        return '添加档案';
      case DeviceArchiveReviewRequestType.Delete:
        return '删除档案';
      case DeviceArchiveReviewRequestType.Update:
        return '修改档案';
      default:
        return '-';
    }
  }

  static getRequestTypeTone(type: DeviceArchiveReviewRequestType): string {
    switch (type) {
      case DeviceArchiveReviewRequestType.Create:
        return AppColors.Success;
      case DeviceArchiveReviewRequestType.Delete:
        return AppColors.Danger;
      case DeviceArchiveReviewRequestType.Update:
        return AppColors.Primary;
      default:
        return AppColors.TextSecondary;
    }
  }

  static formatDecision(decision: DeviceArchiveReviewDecision): string {
    switch (decision) {
      case DeviceArchiveReviewDecision.Approved:
        return '审核通过';
      case DeviceArchiveReviewDecision.Rejected:
        return '审核驳回';
      default:
        return '-';
    }
  }

  static formatStatus(status: DeviceArchiveRequestStatus): string {
    switch (status) {
      case DeviceArchiveRequestStatus.PendingReview:
        return '待审核';
      case DeviceArchiveRequestStatus.Approved:
        return '已通过';
      case DeviceArchiveRequestStatus.Rejected:
        return '已驳回';
      case DeviceArchiveRequestStatus.Withdrawn:
        return '已撤回';
      default:
        return '-';
    }
  }

  static getStatusTone(status: DeviceArchiveRequestStatus): string {
    switch (status) {
      case DeviceArchiveRequestStatus.PendingReview:
        return AppColors.Warning;
      case DeviceArchiveRequestStatus.Approved:
        return AppColors.Success;
      case DeviceArchiveRequestStatus.Rejected:
        return AppColors.Danger;
      case DeviceArchiveRequestStatus.Withdrawn:
        return AppColors.TextSecondary;
      default:
        return AppColors.TextSecondary;
    }
  }

  static formatFieldLabel(field: string): string {
    switch (field) {
      case 'name':
        return '设备名称';
      case 'model':
        return '设备型号';
      case 'manufacturer':
        return '生产厂商';
      case 'location.address':
        return '设备位置';
      default:
        return field;
    }
  }

  private static mapApiItem(item: DeviceArchiveReviewApiItem): DeviceArchiveReviewItem {
    return {
      id: item.id,
      type: item.type === undefined ? DeviceArchiveReviewRequestType.Update : item.type,
      deviceId: item.deviceId,
      deviceCode: item.deviceCode,
      deviceName: item.deviceName,
      operatorName: item.operatorName === undefined || item.operatorName.length === 0 ? item.operatorId : item.operatorName,
      reason: item.reason,
      status: item.status,
      initiatedAt: DeviceArchiveReviewService.resolveTimeText(item.initiatedAt, item.createdAt),
      submittedAt: DeviceArchiveReviewService.resolveTimeText(item.submittedAt, item.createdAt),
      changes: DeviceArchiveReviewService.mapApiChanges(item.changes)
    };
  }

  private static resolveTimeText(value: string | undefined, fallback: string): string {
    if (value !== undefined && value.trim().length > 0) {
      return value.trim();
    }

    return fallback;
  }

  private static mapApiChanges(changes: Record<string, DeviceArchiveUpdateApiValue>): DeviceArchiveRequestFieldDiff[] {
    const result: DeviceArchiveRequestFieldDiff[] = [];
    const fields = Object.keys(changes);
    for (let i = 0; i < fields.length; i += 1) {
      const field = fields[i];
      const change = changes[field];
      result.push({
        field,
        label: DeviceArchiveReviewService.formatFieldLabel(field),
        oldValue: change.oldValue === undefined ? '-' : `${change.oldValue}`,
        newValue: change.newValue === undefined ? '-' : `${change.newValue}`
      });
    }

    return result;
  }

  private static toApiReviewedAt(value: string): string {
    const date = DateTimeFormatUtil.parseLocalDisplayDateTime(value);
    return date === undefined ? '' : date.toISOString();
  }
}
