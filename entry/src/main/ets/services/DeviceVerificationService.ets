import { ApiErrorCode, ApiResponse } from '../models/ApiModels';
import {
  DeviceVerificationFaultReportOfflineSyncPayload,
  DeviceVerificationOfflineSyncPayload,
  OfflineSyncOperationType
} from '../models/OfflineSyncModels';
import { OperationRecordType } from '../models/OperationRecordModels';
import {
  DeviceVerificationForm,
  DeviceVerificationFaultReportForm,
  DeviceVerificationFaultReportRecord,
  DeviceVerificationRecord,
  DeviceVerificationValidationResult,
  VerificationResult
} from '../models/VerificationModels';
import { ApiClient } from './ApiClient';
import { DeviceService } from './DeviceService';
import { FaultReportService } from './FaultReportService';
import { LocalDeviceArchiveRepository } from './LocalDeviceArchiveRepository';
import { LocalOperationRecordRepository } from './LocalOperationRecordRepository';
import { LocalRepairTaskRepository } from './LocalRepairTaskRepository';
import { OfflineSyncService } from './OfflineSyncService';
import { SessionStore } from '../stores/SessionStore';

const MAX_DESCRIPTION_LENGTH = 500;
const MAX_REMARK_LENGTH = 300;
const OFFLINE_SYNC_DEVICE_VERIFICATION_REQUEST_ID = 'offline-sync-device-verification';
const OFFLINE_SYNC_DEVICE_VERIFICATION_FAULT_REPORT_REQUEST_ID = 'offline-sync-device-verification-fault-report';

interface DeviceVerificationApiResult {
  id: string;
  result: string;
  description: string;
  remark?: string;
  verifiedAt: string;
  createdAt: string;
}

interface FaultReportApiResult {
  id: string;
  faultReportNo: string;
  status: string;
  createdAt: string;
}

interface DeviceVerificationFaultReportApiResult {
  verificationRecord: DeviceVerificationApiResult;
  faultReport: FaultReportApiResult;
}

export class DeviceVerificationService {
  static normalizeText(value: string): string {
    return value.trim();
  }

  static validateVerificationForm(form: DeviceVerificationForm): DeviceVerificationValidationResult {
    const deviceCodeValidation = DeviceService.validateDeviceCodeQuery({
      deviceCode: form.deviceCode
    });

    if (!deviceCodeValidation.valid) {
      return {
        valid: false,
        message: deviceCodeValidation.message
      };
    }

    if (!DeviceVerificationService.isKnownResult(form.result)) {
      return {
        valid: false,
        message: '请选择核验结果'
      };
    }

    const description = DeviceVerificationService.normalizeText(form.description);
    if (description.length === 0) {
      return {
        valid: false,
        message: '请输入现场描述'
      };
    }

    if (description.length > MAX_DESCRIPTION_LENGTH) {
      return {
        valid: false,
        message: '现场描述不能超过500字'
      };
    }

    const remark = DeviceVerificationService.normalizeText(form.remark);
    if (remark.length > MAX_REMARK_LENGTH) {
      return {
        valid: false,
        message: '备注不能超过300字'
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  static validateVerificationFaultReportForm(form: DeviceVerificationFaultReportForm): DeviceVerificationValidationResult {
    const verificationValidation = DeviceVerificationService.validateVerificationForm(form.verification);
    if (!verificationValidation.valid) {
      return verificationValidation;
    }

    if (form.verification.result === VerificationResult.Normal) {
      return {
        valid: false,
        message: '正常核验不需要提交报修信息'
      };
    }

    const faultReportValidation = FaultReportService.validateFaultReportForm(form.faultReport);
    if (!faultReportValidation.valid) {
      return {
        valid: false,
        message: faultReportValidation.message
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  static submitVerification(form: DeviceVerificationForm): ApiResponse<DeviceVerificationRecord> {
    const validation = DeviceVerificationService.validateVerificationForm(form);
    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'DEVICE_VERIFICATION_INVALID',
          message: validation.message
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return DeviceVerificationService.createLocalQueuedVerificationResponse(form);
    }

    return ApiClient.createServiceUnavailableResponse<DeviceVerificationRecord>();
  }

  static async submitVerificationRemoteFirst(form: DeviceVerificationForm): Promise<ApiResponse<DeviceVerificationRecord>> {
    const validation = DeviceVerificationService.validateVerificationForm(form);
    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'DEVICE_VERIFICATION_INVALID',
          message: validation.message
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return DeviceVerificationService.createLocalQueuedVerificationResponse(form);
    }

    const verifiedAt = new Date().toISOString();
    const response = await DeviceVerificationService.submitVerificationToBackend(form, verifiedAt);
    if (!response.success &&
      response.error !== undefined &&
      response.error.code === ApiErrorCode.ServiceUnavailable) {
      return DeviceVerificationService.createLocalQueuedVerificationResponse(form, verifiedAt);
    }

    return response;
  }

  static async submitVerificationWithFaultReportRemoteFirst(
    form: DeviceVerificationFaultReportForm
  ): Promise<ApiResponse<DeviceVerificationFaultReportRecord>> {
    const validation = DeviceVerificationService.validateVerificationFaultReportForm(form);
    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'DEVICE_VERIFICATION_FAULT_REPORT_INVALID',
          message: validation.message
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return DeviceVerificationService.createLocalQueuedVerificationFaultReportResponse(form);
    }

    const verifiedAt = new Date().toISOString();
    const response = await DeviceVerificationService.submitVerificationFaultReportToBackend(form, verifiedAt);
    if (!response.success &&
      response.error !== undefined &&
      response.error.code === ApiErrorCode.ServiceUnavailable) {
      return DeviceVerificationService.createLocalQueuedVerificationFaultReportResponse(form, verifiedAt);
    }

    return response;
  }

  static async submitQueuedVerification(payloadJson: string): Promise<ApiResponse<DeviceVerificationRecord>> {
    const payload = DeviceVerificationService.parseOfflineSyncPayload(payloadJson);
    if (payload === undefined) {
      return {
        success: false,
        error: {
          code: 'OFFLINE_SYNC_PAYLOAD_INVALID',
          message: '设备核验待同步数据无效'
        },
        timestamp: new Date().toISOString()
      };
    }

    return DeviceVerificationService.submitVerificationToBackend({
      deviceCode: payload.deviceCode,
      result: payload.result as VerificationResult,
      description: payload.description,
      remark: payload.remark
    }, payload.verifiedAt);
  }

  static async submitQueuedVerificationFaultReport(
    payloadJson: string
  ): Promise<ApiResponse<DeviceVerificationFaultReportRecord>> {
    const payload = DeviceVerificationService.parseFaultReportOfflineSyncPayload(payloadJson);
    if (payload === undefined) {
      return {
        success: false,
        error: {
          code: 'OFFLINE_SYNC_PAYLOAD_INVALID',
          message: '设备核验与报修待同步数据无效'
        },
        timestamp: new Date().toISOString()
      };
    }

    return DeviceVerificationService.submitVerificationFaultReportToBackend({
      verification: {
        deviceCode: payload.deviceCode,
        result: payload.result as VerificationResult,
        description: payload.description,
        remark: payload.remark
      },
      faultReport: {
        deviceCode: payload.deviceCode,
        faultType: payload.faultType,
        severity: payload.severity,
        occurredAt: payload.occurredAt,
        description: payload.faultDescription,
        sceneCondition: payload.sceneCondition
      }
    } as DeviceVerificationFaultReportForm, payload.verifiedAt);
  }

  static isOfflineSyncQueuedResponse(response: ApiResponse<DeviceVerificationRecord>): boolean {
    return response.requestId === OFFLINE_SYNC_DEVICE_VERIFICATION_REQUEST_ID;
  }

  static isOfflineSyncQueuedFaultReportResponse(response: ApiResponse<DeviceVerificationFaultReportRecord>): boolean {
    return response.requestId === OFFLINE_SYNC_DEVICE_VERIFICATION_FAULT_REPORT_REQUEST_ID;
  }

  private static async submitVerificationToBackend(
    form: DeviceVerificationForm,
    verifiedAt: string
  ): Promise<ApiResponse<DeviceVerificationRecord>> {
    const deviceResponse = await DeviceService.queryByCodeRemoteFirst({
      deviceCode: form.deviceCode
    });
    if (!deviceResponse.success || deviceResponse.data === undefined) {
      return {
        success: false,
        error: deviceResponse.error,
        requestId: deviceResponse.requestId,
        timestamp: deviceResponse.timestamp
      };
    }

    const response = await ApiClient.request<DeviceVerificationApiResult>(
      `/api/v1/devices/${encodeURIComponent(deviceResponse.data.id)}/verification-records`,
      'POST',
      true,
      JSON.stringify({
        result: form.result,
        description: DeviceVerificationService.normalizeText(form.description),
        remark: DeviceVerificationService.normalizeText(form.remark),
        verifiedAt
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
          code: 'DEVICE_VERIFICATION_RESPONSE_INVALID',
          message: '核验记录响应无效'
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: {
        id: response.data.id,
        deviceCode: DeviceService.normalizeDeviceCode(form.deviceCode),
        result: response.data.result as VerificationResult,
        description: response.data.description,
        remark: response.data.remark,
        submittedAt: response.data.createdAt
      },
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  private static async submitVerificationFaultReportToBackend(
    form: DeviceVerificationFaultReportForm,
    verifiedAt: string
  ): Promise<ApiResponse<DeviceVerificationFaultReportRecord>> {
    const deviceResponse = await DeviceService.queryByCodeRemoteFirst({
      deviceCode: form.verification.deviceCode
    });
    if (!deviceResponse.success || deviceResponse.data === undefined) {
      return {
        success: false,
        error: deviceResponse.error,
        requestId: deviceResponse.requestId,
        timestamp: deviceResponse.timestamp
      };
    }

    const response = await ApiClient.request<DeviceVerificationFaultReportApiResult>(
      `/api/v1/devices/${encodeURIComponent(deviceResponse.data.id)}/verification-records/fault-report`,
      'POST',
      true,
      JSON.stringify({
        result: form.verification.result,
        description: DeviceVerificationService.normalizeText(form.verification.description),
        remark: DeviceVerificationService.normalizeText(form.verification.remark),
        verifiedAt,
        faultType: form.faultReport.faultType,
        severity: form.faultReport.severity,
        occurredAt: FaultReportService.normalizeText(form.faultReport.occurredAt),
        faultDescription: FaultReportService.normalizeText(form.faultReport.description),
        sceneCondition: FaultReportService.normalizeText(form.faultReport.sceneCondition)
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
          code: 'DEVICE_VERIFICATION_FAULT_REPORT_RESPONSE_INVALID',
          message: '设备核验与报修响应无效'
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: {
        verificationRecord: {
          id: response.data.verificationRecord.id,
          deviceCode: DeviceService.normalizeDeviceCode(form.verification.deviceCode),
          result: response.data.verificationRecord.result as VerificationResult,
          description: response.data.verificationRecord.description,
          remark: response.data.verificationRecord.remark,
          submittedAt: response.data.verificationRecord.createdAt
        },
        faultReport: {
          id: response.data.faultReport.id,
          reportNo: response.data.faultReport.faultReportNo,
          deviceCode: DeviceService.normalizeDeviceCode(form.faultReport.deviceCode),
          faultType: form.faultReport.faultType,
          severity: form.faultReport.severity,
          status: response.data.faultReport.status,
          submittedAt: response.data.faultReport.createdAt
        }
      },
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static formatVerificationResult(result: VerificationResult): string {
    switch (result) {
      case VerificationResult.Normal:
        return '正常';
      case VerificationResult.Abnormal:
        return '异常';
      case VerificationResult.Unavailable:
        return '不可用';
      default:
        return '-';
    }
  }

  private static isKnownResult(result: VerificationResult): boolean {
    return result === VerificationResult.Normal ||
      result === VerificationResult.Abnormal ||
      result === VerificationResult.Unavailable;
  }

  private static createLocalVerificationResponse(
    form: DeviceVerificationForm,
    submittedAt?: string
  ): ApiResponse<DeviceVerificationRecord> {
    const normalizedSubmittedAt = submittedAt === undefined || submittedAt.length === 0 ? new Date().toISOString() : submittedAt;
    const deviceCode = DeviceService.normalizeDeviceCode(form.deviceCode);
    const record: DeviceVerificationRecord = {
      id: `DVR-LOCAL-${normalizedSubmittedAt.replace(/[-:.TZ]/g, '').substring(0, 14)}-${Math.floor(Math.random() * 1000000)}`,
      deviceCode,
      result: form.result,
      description: form.description.trim(),
      remark: form.remark.trim(),
      submittedAt: normalizedSubmittedAt
    };

    LocalOperationRecordRepository.append(OperationRecordType.DeviceVerification, '提交设备核验', deviceCode,
      `核验结果：${DeviceVerificationService.formatVerificationResult(form.result)}`,
      SessionStore.getCurrentOperatorName());
    LocalDeviceArchiveRepository.updateLastVerificationTime(deviceCode, normalizedSubmittedAt);
    return {
      success: true,
      data: record,
      requestId: 'local-device-verification',
      timestamp: normalizedSubmittedAt
    };
  }

  private static createLocalQueuedVerificationResponse(
    form: DeviceVerificationForm,
    verifiedAt?: string
  ): ApiResponse<DeviceVerificationRecord> {
    const normalizedVerifiedAt = verifiedAt === undefined || verifiedAt.length === 0 ? new Date().toISOString() : verifiedAt;
    const localResponse = DeviceVerificationService.createLocalVerificationResponse(form, normalizedVerifiedAt);
    if (!localResponse.success || localResponse.data === undefined) {
      return localResponse;
    }

    const payload = DeviceVerificationService.createOfflineSyncPayload(
      form,
      localResponse.data.id,
      normalizedVerifiedAt);
    OfflineSyncService.enqueue(
      OfflineSyncOperationType.DeviceVerificationCreate,
      `设备核验 ${DeviceService.normalizeDeviceCode(form.deviceCode)}`,
      JSON.stringify(payload)
    );

    return {
      success: true,
      data: localResponse.data,
      requestId: OFFLINE_SYNC_DEVICE_VERIFICATION_REQUEST_ID,
      timestamp: new Date().toISOString()
    };
  }

  private static createOfflineSyncPayload(
    form: DeviceVerificationForm,
    localRecordId: string,
    verifiedAt: string
  ): DeviceVerificationOfflineSyncPayload {
    return {
      deviceCode: DeviceService.normalizeDeviceCode(form.deviceCode),
      result: form.result,
      description: DeviceVerificationService.normalizeText(form.description),
      remark: DeviceVerificationService.normalizeText(form.remark),
      verifiedAt,
      localRecordId,
      queuedAt: new Date().toISOString()
    };
  }

  private static parseOfflineSyncPayload(payloadJson: string): DeviceVerificationOfflineSyncPayload | undefined {
    try {
      const payload = JSON.parse(payloadJson) as DeviceVerificationOfflineSyncPayload;
      if (payload.deviceCode.length === 0 ||
        payload.result.length === 0 ||
        payload.description.length === 0 ||
        payload.verifiedAt.length === 0) {
        return undefined;
      }

      return {
        deviceCode: payload.deviceCode,
        result: payload.result,
        description: payload.description,
        remark: payload.remark === undefined ? '' : payload.remark,
        verifiedAt: payload.verifiedAt,
        localRecordId: payload.localRecordId === undefined ? '' : payload.localRecordId,
        queuedAt: payload.queuedAt === undefined ? '' : payload.queuedAt
      };
    } catch (err) {
      return undefined;
    }
  }

  private static createLocalQueuedVerificationFaultReportResponse(
    form: DeviceVerificationFaultReportForm,
    verifiedAt?: string
  ): ApiResponse<DeviceVerificationFaultReportRecord> {
    const normalizedDeviceCode = DeviceService.normalizeDeviceCode(form.verification.deviceCode);
    const conflictKey = FaultReportService.createOfflineConflictKey(normalizedDeviceCode);
    if (LocalRepairTaskRepository.hasActiveFaultForDevice(normalizedDeviceCode) ||
      OfflineSyncService.hasActiveConflict(OfflineSyncOperationType.FaultReportCreate, conflictKey) ||
      OfflineSyncService.hasActiveConflict(OfflineSyncOperationType.DeviceVerificationFaultReportCreate, conflictKey)) {
      return {
        success: false,
        error: {
          code: 'DEVICE_ACTIVE_FAULT_EXISTS',
          message: '该设备已有进行中的故障处理流程，请勿重复提交报修信息'
        },
        requestId: 'offline-sync-device-verification-fault-report-blocked',
        timestamp: new Date().toISOString()
      };
    }

    const normalizedVerifiedAt = verifiedAt === undefined || verifiedAt.length === 0 ? new Date().toISOString() : verifiedAt;
    const verificationResponse = DeviceVerificationService.createLocalVerificationResponse(
      form.verification,
      normalizedVerifiedAt);
    if (!verificationResponse.success || verificationResponse.data === undefined) {
      return {
        success: false,
        error: verificationResponse.error,
        requestId: verificationResponse.requestId,
        timestamp: verificationResponse.timestamp
      };
    }

    const faultReportResponse = FaultReportService.createLocalFaultReportResponse(form.faultReport);
    if (!faultReportResponse.success || faultReportResponse.data === undefined) {
      return {
        success: false,
        error: faultReportResponse.error,
        requestId: faultReportResponse.requestId,
        timestamp: faultReportResponse.timestamp
      };
    }

    const payload = DeviceVerificationService.createFaultReportOfflineSyncPayload(
      form,
      verificationResponse.data.id,
      faultReportResponse.data.reportNo,
      normalizedVerifiedAt);
    OfflineSyncService.enqueue(
      OfflineSyncOperationType.DeviceVerificationFaultReportCreate,
      `设备核验 ${normalizedDeviceCode}`,
      JSON.stringify(payload),
      conflictKey
    );

    return {
      success: true,
      data: {
        verificationRecord: verificationResponse.data,
        faultReport: faultReportResponse.data
      },
      requestId: OFFLINE_SYNC_DEVICE_VERIFICATION_FAULT_REPORT_REQUEST_ID,
      timestamp: new Date().toISOString()
    };
  }

  private static createFaultReportOfflineSyncPayload(
    form: DeviceVerificationFaultReportForm,
    localRecordId: string,
    localReportNo: string,
    verifiedAt: string
  ): DeviceVerificationFaultReportOfflineSyncPayload {
    return {
      deviceCode: DeviceService.normalizeDeviceCode(form.verification.deviceCode),
      result: form.verification.result,
      description: DeviceVerificationService.normalizeText(form.verification.description),
      remark: DeviceVerificationService.normalizeText(form.verification.remark),
      verifiedAt,
      faultType: form.faultReport.faultType,
      severity: form.faultReport.severity,
      occurredAt: FaultReportService.normalizeText(form.faultReport.occurredAt),
      faultDescription: FaultReportService.normalizeText(form.faultReport.description),
      sceneCondition: FaultReportService.normalizeText(form.faultReport.sceneCondition),
      localRecordId,
      localReportNo,
      queuedAt: new Date().toISOString()
    };
  }

  private static parseFaultReportOfflineSyncPayload(
    payloadJson: string
  ): DeviceVerificationFaultReportOfflineSyncPayload | undefined {
    try {
      const payload = JSON.parse(payloadJson) as DeviceVerificationFaultReportOfflineSyncPayload;
      if (payload.deviceCode.length === 0 ||
        payload.result.length === 0 ||
        payload.description.length === 0 ||
        payload.verifiedAt.length === 0 ||
        payload.faultType.length === 0 ||
        payload.severity.length === 0 ||
        payload.occurredAt.length === 0 ||
        payload.faultDescription.length === 0) {
        return undefined;
      }

      return {
        deviceCode: payload.deviceCode,
        result: payload.result,
        description: payload.description,
        remark: payload.remark === undefined ? '' : payload.remark,
        verifiedAt: payload.verifiedAt,
        faultType: payload.faultType,
        severity: payload.severity,
        occurredAt: payload.occurredAt,
        faultDescription: payload.faultDescription,
        sceneCondition: payload.sceneCondition === undefined ? '' : payload.sceneCondition,
        localRecordId: payload.localRecordId === undefined ? '' : payload.localRecordId,
        localReportNo: payload.localReportNo === undefined ? '' : payload.localReportNo,
        queuedAt: payload.queuedAt === undefined ? '' : payload.queuedAt
      };
    } catch (err) {
      return undefined;
    }
  }
}
