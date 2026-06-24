import { AppColors } from '../../styles/AppTheme';
import { ApiResponse } from '../../models/common/ApiModels';
import {
  OperationReviewDecision,
  OperationReviewForm,
  OperationReviewItem,
  OperationReviewListResult,
  OperationReviewRequestStatus,
  OperationReviewRequestType,
  OperationReviewResult
} from '../../models/management/OperationReviewModels';
import { DateTimeFormatUtil } from '../../utils/DateTimeFormatUtil';
import { ApiClient } from '../common/ApiClient';

interface ApiListResult<T> {
  items: T[];
  total: number;
}

interface OperationReviewApiItem {
  id: string;
  type: OperationReviewRequestType;
  targetId: string;
  targetNo: string;
  faultReportId: string;
  deviceId: string;
  deviceCode: string;
  deviceName: string;
  applicantId: string;
  applicantName?: string;
  summary?: string;
  status: OperationReviewRequestStatus;
  submittedAt: string;
  reviewerId?: string;
  reviewComment?: string;
  reviewedAt?: string;
}

const DEFAULT_OPERATION_REVIEW_PAGE_SIZE = 50;

export class OperationReviewService {
  static async listPendingReviewsRemoteFirst(
    type: string = '',
    keyword: string = ''
  ): Promise<ApiResponse<OperationReviewListResult>> {
    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<OperationReviewListResult>();
    }

    const params: string[] = [];
    params.push('status=PENDING_REVIEW');
    params.push('page=1');
    params.push(`pageSize=${DEFAULT_OPERATION_REVIEW_PAGE_SIZE}`);
    const trimmedType = type.trim();
    if (trimmedType.length > 0) {
      params.push(`type=${encodeURIComponent(trimmedType)}`);
    }
    const trimmedKeyword = keyword.trim();
    if (trimmedKeyword.length > 0) {
      params.push(`keyword=${encodeURIComponent(trimmedKeyword)}`);
    }

    const response = await ApiClient.request<ApiListResult<OperationReviewApiItem>>(
      `/api/v1/operation-review-requests?${params.join('&')}`,
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
      response.data.items.map((item: OperationReviewApiItem): OperationReviewItem => {
        return OperationReviewService.mapApiItem(item);
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

  static async reviewOperationRequestRemoteFirst(
    form: OperationReviewForm
  ): Promise<ApiResponse<OperationReviewResult>> {
    if (form.requestId.trim().length === 0) {
      return {
        success: false,
        error: {
          code: 'OPERATION_REVIEW_REQUEST_INVALID',
          message: '缺少运维审核编号'
        }
      };
    }

    if (form.decision === OperationReviewDecision.Rejected && form.reviewComment.trim().length === 0) {
      return {
        success: false,
        error: {
          code: 'OPERATION_REVIEW_COMMENT_REQUIRED',
          message: '驳回申请时必须填写审核意见'
        }
      };
    }

    const reviewedAt = OperationReviewService.toApiReviewedAt(form.reviewedAt);
    if (reviewedAt.length === 0) {
      return {
        success: false,
        error: {
          code: 'OPERATION_REVIEW_TIME_INVALID',
          message: '请选择审核时间'
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<OperationReviewResult>();
    }

    return ApiClient.request<OperationReviewResult>(
      `/api/v1/operation-review-requests/${encodeURIComponent(form.requestId)}/review`,
      'POST',
      true,
      JSON.stringify({
        decision: form.decision,
        reviewedAt,
        reviewComment: form.reviewComment.trim()
      })
    );
  }

  static formatRequestType(type: OperationReviewRequestType): string {
    switch (type) {
      case OperationReviewRequestType.RepairReport:
        return '维修报告';
      case OperationReviewRequestType.ReinspectionRecord:
        return '复检记录';
      default:
        return '-';
    }
  }

  static getRequestTypeTone(type: OperationReviewRequestType): string {
    switch (type) {
      case OperationReviewRequestType.RepairReport:
        return AppColors.Primary;
      case OperationReviewRequestType.ReinspectionRecord:
        return AppColors.Warning;
      default:
        return AppColors.TextSecondary;
    }
  }

  static formatDecision(decision: OperationReviewDecision): string {
    switch (decision) {
      case OperationReviewDecision.Approved:
        return '审核通过';
      case OperationReviewDecision.Rejected:
        return '审核驳回';
      default:
        return '-';
    }
  }

  static formatStatus(status: OperationReviewRequestStatus): string {
    switch (status) {
      case OperationReviewRequestStatus.PendingReview:
        return '待审核';
      case OperationReviewRequestStatus.Approved:
        return '已通过';
      case OperationReviewRequestStatus.Rejected:
        return '已驳回';
      default:
        return '-';
    }
  }

  static getStatusTone(status: OperationReviewRequestStatus): string {
    switch (status) {
      case OperationReviewRequestStatus.PendingReview:
        return AppColors.Warning;
      case OperationReviewRequestStatus.Approved:
        return AppColors.Success;
      case OperationReviewRequestStatus.Rejected:
        return AppColors.Danger;
      default:
        return AppColors.TextSecondary;
    }
  }

  private static mapApiItem(item: OperationReviewApiItem): OperationReviewItem {
    return {
      id: item.id,
      type: item.type,
      targetId: item.targetId,
      targetNo: item.targetNo,
      faultReportId: item.faultReportId,
      deviceId: item.deviceId,
      deviceCode: item.deviceCode,
      deviceName: item.deviceName,
      applicantId: item.applicantId,
      applicantName: item.applicantName === undefined || item.applicantName.length === 0 ? item.applicantId : item.applicantName,
      summary: item.summary === undefined ? '' : item.summary,
      status: item.status,
      submittedAt: item.submittedAt,
      reviewerId: item.reviewerId,
      reviewComment: item.reviewComment,
      reviewedAt: item.reviewedAt
    };
  }

  private static toApiReviewedAt(value: string): string {
    const date = DateTimeFormatUtil.parseLocalDisplayDateTime(value);
    return date === undefined ? '' : date.toISOString();
  }
}
