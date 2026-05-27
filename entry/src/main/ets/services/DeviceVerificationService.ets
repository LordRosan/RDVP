import { ApiErrorCode, ApiResponse } from '../models/ApiModels';
import {
  DeviceVerificationForm,
  DeviceVerificationRecord,
  DeviceVerificationValidationResult,
  VerificationResult
} from '../models/VerificationModels';
import { ApiClient } from './ApiClient';
import { DeviceService } from './DeviceService';

const MAX_DESCRIPTION_LENGTH = 500;
const MAX_REMARK_LENGTH = 300;

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
      return {
        success: false,
        error: {
          code: ApiErrorCode.ServiceUnavailable,
          message: '后端服务未配置，暂不能提交'
        }
      };
    }

    return ApiClient.createServiceUnavailableResponse<DeviceVerificationRecord>();
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
}
