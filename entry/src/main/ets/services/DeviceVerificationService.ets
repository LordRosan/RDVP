import { ApiErrorCode, ApiResponse } from '../models/ApiModels';
import {
  DeviceVerificationOfflineSyncPayload,
  OfflineSyncOperationType
} from '../models/OfflineSyncModels';
import { OperationRecordType } from '../models/OperationRecordModels';
import {
  DeviceVerificationForm,
  DeviceVerificationRecord,
  DeviceVerificationValidationResult,
  VerificationResult
} from '../models/VerificationModels';
import { ApiClient } from './ApiClient';
import { DeviceService } from './DeviceService';
import { LocalDeviceArchiveRepository } from './LocalDeviceArchiveRepository';
import { LocalOperationRecordRepository } from './LocalOperationRecordRepository';
import { OfflineSyncService } from './OfflineSyncService';
import { SessionStore } from '../stores/SessionStore';

const MAX_DESCRIPTION_LENGTH = 500;
const MAX_REMARK_LENGTH = 300;
const OFFLINE_SYNC_DEVICE_VERIFICATION_REQUEST_ID = 'offline-sync-device-verification';

interface DeviceVerificationApiResult {
  id: string;
  result: string;
  description: string;
  remark?: string;
  verifiedAt: string;
  createdAt: string;
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

  static async submitQueuedVerification(payloadJson: string): Promise<ApiResponse<DeviceVerificationRecord>> {
    const payload = DeviceVerificationService.parseOfflineSyncPayload(payloadJson);
    if (payload === undefined) {
      return {
        success: false,
        error: {
          code: 'OFFLINE_SYNC_PAYLOAD_INVALID',
          message: '状态核验待同步数据无效'
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

  static isOfflineSyncQueuedResponse(response: ApiResponse<DeviceVerificationRecord>): boolean {
    return response.requestId === OFFLINE_SYNC_DEVICE_VERIFICATION_REQUEST_ID;
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

    LocalOperationRecordRepository.append(OperationRecordType.DeviceVerification, '提交状态核验', deviceCode,
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
      `状态核验 ${DeviceService.normalizeDeviceCode(form.deviceCode)}`,
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
}
