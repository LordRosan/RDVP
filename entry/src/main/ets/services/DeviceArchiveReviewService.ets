import { AppColors } from '../styles/AppTheme';
import { ApiResponse } from '../models/ApiModels';
import { DeviceArchiveChangeRequestStatus } from '../models/DeviceArchiveChangeModels';
import {
  DeviceArchiveChangeFieldDiff,
  DeviceArchiveReviewDecision,
  DeviceArchiveReviewForm,
  DeviceArchiveReviewItem,
  DeviceArchiveReviewListResult,
  DeviceArchiveReviewRequestType,
  DeviceArchiveReviewResult
} from '../models/DeviceArchiveReviewModels';
import { ApiClient } from './ApiClient';
import { LocalDeviceChangeRequestRepository } from './LocalDeviceChangeRequestRepository';

interface ApiListResult<T> {
  items: T[];
  total: number;
}

interface DeviceArchiveChangeApiValue {
  oldValue?: string;
  newValue?: string;
}

interface DeviceArchiveReviewApiItem {
  id: string;
  type?: DeviceArchiveReviewRequestType;
  deviceId?: string;
  deviceCode: string;
  deviceName: string;
  applicantName?: string;
  reason: string;
  status: DeviceArchiveChangeRequestStatus;
  initiatedAt?: string;
  createdAt: string;
  submittedAt?: string;
  changes: Record<string, DeviceArchiveChangeApiValue>;
}

export class DeviceArchiveReviewService {
  static async listPendingReviewsRemoteFirst(): Promise<ApiResponse<DeviceArchiveReviewListResult>> {
    if (!ApiClient.isConfigured()) {
      const items = LocalDeviceChangeRequestRepository.listPending();
      return {
        success: true,
        data: {
          items,
          total: items.length
        },
        requestId: 'local-device-change-review-list',
        timestamp: new Date().toISOString()
      };
    }

    const response = await ApiClient.request<ApiListResult<DeviceArchiveReviewApiItem>>(
      '/api/v1/device-change-requests?status=PENDING_REVIEW',
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

  static async reviewChangeRequestRemoteFirst(form: DeviceArchiveReviewForm): Promise<ApiResponse<DeviceArchiveReviewResult>> {
    if (form.requestId.trim().length === 0) {
      return {
        success: false,
        error: {
          code: 'CHANGE_REVIEW_REQUEST_INVALID',
          message: '缺少变更申请编号'
        }
      };
    }

    if (form.decision === DeviceArchiveReviewDecision.Rejected && form.reviewComment.trim().length === 0) {
      return {
        success: false,
        error: {
          code: 'CHANGE_REVIEW_COMMENT_REQUIRED',
          message: '驳回申请时必须填写审核意见'
        }
      };
    }

    const reviewedAt = DeviceArchiveReviewService.toApiReviewedAt(form.reviewedAt);
    if (reviewedAt.length === 0) {
      return {
        success: false,
        error: {
          code: 'CHANGE_REVIEW_TIME_INVALID',
          message: '请选择审核时间'
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      const result = LocalDeviceChangeRequestRepository.review(form.requestId, form.decision, form.reviewComment,
        form.reviewedAt);
      if (result === undefined) {
        return {
          success: false,
          error: {
            code: 'CHANGE_REQUEST_NOT_FOUND',
            message: '未找到可审核的变更申请'
          }
        };
      }

      return {
        success: true,
        data: result,
        requestId: 'local-device-change-review',
        timestamp: new Date().toISOString()
      };
    }

    return ApiClient.request<DeviceArchiveReviewResult>(
      `/api/v1/device-change-requests/${encodeURIComponent(form.requestId)}/review`,
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

  static formatStatus(status: DeviceArchiveChangeRequestStatus): string {
    switch (status) {
      case DeviceArchiveChangeRequestStatus.PendingSync:
        return '待同步';
      case DeviceArchiveChangeRequestStatus.PendingReview:
        return '待审核';
      case DeviceArchiveChangeRequestStatus.Approved:
        return '已通过';
      case DeviceArchiveChangeRequestStatus.Rejected:
        return '已驳回';
      case DeviceArchiveChangeRequestStatus.Withdrawn:
        return '已撤回';
      default:
        return '-';
    }
  }

  static getStatusTone(status: DeviceArchiveChangeRequestStatus): string {
    switch (status) {
      case DeviceArchiveChangeRequestStatus.PendingSync:
      case DeviceArchiveChangeRequestStatus.PendingReview:
        return AppColors.Warning;
      case DeviceArchiveChangeRequestStatus.Approved:
        return AppColors.Success;
      case DeviceArchiveChangeRequestStatus.Rejected:
        return AppColors.Danger;
      case DeviceArchiveChangeRequestStatus.Withdrawn:
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
      applicantName: item.applicantName,
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

  private static mapApiChanges(changes: Record<string, DeviceArchiveChangeApiValue>): DeviceArchiveChangeFieldDiff[] {
    const result: DeviceArchiveChangeFieldDiff[] = [];
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
    const date = DeviceArchiveReviewService.parseLocalDateTime(value);
    return date === undefined ? '' : date.toISOString();
  }

  private static parseLocalDateTime(value: string): Date | undefined {
    const trimmed = value.trim();
    const segments = trimmed.split(' ');
    if (segments.length !== 2) {
      return undefined;
    }

    const dateSegments = segments[0].split('-');
    const timeSegments = segments[1].split(':');
    if (dateSegments.length !== 3 || timeSegments.length < 2) {
      return undefined;
    }

    const year = Number(dateSegments[0]);
    const month = Number(dateSegments[1]);
    const day = Number(dateSegments[2]);
    const hour = Number(timeSegments[0]);
    const minute = Number(timeSegments[1]);
    if (year !== year || month !== month || day !== day || hour !== hour || minute !== minute) {
      return undefined;
    }

    return new Date(year, month - 1, day, hour, minute);
  }
}
