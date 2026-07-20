import { AppColors } from '../../shared/theme/AppTheme';
import { ApiClient } from '../../shared/services/ApiClient';
import { ApiResponse } from '../../shared/models/ApiModels';
import {
  DeviceCodeQueryForm,
  DeviceCodeValidationResult,
  ArchiveRequestState,
  DeviceStatus,
  DeviceQrQueryForm,
  DeviceQrValidationResult,
  DeviceSummary,
  DeviceSummaryPayload,
  ArchiveImageSummary,
  ArchiveImageSummaryPayload
} from '../models/DeviceModels';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';

interface QrVerifyApiResult {
  valid: boolean;
  device: DeviceSummaryPayload;
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
        message: UiFeedbackService.requiredInput('设备编号')
      };
    }

    if (!DEVICE_CODE_PATTERN.test(deviceCode)) {
      return {
        valid: false,
        message: UiFeedbackService.incorrect('设备编号')
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
        message: UiFeedbackService.requiredSelection('二维码')
      };
    }

    if (qrContent.length > QR_CONTENT_MAX_LENGTH) {
      return {
        valid: false,
        message: UiFeedbackService.incorrect('二维码')
      };
    }

    if (!DeviceService.isValidQrContentStructure(qrContent)) {
      return {
        valid: false,
        message: UiFeedbackService.incorrect('二维码')
      };
    }

    return {
      valid: true,
      message: ''
    };
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
      return ApiClient.createServiceUnavailableResponse<DeviceSummary>();
    }

    const deviceCode = encodeURIComponent(DeviceService.normalizeDeviceCode(form.deviceCode));
    const response = await ApiClient.request<DeviceSummaryPayload>(`/api/v1/devices/by-code/${deviceCode}`, 'GET',
      true);
    return DeviceService.normalizeDeviceSummaryResponse(response);
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
      return ApiClient.createServiceUnavailableResponse<DeviceSummary>();
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
          message: UiFeedbackService.incorrect('二维码')
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: DeviceService.normalizeDeviceSummary(response.data.device),
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static normalizeDeviceSummary(payload: DeviceSummaryPayload): DeviceSummary {
    const location = payload.location;
    return {
      id: DeviceService.normalizeText(payload.id),
      deviceCode: DeviceService.normalizeText(payload.deviceCode),
      name: DeviceService.normalizeText(payload.name),
      images: DeviceService.normalizeArchiveImages(payload.images),
      deviceType: DeviceService.normalizeText(payload.deviceType),
      model: DeviceService.normalizeText(payload.model),
      manufacturer: DeviceService.normalizeText(payload.manufacturer),
      commissionedAt: DeviceService.normalizeText(payload.commissionedAt),
      managementDepartment: DeviceService.normalizeText(payload.managementDepartment),
      location: {
        address: location === undefined ? '' : DeviceService.normalizeText(location.address),
        longitude: location === undefined ? undefined : location.longitude,
        latitude: location === undefined ? undefined : location.latitude
      },
      status: payload.status === undefined ? DeviceStatus.PendingVerification : payload.status,
      lastVerificationTime: payload.lastVerificationTime,
      archiveRequestState: payload.archiveRequestState
    };
  }

  private static normalizeArchiveImages(images?: ArchiveImageSummaryPayload[]): ArchiveImageSummary[] {
    if (images === undefined) {
      return [];
    }
    return images.map((item: ArchiveImageSummaryPayload): ArchiveImageSummary => ({
      id: DeviceService.normalizeText(item.id),
      sortOrder: item.sortOrder === undefined ? 0 : item.sortOrder,
      width: item.width === undefined ? 0 : item.width,
      height: item.height === undefined ? 0 : item.height,
      thumbnailDataUri: DeviceService.normalizeText(item.thumbnailDataUri)
    }));
  }

  private static normalizeDeviceSummaryResponse(response: ApiResponse<DeviceSummaryPayload>): ApiResponse<DeviceSummary> {
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
          code: 'DEVICE_QUERY_EMPTY',
          message: UiFeedbackService.operationUnavailable('查询')
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: DeviceService.normalizeDeviceSummary(response.data),
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
      case DeviceStatus.ArchiveRequestPendingReview:
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
      case DeviceStatus.ArchiveRequestPendingReview:
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

  static isArchiveRequestLocked(device: DeviceSummary): boolean {
    const archiveRequestState = DeviceService.getArchiveRequestState(device);
    if (archiveRequestState === undefined) {
      return false;
    }

    if (archiveRequestState.locked) {
      return true;
    }

    if (archiveRequestState.freezeUntil === undefined || archiveRequestState.freezeUntil.length === 0) {
      return false;
    }

    const freezeUntil = new Date(archiveRequestState.freezeUntil);
    if (freezeUntil.getTime() !== freezeUntil.getTime()) {
      return false;
    }

    return freezeUntil.getTime() > Date.now();
  }

  static formatArchiveRequestLockReason(device: DeviceSummary): string {
    const archiveRequestState = DeviceService.getArchiveRequestState(device);
    if (archiveRequestState === undefined) {
      return '可提交档案申请';
    }

    if (archiveRequestState.locked) {
      return '存在待审核档案申请，暂不可再次提交';
    }

    if (DeviceService.isArchiveRequestLocked(device) && archiveRequestState.freezeUntil !== undefined) {
      return `档案申请冻结中，${DeviceService.formatTimestampForDisplay(archiveRequestState.freezeUntil)} 后可再次提交`;
    }

    return '可提交档案申请';
  }

  static getArchiveRequestState(device: DeviceSummary): ArchiveRequestState | undefined {
    return device.archiveRequestState;
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

  private static normalizeText(value?: string): string {
    if (value === undefined) {
      return '';
    }

    return value.trim();
  }

  private static pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
