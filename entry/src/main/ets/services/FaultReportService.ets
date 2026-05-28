import { ApiErrorCode, ApiResponse } from '../models/ApiModels';
import {
  FaultReportForm,
  FaultReportRecord,
  FaultReportValidationResult,
  FaultSeverity,
  FaultType
} from '../models/FaultModels';
import { ApiClient } from './ApiClient';
import { DeviceService } from './DeviceService';

const MAX_DESCRIPTION_LENGTH = 800;
const MAX_SCENE_CONDITION_LENGTH = 500;

export class FaultReportService {
  static normalizeText(value: string): string {
    return value.trim();
  }

  static validateFaultReportForm(form: FaultReportForm): FaultReportValidationResult {
    const deviceCodeValidation = DeviceService.validateDeviceCodeQuery({
      deviceCode: form.deviceCode
    });

    if (!deviceCodeValidation.valid) {
      return {
        valid: false,
        message: deviceCodeValidation.message
      };
    }

    if (!FaultReportService.isKnownFaultType(form.faultType)) {
      return {
        valid: false,
        message: '请选择故障类型'
      };
    }

    if (!FaultReportService.isKnownSeverity(form.severity)) {
      return {
        valid: false,
        message: '请选择故障等级'
      };
    }

    const occurredAt = FaultReportService.normalizeText(form.occurredAt);
    if (occurredAt.length === 0) {
      return {
        valid: false,
        message: '请输入发生时间'
      };
    }

    if (occurredAt.length > 64) {
      return {
        valid: false,
        message: '发生时间不能超过64字'
      };
    }

    const description = FaultReportService.normalizeText(form.description);
    if (description.length === 0) {
      return {
        valid: false,
        message: '请输入故障描述'
      };
    }

    if (description.length > MAX_DESCRIPTION_LENGTH) {
      return {
        valid: false,
        message: '故障描述不能超过800字'
      };
    }

    const sceneCondition = FaultReportService.normalizeText(form.sceneCondition);
    if (sceneCondition.length > MAX_SCENE_CONDITION_LENGTH) {
      return {
        valid: false,
        message: '现场情况不能超过500字'
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  static submitFaultReport(form: FaultReportForm): ApiResponse<FaultReportRecord> {
    const validation = FaultReportService.validateFaultReportForm(form);
    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'FAULT_REPORT_INVALID',
          message: validation.message
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return {
        success: false,
        error: {
          code: ApiErrorCode.ServiceUnavailable,
          message: '后端服务未配置，暂不能提交'
        }
      };
    }

    return ApiClient.createServiceUnavailableResponse<FaultReportRecord>();
  }

  static formatFaultType(type: FaultType): string {
    switch (type) {
      case FaultType.OperationAbnormal:
        return '运行异常';
      case FaultType.NetworkAbnormal:
        return '通信异常';
      case FaultType.HardwareDamage:
        return '部件损坏';
      case FaultType.SafetyRisk:
        return '安全风险';
      case FaultType.Other:
        return '其他';
      default:
        return '-';
    }
  }

  static formatSeverity(severity: FaultSeverity): string {
    switch (severity) {
      case FaultSeverity.General:
        return '一般';
      case FaultSeverity.Major:
        return '重大';
      case FaultSeverity.Critical:
        return '紧急';
      default:
        return '-';
    }
  }

  private static isKnownFaultType(type: FaultType): boolean {
    return type === FaultType.OperationAbnormal ||
      type === FaultType.NetworkAbnormal ||
      type === FaultType.HardwareDamage ||
      type === FaultType.SafetyRisk ||
      type === FaultType.Other;
  }

  private static isKnownSeverity(severity: FaultSeverity): boolean {
    return severity === FaultSeverity.General ||
      severity === FaultSeverity.Major ||
      severity === FaultSeverity.Critical;
  }
}
