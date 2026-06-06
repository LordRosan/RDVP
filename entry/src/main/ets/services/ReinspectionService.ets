import { AppColors } from '../styles/AppTheme';
import { ApiResponse } from '../models/ApiModels';
import { FaultSeverity, FaultStatus } from '../models/FaultModels';
import { OperationRecordType } from '../models/OperationRecordModels';
import {
  ReinspectionRecord,
  ReinspectionRecordForm,
  ReinspectionResult,
  ReinspectionTaskStatus,
  ReinspectionTaskListResult,
  ReinspectionTaskSummary,
  ReinspectionValidationResult
} from '../models/ReinspectionModels';
import { ApiClient } from './ApiClient';
import { LocalOperationRecordRepository } from './LocalOperationRecordRepository';
import { LocalReinspectionRepository } from './LocalReinspectionRepository';
import { SessionStore } from '../stores/SessionStore';

const MAX_REINSPECTION_DESCRIPTION_LENGTH = 800;

interface DeviceLocationApiResult {
  address: string;
}

interface ReinspectionTaskApiSummary {
  id: string;
  faultReportId: string;
  faultReportNo: string;
  deviceCode: string;
  deviceName: string;
  severity: FaultSeverity;
  location: DeviceLocationApiResult;
  repairedAt?: string;
  status: FaultStatus;
}

interface ReinspectionRecordApiResult {
  id: string;
  reinspectionRecordNo?: string;
  faultReportId: string;
  result: ReinspectionResult;
  createdAt: string;
}

interface ApiListResult<T> {
  items: T[];
  total: number;
}

export class ReinspectionService {
  static queryPendingTasks(): ApiResponse<ReinspectionTaskListResult> {
    if (!ApiClient.isConfigured()) {
      return {
        success: true,
        data: LocalReinspectionRepository.queryPendingTasks(),
        requestId: 'local-reinspection-tasks',
        timestamp: new Date().toISOString()
      };
    }

    return ApiClient.createServiceUnavailableResponse<ReinspectionTaskListResult>();
  }

  static async queryPendingTasksRemoteFirst(): Promise<ApiResponse<ReinspectionTaskListResult>> {
    if (!ApiClient.isConfigured()) {
      return {
        success: true,
        data: LocalReinspectionRepository.queryPendingTasks(),
        requestId: 'local-reinspection-tasks',
        timestamp: new Date().toISOString()
      };
    }

    const response = await ApiClient.request<ApiListResult<ReinspectionTaskApiSummary>>(
      '/api/v1/reinspections/pending',
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

    return {
      success: true,
      data: {
        items: response.data === undefined ? [] : response.data.items.map((item: ReinspectionTaskApiSummary): ReinspectionTaskSummary => {
          return ReinspectionService.mapTask(item);
        }),
        total: response.data === undefined ? 0 : response.data.total
      },
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static validateRecordForm(form: ReinspectionRecordForm): ReinspectionValidationResult {
    if (form.taskId.trim().length === 0) {
      return {
        valid: false,
        message: '请选择复检任务'
      };
    }

    if (!ReinspectionService.isKnownResult(form.result)) {
      return {
        valid: false,
        message: '请选择复检结论'
      };
    }

    if (form.reinspectedAt.trim().length === 0) {
      return {
        valid: false,
        message: '请选择复检时间'
      };
    }

    const description = form.description.trim();
    if (description.length === 0) {
      return {
        valid: false,
        message: '请输入复检说明'
      };
    }

    if (description.length > MAX_REINSPECTION_DESCRIPTION_LENGTH) {
      return {
        valid: false,
        message: '复检说明不能超过800字'
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  static submitRecord(form: ReinspectionRecordForm): ApiResponse<ReinspectionRecord> {
    const validation = ReinspectionService.validateRecordForm(form);
    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'REINSPECTION_RECORD_INVALID',
          message: validation.message
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return ReinspectionService.createLocalRecordResponse(form);
    }

    return ApiClient.createServiceUnavailableResponse<ReinspectionRecord>();
  }

  static async submitRecordRemoteFirst(form: ReinspectionRecordForm): Promise<ApiResponse<ReinspectionRecord>> {
    const validation = ReinspectionService.validateRecordForm(form);
    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'REINSPECTION_RECORD_INVALID',
          message: validation.message
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return ReinspectionService.createLocalRecordResponse(form);
    }

    const taskId = encodeURIComponent(form.taskId.trim());
    const response = await ApiClient.request<ReinspectionRecordApiResult>(
      `/api/v1/fault-reports/${taskId}/reinspection-records`,
      'POST',
      true,
      JSON.stringify({
        result: form.result,
        reinspectedAt: form.reinspectedAt.trim(),
        description: form.description.trim()
      })
    );

    if (!response.success) {
      return {
        success: false,
        error: response.error,
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    if (response.data === undefined) {
      return {
        success: false,
        error: {
          code: 'REINSPECTION_RECORD_RESPONSE_INVALID',
          message: '复检记录响应无效'
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: {
        id: response.data.id,
        recordNo: response.data.reinspectionRecordNo === undefined ? response.data.id : response.data.reinspectionRecordNo,
        taskId: response.data.faultReportId,
        result: response.data.result,
        submittedAt: response.data.createdAt
      },
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static formatResult(result: ReinspectionResult): string {
    switch (result) {
      case ReinspectionResult.Passed:
        return '通过';
      case ReinspectionResult.Failed:
        return '不通过';
      default:
        return '-';
    }
  }

  static formatSeverity(severity: FaultSeverity): string {
    switch (severity) {
      case FaultSeverity.Emergency:
        return '紧急';
      case FaultSeverity.Severe:
        return '严重';
      case FaultSeverity.General:
        return '一般';
      case FaultSeverity.Minor:
        return '轻微';
      default:
        return '-';
    }
  }

  static getResultTone(result: ReinspectionResult): string {
    switch (result) {
      case ReinspectionResult.Passed:
        return AppColors.Success;
      case ReinspectionResult.Failed:
        return AppColors.Danger;
      default:
        return AppColors.TextSecondary;
    }
  }

  static getSeverityTone(severity: FaultSeverity): string {
    switch (severity) {
      case FaultSeverity.Emergency:
        return AppColors.Danger;
      case FaultSeverity.Severe:
        return AppColors.Warning;
      case FaultSeverity.General:
        return AppColors.Primary;
      case FaultSeverity.Minor:
        return AppColors.Success;
      default:
        return AppColors.TextSecondary;
    }
  }

  private static isKnownResult(result: ReinspectionResult): boolean {
    return result === ReinspectionResult.Passed || result === ReinspectionResult.Failed;
  }

  private static createLocalRecordResponse(form: ReinspectionRecordForm): ApiResponse<ReinspectionRecord> {
    const record = LocalReinspectionRepository.submitRecord(form);
    if (record === undefined) {
      return {
        success: false,
        error: {
          code: 'REINSPECTION_TASK_NOT_FOUND',
          message: '复检任务不存在或已完成'
        }
      };
    }

    LocalOperationRecordRepository.append(OperationRecordType.ReinspectionRecord, '提交复检记录', record.recordNo,
      `复检结论：${ReinspectionService.formatResult(form.result)}`, SessionStore.getCurrentOperatorName());
    return {
      success: true,
      data: record,
      requestId: 'local-reinspection-record',
      timestamp: new Date().toISOString()
    };
  }

  private static mapTask(item: ReinspectionTaskApiSummary): ReinspectionTaskSummary {
    return {
      id: item.faultReportId,
      taskNo: item.faultReportNo,
      faultNo: item.faultReportNo,
      deviceCode: item.deviceCode,
      deviceName: item.deviceName,
      severity: item.severity,
      location: item.location.address,
      repairedAt: item.repairedAt === undefined ? '-' : item.repairedAt,
      status: item.status === FaultStatus.PendingReinspection ? ReinspectionTaskStatus.Pending : ReinspectionTaskStatus.Completed
    };
  }
}
