import { AppColors } from '../../shared/theme/AppTheme';
import { ApiResponse } from '../../shared/models/ApiModels';
import { ArchiveRequestStatus } from '../../archive/models/ArchiveRequestModels';
import {
  ArchiveRequestFieldDiff,
  ArchiveReviewDecision,
  ArchiveReviewForm,
  ArchiveReviewItem,
  ArchiveReviewListResult,
  ArchiveReviewRequestType,
  ArchiveReviewResult
} from '../../archive/models/ArchiveReviewModels';
import { ApiClient } from '../../shared/services/ApiClient';
import { DateTimeFormatUtil } from '../../shared/utils/DateTimeFormatUtil';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';

interface ApiListResult<T> {
  items: T[];
  total: number;
}

interface ArchiveUpdateApiValue {
  oldValue?: string;
  newValue?: string;
}

interface ArchiveReviewApiItem {
  id: string;
  type?: ArchiveReviewRequestType;
  deviceId?: string;
  deviceCode: string;
  deviceName: string;
  operatorId?: string;
  operatorName?: string;
  reason: string;
  status: ArchiveRequestStatus;
  initiatedAt?: string;
  createdAt: string;
  submittedAt?: string;
  changes: Record<string, ArchiveUpdateApiValue>;
}

export class ArchiveReviewService {
  static async listPendingReviewsRemoteFirst(): Promise<ApiResponse<ArchiveReviewListResult>> {
    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<ArchiveReviewListResult>();
    }

    const response = await ApiClient.request<ApiListResult<ArchiveReviewApiItem>>(
      '/api/v1/archive-requests?status=PENDING_REVIEW',
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

    const items = response.data === undefined ? [] : response.data.items.map((item: ArchiveReviewApiItem): ArchiveReviewItem => {
      return ArchiveReviewService.mapApiItem(item);
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

  static async reviewArchiveRequestRemoteFirst(form: ArchiveReviewForm): Promise<ApiResponse<ArchiveReviewResult>> {
    if (form.requestId.trim().length === 0) {
      return {
        success: false,
        error: {
          code: 'ARCHIVE_REQUEST_REVIEW_REQUEST_INVALID',
          message: UiFeedbackService.requiredSelection('待审核操作')
        }
      };
    }

    if (form.decision === ArchiveReviewDecision.Rejected && form.reviewComment.trim().length === 0) {
      return {
        success: false,
        error: {
          code: 'ARCHIVE_REQUEST_REVIEW_COMMENT_REQUIRED',
          message: UiFeedbackService.requiredInput('审核意见')
        }
      };
    }

    const reviewedAt = ArchiveReviewService.toApiReviewedAt(form.reviewedAt);
    if (reviewedAt.length === 0) {
      return {
        success: false,
        error: {
          code: 'ARCHIVE_REQUEST_REVIEW_TIME_INVALID',
          message: UiFeedbackService.requiredTime('审核')
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<ArchiveReviewResult>();
    }

    return ApiClient.request<ArchiveReviewResult>(
      `/api/v1/archive-requests/${encodeURIComponent(form.requestId)}/review`,
      'POST',
      true,
      JSON.stringify({
        decision: form.decision,
        reviewedAt,
        reviewComment: form.reviewComment.trim()
      })
    );
  }

  static formatRequestType(type: ArchiveReviewRequestType): string {
    switch (type) {
      case ArchiveReviewRequestType.Create:
        return '添加档案';
      case ArchiveReviewRequestType.Delete:
        return '删除档案';
      case ArchiveReviewRequestType.Update:
        return '修改档案';
      default:
        return '-';
    }
  }

  static getRequestTypeTone(type: ArchiveReviewRequestType): string {
    switch (type) {
      case ArchiveReviewRequestType.Create:
        return AppColors.Success;
      case ArchiveReviewRequestType.Delete:
        return AppColors.Danger;
      case ArchiveReviewRequestType.Update:
        return AppColors.Primary;
      default:
        return AppColors.TextSecondary;
    }
  }

  static formatDecision(decision: ArchiveReviewDecision): string {
    switch (decision) {
      case ArchiveReviewDecision.Approved:
        return '审核通过';
      case ArchiveReviewDecision.Rejected:
        return '审核驳回';
      default:
        return '-';
    }
  }

  static formatStatus(status: ArchiveRequestStatus): string {
    switch (status) {
      case ArchiveRequestStatus.PendingReview:
        return '待审核';
      case ArchiveRequestStatus.Approved:
        return '已通过';
      case ArchiveRequestStatus.Rejected:
        return '已驳回';
      case ArchiveRequestStatus.Withdrawn:
        return '已撤回';
      default:
        return '-';
    }
  }

  static getStatusTone(status: ArchiveRequestStatus): string {
    switch (status) {
      case ArchiveRequestStatus.PendingReview:
        return AppColors.Warning;
      case ArchiveRequestStatus.Approved:
        return AppColors.Success;
      case ArchiveRequestStatus.Rejected:
        return AppColors.Danger;
      case ArchiveRequestStatus.Withdrawn:
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

  private static mapApiItem(item: ArchiveReviewApiItem): ArchiveReviewItem {
    return {
      id: item.id,
      type: item.type === undefined ? ArchiveReviewRequestType.Update : item.type,
      deviceId: item.deviceId,
      deviceCode: item.deviceCode,
      deviceName: item.deviceName,
      operatorName: item.operatorName === undefined || item.operatorName.length === 0 ? item.operatorId : item.operatorName,
      reason: item.reason,
      status: item.status,
      initiatedAt: ArchiveReviewService.resolveTimeText(item.initiatedAt, item.createdAt),
      submittedAt: ArchiveReviewService.resolveTimeText(item.submittedAt, item.createdAt),
      changes: ArchiveReviewService.mapApiChanges(item.changes)
    };
  }

  private static resolveTimeText(value: string | undefined, fallback: string): string {
    if (value !== undefined && value.trim().length > 0) {
      return value.trim();
    }

    return fallback;
  }

  private static mapApiChanges(changes: Record<string, ArchiveUpdateApiValue>): ArchiveRequestFieldDiff[] {
    const result: ArchiveRequestFieldDiff[] = [];
    const fields = Object.keys(changes);
    for (let i = 0; i < fields.length; i += 1) {
      const field = fields[i];
      const change = changes[field];
      result.push({
        field,
        label: ArchiveReviewService.formatFieldLabel(field),
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
