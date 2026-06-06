import { ApiError, ApiErrorCode, ApiResponse } from '../models/ApiModels';
import {
  FaultReportForm,
  FaultReportRecord,
  FaultReportValidationResult,
  FaultSeverity,
  FaultStatus,
  FaultType
} from '../models/FaultModels';
import {
  FaultReportOfflineSyncPayload,
  OfflineSyncOperationType
} from '../models/OfflineSyncModels';
import { OperationRecordType } from '../models/OperationRecordModels';
import { ApiClient } from './ApiClient';
import { DeviceService } from './DeviceService';
import { LocalRepairTaskRepository } from './LocalRepairTaskRepository';
import { LocalOperationRecordRepository } from './LocalOperationRecordRepository';
import { OfflineSyncService } from './OfflineSyncService';
import { SessionStore } from '../stores/SessionStore';

const MAX_DESCRIPTION_LENGTH = 800;
const MAX_SCENE_CONDITION_LENGTH = 500;
const OFFLINE_SYNC_FAULT_REPORT_REQUEST_ID = 'offline-sync-fault-report';

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
      return FaultReportService.createLocalQueuedFaultReportResponse(form);
    }

    return ApiClient.createServiceUnavailableResponse<FaultReportRecord>();
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
      return FaultReportService.createLocalQueuedFaultReportResponse(form);
    }

    const response = await FaultReportService.submitFaultReportToBackend(form);
    if (!response.success &&
      response.error !== undefined &&
      response.error.code === ApiErrorCode.ServiceUnavailable) {
      return FaultReportService.createLocalQueuedFaultReportResponse(form);
    }

    return response;
  }

  static async submitQueuedFaultReport(payloadJson: string): Promise<ApiResponse<FaultReportRecord>> {
    const payload = FaultReportService.parseOfflineSyncPayload(payloadJson);
    if (payload === undefined) {
      return {
        success: false,
        error: {
          code: 'OFFLINE_SYNC_PAYLOAD_INVALID',
          message: '设备报修待同步数据无效'
        },
        timestamp: new Date().toISOString()
      };
    }

    return FaultReportService.submitFaultReportToBackend({
      deviceCode: payload.deviceCode,
      faultType: payload.faultType as FaultType,
      severity: payload.severity as FaultSeverity,
      occurredAt: payload.occurredAt,
      description: payload.description,
      sceneCondition: payload.sceneCondition
    });
  }

  static isOfflineSyncQueuedResponse(response: ApiResponse<FaultReportRecord>): boolean {
    return response.requestId === OFFLINE_SYNC_FAULT_REPORT_REQUEST_ID;
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
          message: '故障报告响应无效'
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

  static createLocalFaultReportResponse(form: FaultReportForm): ApiResponse<FaultReportRecord> {
    const record = LocalRepairTaskRepository.createFaultReport(form);
    if (record === undefined) {
      return {
        success: false,
        error: FaultReportService.createSubmitError('DEVICE_ACTIVE_FAULT_EXISTS', ''),
        requestId: 'local-fault-report-blocked',
        timestamp: new Date().toISOString()
      };
    }

    LocalOperationRecordRepository.append(OperationRecordType.FaultReport, '提交设备报修', record.reportNo,
      `设备 ${record.deviceCode} 进入待接取状态`, SessionStore.getCurrentOperatorName());
    return {
      success: true,
      data: record,
      requestId: 'local-fault-report',
      timestamp: new Date().toISOString()
    };
  }

  private static createLocalQueuedFaultReportResponse(form: FaultReportForm): ApiResponse<FaultReportRecord> {
    const normalizedDeviceCode = DeviceService.normalizeDeviceCode(form.deviceCode);
    const conflictKey = FaultReportService.createOfflineConflictKey(normalizedDeviceCode);
    if (OfflineSyncService.hasActiveConflict(OfflineSyncOperationType.FaultReportCreate, conflictKey)) {
      return {
        success: false,
        error: FaultReportService.createSubmitError('DEVICE_ACTIVE_FAULT_EXISTS', ''),
        requestId: 'offline-sync-fault-report-blocked',
        timestamp: new Date().toISOString()
      };
    }

    const localResponse = FaultReportService.createLocalFaultReportResponse(form);
    if (!localResponse.success || localResponse.data === undefined) {
      return localResponse;
    }

    const payload = FaultReportService.createOfflineSyncPayload(form, localResponse.data.reportNo);
    OfflineSyncService.enqueue(
      OfflineSyncOperationType.FaultReportCreate,
      `设备报修 ${normalizedDeviceCode}`,
      JSON.stringify(payload),
      conflictKey
    );

    return {
      success: true,
      data: localResponse.data,
      requestId: OFFLINE_SYNC_FAULT_REPORT_REQUEST_ID,
      timestamp: new Date().toISOString()
    };
  }

  private static createOfflineSyncPayload(form: FaultReportForm, localReportNo: string): FaultReportOfflineSyncPayload {
    return {
      deviceCode: DeviceService.normalizeDeviceCode(form.deviceCode),
      faultType: form.faultType,
      severity: form.severity,
      occurredAt: FaultReportService.normalizeText(form.occurredAt),
      description: FaultReportService.normalizeText(form.description),
      sceneCondition: FaultReportService.normalizeText(form.sceneCondition),
      localReportNo,
      queuedAt: new Date().toISOString()
    };
  }

  private static parseOfflineSyncPayload(payloadJson: string): FaultReportOfflineSyncPayload | undefined {
    try {
      const payload = JSON.parse(payloadJson) as FaultReportOfflineSyncPayload;
      if (payload.deviceCode.length === 0 ||
        payload.faultType.length === 0 ||
        payload.severity.length === 0 ||
        payload.occurredAt.length === 0 ||
        payload.description.length === 0) {
        return undefined;
      }

      return {
        deviceCode: payload.deviceCode,
        faultType: payload.faultType,
        severity: payload.severity,
        occurredAt: payload.occurredAt,
        description: payload.description,
        sceneCondition: payload.sceneCondition === undefined ? '' : payload.sceneCondition,
        localReportNo: payload.localReportNo === undefined ? '' : payload.localReportNo,
        queuedAt: payload.queuedAt === undefined ? '' : payload.queuedAt
      };
    } catch (err) {
      return undefined;
    }
  }

  static createOfflineConflictKey(deviceCode: string): string {
    return `fault-report:${DeviceService.normalizeDeviceCode(deviceCode)}`;
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
        message: '该设备已有进行中的故障处理流程，请勿重复提交报修信息'
      };
    }

    return {
      code: code.length === 0 ? 'FAULT_REPORT_SUBMIT_FAILED' : code,
      message: fallbackMessage.length === 0 ? '设备报修提交失败' : fallbackMessage
    };
  }
}
