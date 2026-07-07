import {
  FaultReportForm,
  FaultReportValidationResult,
  FaultSeverity,
  FaultStatus,
  FaultSubtype,
  FaultType
} from '../models/FaultModels';
import { DeviceService } from '../../archive/services/DeviceService';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';

const MAX_DESCRIPTION_LENGTH = 800;
const MAX_SCENE_CONDITION_LENGTH = 500;

export interface FaultSubtypeOption {
  type: FaultType;
  subtype: FaultSubtype;
  label: string;
}

export interface FaultTypeSelection {
  faultType: FaultType;
  faultSubtype: FaultSubtype;
}

const FAULT_SUBTYPE_OPTIONS: FaultSubtypeOption[] = [
  {
    type: FaultType.OperationAbnormal,
    subtype: FaultSubtype.NoResponse,
    label: '无响应'
  },
  {
    type: FaultType.OperationAbnormal,
    subtype: FaultSubtype.PerformanceDegraded,
    label: '性能下降'
  },
  {
    type: FaultType.OperationAbnormal,
    subtype: FaultSubtype.IntermittentAbnormal,
    label: '间歇异常'
  },
  {
    type: FaultType.OperationAbnormal,
    subtype: FaultSubtype.ParameterAbnormal,
    label: '参数异常'
  },
  {
    type: FaultType.HardwareDamage,
    subtype: FaultSubtype.PartDamaged,
    label: '部件损坏'
  },
  {
    type: FaultType.HardwareDamage,
    subtype: FaultSubtype.LoosenedOrDeformed,
    label: '松动变形'
  },
  {
    type: FaultType.HardwareDamage,
    subtype: FaultSubtype.WearOrAging,
    label: '磨损老化'
  },
  {
    type: FaultType.HardwareDamage,
    subtype: FaultSubtype.MissingPart,
    label: '部件缺失'
  },
  {
    type: FaultType.CommunicationFault,
    subtype: FaultSubtype.ConnectionInterrupted,
    label: '连接中断'
  },
  {
    type: FaultType.CommunicationFault,
    subtype: FaultSubtype.SignalAbnormal,
    label: '信号异常'
  },
  {
    type: FaultType.CommunicationFault,
    subtype: FaultSubtype.DataAbnormal,
    label: '数据异常'
  },
  {
    type: FaultType.CommunicationFault,
    subtype: FaultSubtype.SyncFailed,
    label: '同步失败'
  },
  {
    type: FaultType.LogicFault,
    subtype: FaultSubtype.LogicException,
    label: '逻辑异常'
  },
  {
    type: FaultType.LogicFault,
    subtype: FaultSubtype.ConfigurationMismatch,
    label: '配置不符'
  },
  {
    type: FaultType.LogicFault,
    subtype: FaultSubtype.ProcessBlocked,
    label: '流程阻塞'
  },
  {
    type: FaultType.LogicFault,
    subtype: FaultSubtype.StateConflict,
    label: '状态冲突'
  },
  {
    type: FaultType.EnergyFault,
    subtype: FaultSubtype.PowerSupplyAbnormal,
    label: '供能异常'
  },
  {
    type: FaultType.EnergyFault,
    subtype: FaultSubtype.EnergyConsumptionAbnormal,
    label: '能耗异常'
  },
  {
    type: FaultType.EnergyFault,
    subtype: FaultSubtype.Overheated,
    label: '过热'
  },
  {
    type: FaultType.EnergyFault,
    subtype: FaultSubtype.ProtectionTriggered,
    label: '保护触发'
  },
  {
    type: FaultType.ExternalFactor,
    subtype: FaultSubtype.MoistureOrWater,
    label: '受潮进水'
  },
  {
    type: FaultType.ExternalFactor,
    subtype: FaultSubtype.DustPollution,
    label: '积尘污染'
  },
  {
    type: FaultType.ExternalFactor,
    subtype: FaultSubtype.ExternalImpact,
    label: '外力影响'
  },
  {
    type: FaultType.ExternalFactor,
    subtype: FaultSubtype.EnvironmentExceeded,
    label: '环境超限'
  },
  {
    type: FaultType.Other,
    subtype: FaultSubtype.ToBeConfirmed,
    label: '待确认'
  },
  {
    type: FaultType.Other,
    subtype: FaultSubtype.OtherAbnormal,
    label: '其他异常'
  }
];

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

    if (!FaultReportService.isKnownFaultSubtype(form.faultType, form.faultSubtype)) {
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

    if (!FaultReportService.hasValidLocation(form.longitude, form.latitude)) {
      return {
        valid: false,
        message: UiFeedbackService.requiredAction('获取故障地点')
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

  static formatFaultType(type: FaultType): string {
    switch (type) {
      case FaultType.OperationAbnormal:
        return '运行故障';
      case FaultType.HardwareDamage:
        return '部件故障';
      case FaultType.CommunicationFault:
        return '通信故障';
      case FaultType.LogicFault:
        return '逻辑故障';
      case FaultType.EnergyFault:
        return '能源故障';
      case FaultType.ExternalFactor:
        return '外部故障';
      case FaultType.Other:
        return '其他';
      default:
        return '-';
    }
  }

  static getFaultSubtypeOptions(type: FaultType): FaultSubtypeOption[] {
    return FAULT_SUBTYPE_OPTIONS.filter((item: FaultSubtypeOption) => {
      return item.type === type;
    }).map((item: FaultSubtypeOption): FaultSubtypeOption => {
      const option: FaultSubtypeOption = {
        type: item.type,
        subtype: item.subtype,
        label: item.label
      };
      return option;
    });
  }

  static getDefaultFaultSubtype(type: FaultType): FaultSubtype {
    const options = FaultReportService.getFaultSubtypeOptions(type);
    if (options.length === 0) {
      return FaultSubtype.OtherAbnormal;
    }

    return options[0].subtype;
  }

  static formatFaultTypeSelection(type: FaultType, subtype: FaultSubtype): string {
    if (!FaultReportService.isKnownFaultType(type) || !FaultReportService.isKnownFaultSubtype(type, subtype)) {
      return '请选择故障类型';
    }

    return `${FaultReportService.formatFaultType(type)} / ${FaultReportService.formatFaultSubtype(subtype)}`;
  }

  static resolveFaultTypeSelection(typeLabel: string, subtypeLabel: string): FaultTypeSelection | undefined {
    const faultType = FaultReportService.resolveFaultTypeLabel(typeLabel);
    if (faultType === undefined) {
      return undefined;
    }

    const normalizedSubtypeLabel = FaultReportService.normalizeText(subtypeLabel);
    const options = FaultReportService.getFaultSubtypeOptions(faultType);
    for (let index = 0; index < options.length; index++) {
      if (options[index].label === normalizedSubtypeLabel) {
        return {
          faultType,
          faultSubtype: options[index].subtype
        };
      }
    }

    return undefined;
  }

  static formatFaultSubtype(subtype: FaultSubtype): string {
    for (let index = 0; index < FAULT_SUBTYPE_OPTIONS.length; index++) {
      if (FAULT_SUBTYPE_OPTIONS[index].subtype === subtype) {
        return FAULT_SUBTYPE_OPTIONS[index].label;
      }
    }

    return '-';
  }

  static formatFaultLocation(longitude: number | undefined, latitude: number | undefined): string {
    if (!FaultReportService.hasValidLocation(longitude, latitude)) {
      return '未获取';
    }

    return `${latitude?.toFixed(6)}, ${longitude?.toFixed(6)}`;
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

  static formatSeveritySelection(severity: FaultSeverity): string {
    const label = FaultReportService.formatSeverity(severity);
    return label === '-' ? '请选择故障等级' : label;
  }

  static resolveSeveritySelection(label: string): FaultSeverity | undefined {
    switch (FaultReportService.normalizeText(label)) {
      case '紧急':
        return FaultSeverity.Emergency;
      case '严重':
        return FaultSeverity.Severe;
      case '一般':
        return FaultSeverity.General;
      case '轻微':
        return FaultSeverity.Minor;
      default:
        return undefined;
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

  private static resolveFaultTypeLabel(label: string): FaultType | undefined {
    switch (FaultReportService.normalizeText(label)) {
      case '运行故障':
        return FaultType.OperationAbnormal;
      case '部件故障':
        return FaultType.HardwareDamage;
      case '通信故障':
        return FaultType.CommunicationFault;
      case '逻辑故障':
        return FaultType.LogicFault;
      case '能源故障':
        return FaultType.EnergyFault;
      case '外部故障':
        return FaultType.ExternalFactor;
      case '其他故障':
        return FaultType.Other;
      default:
        return undefined;
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

  private static isKnownFaultSubtype(type: FaultType, subtype: FaultSubtype): boolean {
    for (let index = 0; index < FAULT_SUBTYPE_OPTIONS.length; index++) {
      const item = FAULT_SUBTYPE_OPTIONS[index];
      if (item.type === type && item.subtype === subtype) {
        return true;
      }
    }

    return false;
  }

  private static isKnownSeverity(severity: FaultSeverity): boolean {
    return severity === FaultSeverity.Emergency ||
      severity === FaultSeverity.Severe ||
      severity === FaultSeverity.General ||
      severity === FaultSeverity.Minor;
  }

  private static hasValidLocation(longitude: number | undefined, latitude: number | undefined): boolean {
    if (longitude === undefined || latitude === undefined) {
      return false;
    }

    return longitude === longitude && latitude === latitude &&
      longitude >= -180 && longitude <= 180 &&
      latitude >= -90 && latitude <= 90;
  }
}
