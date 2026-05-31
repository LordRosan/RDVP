import { ApiResponse } from '../models/ApiModels';
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

const MAX_DESCRIPTION_LENGTH = 500;
const MAX_REMARK_LENGTH = 300;

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
      return DeviceVerificationService.createLocalVerificationResponse(form);
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
      return DeviceVerificationService.createLocalVerificationResponse(form);
    }

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
        verifiedAt: new Date().toISOString()
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

  private static createLocalVerificationResponse(form: DeviceVerificationForm): ApiResponse<DeviceVerificationRecord> {
    const submittedAt = new Date().toISOString();
    const deviceCode = DeviceService.normalizeDeviceCode(form.deviceCode);
    const record: DeviceVerificationRecord = {
      id: `DVR-LOCAL-${submittedAt.replace(/[-:.TZ]/g, '').substring(0, 14)}`,
      deviceCode,
      result: form.result,
      description: form.description.trim(),
      remark: form.remark.trim(),
      submittedAt
    };

    LocalOperationRecordRepository.append(OperationRecordType.DeviceVerification, '提交状态核验', deviceCode,
      `核验结果：${DeviceVerificationService.formatVerificationResult(form.result)}`);
    LocalDeviceArchiveRepository.updateLastVerificationTime(deviceCode, submittedAt);
    return {
      success: true,
      data: record,
      requestId: 'local-device-verification',
      timestamp: submittedAt
    };
  }
}
