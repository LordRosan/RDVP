import { ApiClient } from './ApiClient';
import { ApiResponse } from '../models/ApiModels';
import { DeviceCodeSearchForm, DeviceCodeValidationResult, DeviceSummary } from '../models/DeviceModels';

export class DeviceService {
  static normalizeDeviceCode(deviceCode: string): string {
    return deviceCode.trim().toUpperCase();
  }

  static validateDeviceCodeSearch(form: DeviceCodeSearchForm): DeviceCodeValidationResult {
    const deviceCode = DeviceService.normalizeDeviceCode(form.deviceCode);
    const pattern = /^[A-Z0-9][A-Z0-9_-]{2,63}$/;

    if (deviceCode.length === 0) {
      return {
        valid: false,
        message: '请输入设备编号'
      };
    }

    if (!pattern.test(deviceCode)) {
      return {
        valid: false,
        message: '设备编号格式无效'
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  static queryByCode(form: DeviceCodeSearchForm): ApiResponse<DeviceSummary> {
    const validation = DeviceService.validateDeviceCodeSearch(form);

    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'DEVICE_CODE_INVALID',
          message: validation.message
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<DeviceSummary>();
    }

    return ApiClient.createServiceUnavailableResponse<DeviceSummary>();
  }
}

