import { ApiError, ApiResponse } from '../../models/common/ApiModels';
import {
  FaultReportForm,
  FaultReportRecord,
  FaultReportValidationResult,
  FaultSeverity,
  FaultStatus,
  FaultType
} from '../../models/operations/FaultModels';
import { ApiClient } from '../common/ApiClient';
import { DeviceService } from '../archive/DeviceService';
import { UiFeedbackService } from '../common/UiFeedbackService';

const MAX_DESCRIPTION_LENGTH = 800;
const MAX_SCENE_CONDITION_LENGTH = 500;

interface FaultReportApiResult {
  id: string;
  faultReportNo: string;
  status: FaultStatus;
  createdAt: string;
}

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
        message: UiFeedbackService.requiredSelection('故障类型')
      };
    }

    if (!FaultReportService.isKnownSeverity(form.severity)) {
      return {
        valid: false,
        message: UiFeedbackService.requiredSelection('故障等级')
      };
    }

    const occurredAt = FaultReportService.normalizeText(form.occurredAt);
    if (occurredAt.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredTime('故障')
      };
    }

    if (occurredAt.length > 64) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('故障时间', 64, '字')
      };
    }

    const description = FaultReportService.normalizeText(form.description);
    if (description.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('故障说明')
      };
    }

    if (description.length > MAX_DESCRIPTION_LENGTH) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('故障说明', 800, '字')
      };
    }

    const sceneCondition = FaultReportService.normalizeText(form.sceneCondition);
    if (sceneCondition.length > MAX_SCENE_CONDITION_LENGTH) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('备注', 500, '字')
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  static async submitFaultReportRemoteFirst(form: FaultReportForm): Promise<ApiResponse<FaultReportRecord>> {
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
      return ApiClient.createServiceUnavailableResponse<FaultReportRecord>();
    }

    return FaultReportService.submitFaultReportToBackend(form);
  }

  private static async submitFaultReportToBackend(form: FaultReportForm): Promise<ApiResponse<FaultReportRecord>> {
    const response = await ApiClient.request<FaultReportApiResult>('/api/v1/fault-reports', 'POST', true,
      JSON.stringify({
        deviceCode: DeviceService.normalizeDeviceCode(form.deviceCode),
        faultType: form.faultType,
        severity: form.severity,
        occurredAt: FaultReportService.normalizeText(form.occurredAt),
        description: FaultReportService.normalizeText(form.description),
        sceneCondition: FaultReportService.normalizeText(form.sceneCondition)
      }));

    if (!response.success) {
      return {
        success: false,
        error: FaultReportService.createSubmitError(response.error === undefined ? '' : `${response.error.code}`,
          response.error === undefined ? '' : response.error.message),
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    if (response.data === undefined) {
      return {
        success: false,
        error: {
          code: 'FAULT_REPORT_RESPONSE_INVALID',
          message: UiFeedbackService.operationUnavailable('提交')
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: FaultReportService.createRecordFromApiResult(form, response.data),
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static formatFaultType(type: FaultType): string {
    switch (type) {
      case FaultType.OperationAbnormal:
        return '运行异常';
      case FaultType.HardwareDamage:
        return '部件损坏';
      case FaultType.CommunicationFault:
        return '通信故障';
      case FaultType.LogicFault:
        return '逻辑故障';
      case FaultType.EnergyFault:
        return '能源故障';
      case FaultType.ExternalFactor:
        return '外部因素';
      case FaultType.Other:
        return '其他';
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

  static formatSeverityDescription(severity: FaultSeverity): string {
    switch (severity) {
      case FaultSeverity.Emergency:
        return '关键能力已中断或设备停机，可能造成安全事故、重大损失或大范围业务中断，应立即处置';
      case FaultSeverity.Severe:
        return '核心能力明显受损，运行效率或质量显著下降，存在停机风险，需要优先安排维修';
      case FaultSeverity.General:
        return '局部功能或指标异常，设备仍可受控运行，但已影响效率、质量或现场操作体验';
      case FaultSeverity.Minor:
        return '暂不影响正常使用，但存在缺陷、隐患或趋势性异常，应记录并跟踪处理';
      default:
        return '-';
    }
  }

  static formatFaultStatus(status: FaultStatus): string {
    switch (status) {
      case FaultStatus.PendingAcceptance:
        return '待接取';
      case FaultStatus.Accepted:
        return '已接取';
      case FaultStatus.UnderRepair:
        return '维修中';
      case FaultStatus.PendingReinspection:
        return '待复检';
      case FaultStatus.Closed:
        return '已关闭';
      default:
        return '-';
    }
  }

  static formatFaultTypeDescription(type: FaultType): string {
    switch (type) {
      case FaultType.OperationAbnormal:
        return '运行状态、性能表现或作业流程偏离预期，可能影响稳定性或产出一致性';
      case FaultType.HardwareDamage:
        return '机械结构、电气部件或关键零部件出现损坏、失效、松动或磨损超限';
      case FaultType.CommunicationFault:
        return '网络链路、协议交互、远程连接或数据传输异常，导致状态同步或控制受阻';
      case FaultType.LogicFault:
        return '控制策略、业务规则、程序状态或参数配置异常，导致设备行为不符合预期';
      case FaultType.EnergyFault:
        return '供电、储能、电源链路或能耗表现异常，可能影响连续运行或安全边界';
      case FaultType.ExternalFactor:
        return '环境、人为操作、施工干扰、自然灾害等外部条件引发或放大设备异常';
      case FaultType.Other:
        return '现象明确但暂无法归入既有类别，提交时应补充充分现场描述和证据';
      default:
        return '-';
    }
  }

  private static isKnownFaultType(type: FaultType): boolean {
    return type === FaultType.OperationAbnormal ||
      type === FaultType.HardwareDamage ||
      type === FaultType.CommunicationFault ||
      type === FaultType.LogicFault ||
      type === FaultType.EnergyFault ||
      type === FaultType.ExternalFactor ||
      type === FaultType.Other;
  }

  private static isKnownSeverity(severity: FaultSeverity): boolean {
    return severity === FaultSeverity.Emergency ||
      severity === FaultSeverity.Severe ||
      severity === FaultSeverity.General ||
      severity === FaultSeverity.Minor;
  }

  private static createRecordFromApiResult(form: FaultReportForm, result: FaultReportApiResult): FaultReportRecord {
    return {
      id: result.id,
      reportNo: result.faultReportNo,
      deviceCode: DeviceService.normalizeDeviceCode(form.deviceCode),
      faultType: form.faultType,
      severity: form.severity,
      status: result.status as FaultStatus,
      submittedAt: result.createdAt
    };
  }

  private static createSubmitError(code: string, fallbackMessage: string): ApiError {
    if (code === 'DEVICE_ACTIVE_FAULT_EXISTS') {
      return {
        code,
        message: UiFeedbackService.operationUnavailable('报修')
      };
    }

    return {
      code: code.length === 0 ? 'FAULT_REPORT_SUBMIT_FAILED' : code,
      message: fallbackMessage.length === 0 ? UiFeedbackService.operationUnavailable('提交') : UiFeedbackService.sanitize(fallbackMessage)
    };
  }
}
