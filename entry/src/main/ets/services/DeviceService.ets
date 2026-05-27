import { ApiClient } from './ApiClient';
import { ApiResponse } from '../models/ApiModels';
import {
  DeviceCodeQueryForm,
  DeviceCodeValidationResult,
  DeviceQrQueryForm,
  DeviceQrValidationResult,
  DeviceSummary
} from '../models/DeviceModels';

export class DeviceService {
  static normalizeDeviceCode(deviceCode: string): string {
    return deviceCode.trim().toUpperCase();
  }

  static validateDeviceCodeQuery(form: DeviceCodeQueryForm): DeviceCodeValidationResult {
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

  static normalizeQrContent(qrContent: string): string {
    return qrContent.trim();
  }

  static validateQrQuery(form: DeviceQrQueryForm): DeviceQrValidationResult {
    const qrContent = DeviceService.normalizeQrContent(form.qrContent);

    if (qrContent.length === 0) {
      return {
        valid: false,
        message: '请先扫描或上传二维码'
      };
    }

    if (qrContent.length > 1024) {
      return {
        valid: false,
        message: '二维码内容过长'
      };
    }

    if (!qrContent.startsWith('RDVP:')) {
      return {
        valid: false,
        message: '二维码内容无效'
      };
    }

    return {
      valid: true,
      message: ''
    };
  }

  static queryByCode(form: DeviceCodeQueryForm): ApiResponse<DeviceSummary> {
    const validation = DeviceService.validateDeviceCodeQuery(form);

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

  static queryByQrContent(form: DeviceQrQueryForm): ApiResponse<DeviceSummary> {
    const validation = DeviceService.validateQrQuery(form);

    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'QR_CODE_INVALID',
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
