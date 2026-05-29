import { ApiClient } from './ApiClient';
import { ApiErrorCode, ApiResponse } from '../models/ApiModels';
import {
  DeviceCodeQueryForm,
  DeviceCodeValidationResult,
  DeviceStatus,
  DeviceQrQueryForm,
  DeviceQrValidationResult,
  DeviceSummary
} from '../models/DeviceModels';
import { LocalDeviceArchiveRepository } from './LocalDeviceArchiveRepository';

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
      return DeviceService.queryLocalArchiveByCode(form.deviceCode);
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
      return DeviceService.queryLocalArchiveByQrContent(form.qrContent);
    }

    return ApiClient.createServiceUnavailableResponse<DeviceSummary>();
  }

  static formatDeviceStatus(status: DeviceStatus): string {
    switch (status) {
      case DeviceStatus.Normal:
        return '正常';
      case DeviceStatus.PendingVerification:
        return '待核验';
      case DeviceStatus.ChangePendingReview:
        return '变更待审核';
      case DeviceStatus.Faulted:
        return '故障中';
      case DeviceStatus.UnderRepair:
        return '维修中';
      case DeviceStatus.PendingReinspection:
        return '待复检';
      case DeviceStatus.Disabled:
        return '停用';
      case DeviceStatus.Retired:
        return '已退役';
      default:
        return '-';
    }
  }

  static getDeviceStatusTone(status: DeviceStatus): string {
    switch (status) {
      case DeviceStatus.Normal:
        return '#087F5B';
      case DeviceStatus.PendingVerification:
      case DeviceStatus.ChangePendingReview:
      case DeviceStatus.PendingReinspection:
        return '#E67700';
      case DeviceStatus.Faulted:
      case DeviceStatus.Disabled:
        return '#D9480F';
      case DeviceStatus.UnderRepair:
        return '#2F6FED';
      case DeviceStatus.Retired:
        return '#6B7280';
      default:
        return '#374151';
    }
  }

  static isArchiveChangeLocked(device: DeviceSummary): boolean {
    const changeState = device.changeState;
    if (changeState === undefined) {
      return false;
    }

    if (changeState.locked) {
      return true;
    }

    if (changeState.freezeUntil === undefined || changeState.freezeUntil.length === 0) {
      return false;
    }

    const freezeUntil = new Date(changeState.freezeUntil);
    if (freezeUntil.getTime() !== freezeUntil.getTime()) {
      return false;
    }

    return freezeUntil.getTime() > Date.now();
  }

  static formatArchiveChangeLockReason(device: DeviceSummary): string {
    const changeState = device.changeState;
    if (changeState === undefined) {
      return '可申请变更';
    }

    if (changeState.locked) {
      return '存在待审核变更，暂不可再次修改';
    }

    if (DeviceService.isArchiveChangeLocked(device) && changeState.freezeUntil !== undefined) {
      return `变更冻结中，${changeState.freezeUntil} 后可再次修改`;
    }

    return '可申请变更';
  }

  private static queryLocalArchiveByCode(deviceCode: string): ApiResponse<DeviceSummary> {
    const device = LocalDeviceArchiveRepository.findByCode(deviceCode);
    if (device === undefined) {
      return {
        success: false,
        error: {
          code: ApiErrorCode.NotFound,
          message: '未找到设备档案'
        }
      };
    }

    return DeviceService.createLocalArchiveResponse(device);
  }

  private static queryLocalArchiveByQrContent(qrContent: string): ApiResponse<DeviceSummary> {
    const device = LocalDeviceArchiveRepository.findByQrContent(qrContent);
    if (device === undefined) {
      return {
        success: false,
        error: {
          code: 'QR_DEVICE_NOT_FOUND',
          message: '二维码未关联设备档案'
        }
      };
    }

    return DeviceService.createLocalArchiveResponse(device);
  }

  private static createLocalArchiveResponse(device: DeviceSummary): ApiResponse<DeviceSummary> {
    return {
      success: true,
      data: device,
      requestId: 'local-device-archive',
      timestamp: new Date().toISOString()
    };
  }
}
