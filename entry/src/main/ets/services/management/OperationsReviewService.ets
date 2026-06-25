import { AppColors } from '../../styles/AppTheme';
import { ApiResponse } from '../../models/common/ApiModels';
import {
  OperationsReviewDecision,
  OperationsReviewForm,
  OperationsReviewItem,
  OperationsReviewListResult,
  OperationsReviewRequestStatus,
  OperationsReviewRequestType,
  OperationsReviewResult
} from '../../models/management/OperationsReviewModels';
import { DateTimeFormatUtil } from '../../utils/DateTimeFormatUtil';
import { ApiClient } from '../common/ApiClient';
import { UiFeedbackService } from '../common/UiFeedbackService';

interface ApiListResult<T> {
  items: T[];
  total: number;
}

interface OperationsReviewApiItem {
  id: string;
  type: OperationsReviewRequestType;
  targetId: string;
  targetNo: string;
  faultReportId: string;
  deviceId: string;
  deviceCode: string;
  deviceName: string;
  operatorId: string;
  operatorName?: string;
  summary?: string;
  status: OperationsReviewRequestStatus;
  submittedAt: string;
  reviewOperatorId?: string;
  reviewComment?: string;
  reviewedAt?: string;
}

const DEFAULT_OPERATIONS_REVIEW_PAGE_SIZE = 50;

export class OperationsReviewService {
  static async listPendingReviewsRemoteFirst(
    type: string = ''
  ): Promise<ApiResponse<OperationsReviewListResult>> {
    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<OperationsReviewListResult>();
    }

    const params: string[] = [];
    params.push('status=PENDING_REVIEW');
    params.push('page=1');
    params.push(`pageSize=${DEFAULT_OPERATIONS_REVIEW_PAGE_SIZE}`);
    const trimmedType = type.trim();
    if (trimmedType.length > 0) {
      params.push(`type=${encodeURIComponent(trimmedType)}`);
    }
    const response = await ApiClient.request<ApiListResult<OperationsReviewApiItem>>(
      `/api/v1/operations-review-requests?${params.join('&')}`,
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
      response.data.items.map((item: OperationsReviewApiItem): OperationsReviewItem => {
        return OperationsReviewService.mapApiItem(item);
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

  static async reviewOperationsRequestRemoteFirst(
    form: OperationsReviewForm
  ): Promise<ApiResponse<OperationsReviewResult>> {
    if (form.requestId.trim().length === 0) {
      return {
        success: false,
        error: {
          code: 'OPERATIONS_REVIEW_REQUEST_INVALID',
          message: UiFeedbackService.requiredSelection('待审核操作')
        }
      };
    }

    if (form.decision === OperationsReviewDecision.Rejected && form.reviewComment.trim().length === 0) {
      return {
        success: false,
        error: {
          code: 'OPERATIONS_REVIEW_COMMENT_REQUIRED',
          message: UiFeedbackService.requiredInput('审核意见')
        }
      };
    }

    const reviewedAt = OperationsReviewService.toApiReviewedAt(form.reviewedAt);
    if (reviewedAt.length === 0) {
      return {
        success: false,
        error: {
          code: 'OPERATIONS_REVIEW_TIME_INVALID',
          message: UiFeedbackService.requiredTime('审核')
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<OperationsReviewResult>();
    }

    return ApiClient.request<OperationsReviewResult>(
      `/api/v1/operations-review-requests/${encodeURIComponent(form.requestId)}/review`,
      'POST',
      true,
      JSON.stringify({
        decision: form.decision,
        reviewedAt,
        reviewComment: form.reviewComment.trim()
      })
    );
  }

  static formatRequestType(type: OperationsReviewRequestType): string {
    switch (type) {
      case OperationsReviewRequestType.DeviceVerificationReport:
        return '核验报告';
      case OperationsReviewRequestType.FaultReport:
        return '报修报告';
      case OperationsReviewRequestType.RepairReport:
        return '维修报告';
      case OperationsReviewRequestType.ReinspectionReport:
        return '复检报告';
      default:
        return '-';
    }
  }

  static getRequestTypeTone(type: OperationsReviewRequestType): string {
    switch (type) {
      case OperationsReviewRequestType.DeviceVerificationReport:
        return AppColors.Primary;
      case OperationsReviewRequestType.FaultReport:
        return AppColors.Danger;
      case OperationsReviewRequestType.RepairReport:
        return AppColors.Success;
      case OperationsReviewRequestType.ReinspectionReport:
        return AppColors.Warning;
      default:
        return AppColors.TextSecondary;
    }
  }

  static formatDecision(decision: OperationsReviewDecision): string {
    switch (decision) {
      case OperationsReviewDecision.Approved:
        return '审核通过';
      case OperationsReviewDecision.Rejected:
        return '审核驳回';
      default:
        return '-';
    }
  }

  static formatStatus(status: OperationsReviewRequestStatus): string {
    switch (status) {
      case OperationsReviewRequestStatus.PendingReview:
        return '待审核';
      case OperationsReviewRequestStatus.Approved:
        return '已通过';
      case OperationsReviewRequestStatus.Rejected:
        return '已驳回';
      default:
        return '-';
    }
  }

  static getStatusTone(status: OperationsReviewRequestStatus): string {
    switch (status) {
      case OperationsReviewRequestStatus.PendingReview:
        return AppColors.Warning;
      case OperationsReviewRequestStatus.Approved:
        return AppColors.Success;
      case OperationsReviewRequestStatus.Rejected:
        return AppColors.Danger;
      default:
        return AppColors.TextSecondary;
    }
  }

  private static mapApiItem(item: OperationsReviewApiItem): OperationsReviewItem {
    return {
      id: item.id,
      type: item.type,
      targetId: item.targetId,
      targetNo: item.targetNo,
      faultReportId: item.faultReportId,
      deviceId: item.deviceId,
      deviceCode: item.deviceCode,
      deviceName: item.deviceName,
      operatorId: item.operatorId,
      operatorName: item.operatorName === undefined || item.operatorName.length === 0 ? item.operatorId : item.operatorName,
      summary: item.summary === undefined ? '' : item.summary,
      status: item.status,
      submittedAt: item.submittedAt,
      reviewOperatorId: item.reviewOperatorId,
      reviewComment: item.reviewComment,
      reviewedAt: item.reviewedAt
    };
  }

  private static toApiReviewedAt(value: string): string {
    const date = DateTimeFormatUtil.parseLocalDisplayDateTime(value);
    return date === undefined ? '' : date.toISOString();
  }
}
