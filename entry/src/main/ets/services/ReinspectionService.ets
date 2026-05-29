import { ApiResponse } from '../models/ApiModels';
import { FaultSeverity } from '../models/FaultModels';
import { OperationRecordType } from '../models/OperationRecordModels';
import {
  ReinspectionRecord,
  ReinspectionRecordForm,
  ReinspectionResult,
  ReinspectionTaskListResult,
  ReinspectionValidationResult
} from '../models/ReinspectionModels';
import { ApiClient } from './ApiClient';
import { LocalOperationRecordRepository } from './LocalOperationRecordRepository';
import { LocalReinspectionRepository } from './LocalReinspectionRepository';

const MAX_REINSPECTION_DESCRIPTION_LENGTH = 800;

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
        `复检结论：${ReinspectionService.formatResult(form.result)}`);
      return {
        success: true,
        data: record,
        requestId: 'local-reinspection-record',
        timestamp: new Date().toISOString()
      };
    }

    return ApiClient.createServiceUnavailableResponse<ReinspectionRecord>();
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
        return '#087F5B';
      case ReinspectionResult.Failed:
        return '#D9480F';
      default:
        return '#374151';
    }
  }

  static getSeverityTone(severity: FaultSeverity): string {
    switch (severity) {
      case FaultSeverity.Emergency:
        return '#D9480F';
      case FaultSeverity.Severe:
        return '#E67700';
      case FaultSeverity.General:
        return '#2F6FED';
      case FaultSeverity.Minor:
        return '#087F5B';
      default:
        return '#374151';
    }
  }

  private static isKnownResult(result: ReinspectionResult): boolean {
    return result === ReinspectionResult.Passed || result === ReinspectionResult.Failed;
  }
}
