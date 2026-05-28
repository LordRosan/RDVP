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
        return '核心功能完全不可用，影响所有用户，造成重大损失；设备完全停机，可能引发安全事故或严重生产中断';
      case FaultSeverity.Severe:
        return '核心功能受损，大部分用户受影响，但非全部；设备运行效率极低，很大可能停机，严重影响产量或质量';
      case FaultSeverity.General:
        return '非核心功能异常，部分用户受影响，有临时方案；设备降效运行，但未停机，明显影响产量或质量';
      case FaultSeverity.Minor:
        return '不影响业务，可正常运行，但存在隐患或小缺陷';
      default:
        return '-';
    }
  }

  static formatFaultTypeDescription(type: FaultType): string {
    switch (type) {
      case FaultType.OperationAbnormal:
        return '设备运行状态、性能输出或工作流程出现异常';
      case FaultType.HardwareDamage:
        return '硬件、结构件或关键部件损坏、失效或磨损超限';
      case FaultType.CommunicationFault:
        return '网络链路、协议交互、数据传输或远程连接异常';
      case FaultType.LogicFault:
        return '控制逻辑、业务规则、程序状态或配置逻辑异常';
      case FaultType.EnergyFault:
        return '供电、储能、电源链路、能耗或能源供应异常';
      case FaultType.ExternalFactor:
        return '环境、人为、施工、灾害等外部条件导致异常';
      case FaultType.Other:
        return '无法归入以上类别的故障';
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
}
