import { AppColors } from '../styles/AppTheme';
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

interface QrVerifyApiResult {
  valid: boolean;
  device: DeviceSummary;
}

const DEVICE_CODE_PATTERN = /^RDVP-DEVICE-\d{4}$/;
const QR_VERSION_PATTERN = /^\d{1,3}$/;
const QR_NONCE_PATTERN = /^[A-Za-z0-9._-]{1,128}$/;
const QR_SIGNATURE_PATTERN = /^[0-9a-fA-F]{64}$/;
const QR_CONTENT_MAX_LENGTH = 512;
const QR_MAX_VERSION = 999;

export class DeviceService {
  static normalizeDeviceCode(deviceCode: string): string {
    return deviceCode.trim().toUpperCase();
  }

  static validateDeviceCodeQuery(form: DeviceCodeQueryForm): DeviceCodeValidationResult {
    const deviceCode = DeviceService.normalizeDeviceCode(form.deviceCode);

    if (deviceCode.length === 0) {
      return {
        valid: false,
        message: '请输入设备编号'
      };
    }

    if (!DEVICE_CODE_PATTERN.test(deviceCode)) {
      return {
        valid: false,
        message: '设备编号格式应为 RDVP-DEVICE-0001'
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

    if (qrContent.length > QR_CONTENT_MAX_LENGTH) {
      return {
        valid: false,
        message: '二维码内容过长'
      };
    }

    if (!DeviceService.isValidQrContentStructure(qrContent)) {
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

  static async queryByCodeRemoteFirst(form: DeviceCodeQueryForm): Promise<ApiResponse<DeviceSummary>> {
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

    const deviceCode = encodeURIComponent(DeviceService.normalizeDeviceCode(form.deviceCode));
    return ApiClient.request<DeviceSummary>(`/api/v1/devices/by-code/${deviceCode}`, 'GET', true);
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

  static async queryByQrContentRemoteFirst(form: DeviceQrQueryForm): Promise<ApiResponse<DeviceSummary>> {
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

    const response = await ApiClient.request<QrVerifyApiResult>('/api/v1/device-qrcodes/verify', 'POST', true,
      JSON.stringify({
        qrContent: DeviceService.normalizeQrContent(form.qrContent),
        scannedAt: new Date().toISOString()
      }));

    if (!response.success) {
      return {
        success: false,
        error: response.error,
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    if (response.data === undefined || !response.data.valid) {
      return {
        success: false,
        error: {
          code: 'QR_CODE_INVALID',
          message: '二维码校验未通过'
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: response.data.device,
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  private static isValidQrContentStructure(qrContent: string): boolean {
    const segments = qrContent.split(':');
    if (segments.length !== 5 || segments[0] !== 'RDVP') {
      return false;
    }

    const versionText = segments[1].trim();
    if (!QR_VERSION_PATTERN.test(versionText)) {
      return false;
    }

    const version = Number.parseInt(versionText, 10);
    const deviceCode = DeviceService.normalizeDeviceCode(segments[2]);
    const nonce = segments[3].trim();
    const signature = segments[4].trim();

    return version > 0
      && version <= QR_MAX_VERSION
      && DEVICE_CODE_PATTERN.test(deviceCode)
      && QR_NONCE_PATTERN.test(nonce)
      && QR_SIGNATURE_PATTERN.test(signature);
  }

  static formatDeviceStatus(status: DeviceStatus): string {
    switch (status) {
      case DeviceStatus.Normal:
        return '正常';
      case DeviceStatus.PendingVerification:
        return '待核验';
      case DeviceStatus.ChangePendingReview:
        return '正常';
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
      case DeviceStatus.ChangePendingReview:
        return AppColors.Success;
      case DeviceStatus.PendingVerification:
      case DeviceStatus.PendingReinspection:
        return AppColors.Warning;
      case DeviceStatus.Faulted:
      case DeviceStatus.Disabled:
        return AppColors.Danger;
      case DeviceStatus.UnderRepair:
        return AppColors.Primary;
      case DeviceStatus.Retired:
        return AppColors.TextSecondary;
      default:
        return AppColors.TextSecondary;
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
      return `变更冻结中，${DeviceService.formatTimestampForDisplay(changeState.freezeUntil)} 后可再次修改`;
    }

    return '可申请变更';
  }

  static formatTimestampForDisplay(value?: string): string {
    if (value === undefined || value.trim().length === 0) {
      return '-';
    }

    const timestamp = Date.parse(value);
    if (timestamp !== timestamp) {
      return value;
    }

    const date = new Date(timestamp);
    return `${date.getFullYear()}-${DeviceService.pad2(date.getMonth() + 1)}-${DeviceService.pad2(
      date.getDate())} ${DeviceService.pad2(date.getHours())}:${DeviceService.pad2(date.getMinutes())}`;
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

  private static pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
