import { ApiResponse } from '../../shared/models/ApiModels';
import {
  ArchiveCreateRequestForm,
  ArchiveDeleteRequestForm,
  ArchiveRequestRecord,
  ArchiveRequestStatus,
  ArchiveRequestValidationResult
} from '../models/ArchiveRequestModels';
import { ApiClient } from '../../shared/services/ApiClient';
import { DeviceService } from './DeviceService';
import { DateTimeFormatUtil } from '../../shared/utils/DateTimeFormatUtil';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';
import { ArchiveImageSubmissionPayload } from '../models/ArchiveImageModels';
import { ArchiveImageService } from './ArchiveImageService';

interface ArchiveRequestApiResult {
  id: string;
  status: ArchiveRequestStatus;
  createdAt: string;
}

interface ArchiveCreateChangePayload {
  newValue: string;
}

interface ArchiveCreateRequestPayload {
  type: string;
  deviceCode: string;
  reason: string;
  changes: Record<string, ArchiveCreateChangePayload>;
  images: ArchiveImageSubmissionPayload[];
  initiatedAt?: string;
}

interface ArchiveDeleteRequestPayload {
  type: string;
  deviceId: string;
  reason: string;
  initiatedAt?: string;
}

export class ArchiveRequestService {
  static validateCreateRequestForm(form: ArchiveCreateRequestForm): ArchiveRequestValidationResult {
    const deviceCodeValidation = DeviceService.validateDeviceCodeQuery({
      deviceCode: form.deviceCode
    });
    const normalizedDeviceCode = DeviceService.normalizeDeviceCode(form.deviceCode);

    if (!deviceCodeValidation.valid) {
      return {
        valid: false,
        message: deviceCodeValidation.message,
        normalizedDeviceCode
      };
    }

    const deviceName = ArchiveRequestService.normalizeText(form.deviceName);
    const deviceType = ArchiveRequestService.normalizeText(form.deviceType);
    const model = ArchiveRequestService.normalizeText(form.model);
    const manufacturer = ArchiveRequestService.normalizeText(form.manufacturer);
    const commissionedAt = ArchiveRequestService.normalizeText(form.commissionedAt);
    const managementDepartment = ArchiveRequestService.normalizeText(form.managementDepartment);
    const locationAddress = ArchiveRequestService.normalizeText(form.locationAddress);
    const reason = ArchiveRequestService.normalizeText(form.reason);

    if (deviceName.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('设备名称'),
        normalizedDeviceCode
      };
    }

    if (deviceName.length > 80) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('设备名称', 80),
        normalizedDeviceCode
      };
    }

    if (form.images.length > ArchiveImageService.getMaximumImageCount()) {
      return {
        valid: false,
        message: '设备图片最多选择5张',
        normalizedDeviceCode
      };
    }

    if (deviceType.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('设备类型'),
        normalizedDeviceCode
      };
    }

    if (deviceType.length > 80) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('设备类型', 80),
        normalizedDeviceCode
      };
    }

    if (model.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('设备型号'),
        normalizedDeviceCode
      };
    }

    if (model.length > 80) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('设备型号', 80),
        normalizedDeviceCode
      };
    }

    if (manufacturer.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('生产厂商'),
        normalizedDeviceCode
      };
    }

    if (manufacturer.length > 100) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('生产厂商', 100),
        normalizedDeviceCode
      };
    }

    if (commissionedAt.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredSelection('启用日期'),
        normalizedDeviceCode
      };
    }

    if (!ArchiveRequestService.isLocalDateText(commissionedAt)) {
      return {
        valid: false,
        message: UiFeedbackService.incorrect('启用日期'),
        normalizedDeviceCode
      };
    }

    if (managementDepartment.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('管理部门'),
        normalizedDeviceCode
      };
    }

    if (managementDepartment.length > 120) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('管理部门', 120),
        normalizedDeviceCode
      };
    }

    if (locationAddress.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('设备位置'),
        normalizedDeviceCode
      };
    }

    if (locationAddress.length > 200) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('设备位置', 200),
        normalizedDeviceCode
      };
    }

    if (form.initiatedAt === undefined || form.initiatedAt.trim().length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredTime('添加'),
        normalizedDeviceCode
      };
    }

    if (reason.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('添加原因'),
        normalizedDeviceCode
      };
    }

    if (reason.length > 500) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('添加原因', 500),
        normalizedDeviceCode
      };
    }

    return {
      valid: true,
      message: '',
      normalizedDeviceCode,
      fieldCount: ArchiveRequestService.countCreateFields(form)
    };
  }

  static validateDeleteRequestForm(form: ArchiveDeleteRequestForm): ArchiveRequestValidationResult {
    if (form.initiatedAt === undefined || form.initiatedAt.trim().length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredTime('删除'),
        normalizedDeviceCode: form.device.deviceCode
      };
    }

    const reason = ArchiveRequestService.normalizeText(form.reason);
    if (reason.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('删除原因'),
        normalizedDeviceCode: form.device.deviceCode
      };
    }

    if (reason.length > 500) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('删除原因', 500),
        normalizedDeviceCode: form.device.deviceCode
      };
    }

    if (DeviceService.isArchiveRequestLocked(form.device)) {
      return {
        valid: false,
        message: DeviceService.formatArchiveRequestLockReason(form.device),
        normalizedDeviceCode: form.device.deviceCode
      };
    }

    return {
      valid: true,
      message: '',
      normalizedDeviceCode: form.device.deviceCode
    };
  }

  static async submitCreateRequestRemoteFirst(
    form: ArchiveCreateRequestForm
  ): Promise<ApiResponse<ArchiveRequestRecord>> {
    const validation = ArchiveRequestService.validateCreateRequestForm(form);
    if (!validation.valid) {
      return ArchiveRequestService.createInvalidResponse(validation.message);
    }

    const normalizedDeviceCode = validation.normalizedDeviceCode ?
      validation.normalizedDeviceCode : DeviceService.normalizeDeviceCode(form.deviceCode);

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<ArchiveRequestRecord>();
    }

    const response = await ApiClient.request<ArchiveRequestApiResult>('/api/v1/archive-requests', 'POST',
      true, ArchiveRequestService.buildCreateRequestBody(form, normalizedDeviceCode));

    return ArchiveRequestService.mapRequestResponse(response, normalizedDeviceCode, form.deviceName,
      form.images.length, form.deviceType, form.model, form.manufacturer, form.commissionedAt,
      form.managementDepartment, form.locationAddress, form.reason);
  }

  static async submitDeleteRequestRemoteFirst(
    form: ArchiveDeleteRequestForm
  ): Promise<ApiResponse<ArchiveRequestRecord>> {
    const validation = ArchiveRequestService.validateDeleteRequestForm(form);
    if (!validation.valid) {
      return ArchiveRequestService.createInvalidResponse(validation.message);
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<ArchiveRequestRecord>();
    }

    const response = await ApiClient.request<ArchiveRequestApiResult>('/api/v1/archive-requests', 'POST',
      true, ArchiveRequestService.buildDeleteRequestBody(form));

    return ArchiveRequestService.mapRequestResponse(response, form.device.deviceCode, form.device.name,
      form.device.images.length, form.device.deviceType, form.device.model, form.device.manufacturer,
      form.device.commissionedAt, form.device.managementDepartment, form.device.location.address, form.reason);
  }

  static countCreateFields(form: ArchiveCreateRequestForm): number {
    let count = 0;
    if (ArchiveRequestService.normalizeText(form.deviceName).length > 0) {
      count += 1;
    }

    if (form.images.length > 0) {
      count += 1;
    }

    if (ArchiveRequestService.normalizeText(form.deviceType).length > 0) {
      count += 1;
    }

    if (ArchiveRequestService.normalizeText(form.model).length > 0) {
      count += 1;
    }

    if (ArchiveRequestService.normalizeText(form.manufacturer).length > 0) {
      count += 1;
    }

    if (ArchiveRequestService.normalizeText(form.commissionedAt).length > 0) {
      count += 1;
    }

    if (ArchiveRequestService.normalizeText(form.managementDepartment).length > 0) {
      count += 1;
    }

    if (ArchiveRequestService.normalizeText(form.locationAddress).length > 0) {
      count += 1;
    }

    return count;
  }

  private static mapRequestResponse(
    response: ApiResponse<ArchiveRequestApiResult>,
    deviceCode: string,
    deviceName: string,
    imageCount: number,
    deviceType: string,
    model: string,
    manufacturer: string,
    commissionedAt: string,
    managementDepartment: string,
    locationAddress: string,
    reason: string
  ): ApiResponse<ArchiveRequestRecord> {
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
          code: 'ARCHIVE_REQUEST_RESPONSE_INVALID',
          message: UiFeedbackService.operationUnavailable('提交')
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: ArchiveRequestService.createRecord(response.data.id, deviceCode, deviceName, imageCount, deviceType,
        model, manufacturer, commissionedAt, managementDepartment, locationAddress, reason, response.data.createdAt),
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  private static createInvalidResponse(message: string): ApiResponse<ArchiveRequestRecord> {
    return {
      success: false,
      error: {
        code: 'ARCHIVE_REQUEST_INVALID',
        message
      }
    };
  }

  private static createRecord(
    requestId: string,
    deviceCode: string,
    deviceName: string,
    imageCount: number,
    deviceType: string,
    model: string,
    manufacturer: string,
    commissionedAt: string,
    managementDepartment: string,
    locationAddress: string,
    reason: string,
    submittedAt: string,
    status: ArchiveRequestStatus = ArchiveRequestStatus.PendingReview
  ): ArchiveRequestRecord {
    return {
      id: requestId,
      deviceCode,
      deviceName: ArchiveRequestService.normalizeText(deviceName),
      imageCount,
      deviceType: ArchiveRequestService.normalizeText(deviceType),
      model: ArchiveRequestService.normalizeText(model),
      manufacturer: ArchiveRequestService.normalizeText(manufacturer),
      commissionedAt: ArchiveRequestService.normalizeText(commissionedAt),
      managementDepartment: ArchiveRequestService.normalizeText(managementDepartment),
      locationAddress: ArchiveRequestService.normalizeText(locationAddress),
      reason: ArchiveRequestService.normalizeText(reason),
      status,
      submittedAt
    };
  }

  private static buildCreateRequestBody(form: ArchiveCreateRequestForm, normalizedDeviceCode: string): string {
    const payload: ArchiveCreateRequestPayload = {
      type: 'CREATE',
      deviceCode: normalizedDeviceCode,
      reason: ArchiveRequestService.normalizeText(form.reason),
      images: ArchiveImageService.buildSubmissionPayloads(form.images),
      changes: {
        'name': {
          newValue: ArchiveRequestService.normalizeText(form.deviceName)
        },
        'deviceType': {
          newValue: ArchiveRequestService.normalizeText(form.deviceType)
        },
        'model': {
          newValue: ArchiveRequestService.normalizeText(form.model)
        },
        'manufacturer': {
          newValue: ArchiveRequestService.normalizeText(form.manufacturer)
        },
        'commissionedAt': {
          newValue: ArchiveRequestService.normalizeText(form.commissionedAt)
        },
        'managementDepartment': {
          newValue: ArchiveRequestService.normalizeText(form.managementDepartment)
        },
        'location.address': {
          newValue: ArchiveRequestService.normalizeText(form.locationAddress)
        }
      }
    };

    if (form.initiatedAt !== undefined && form.initiatedAt.trim().length > 0) {
      payload.initiatedAt = DateTimeFormatUtil.toApiIsoString(form.initiatedAt);
    }

    return JSON.stringify(payload);
  }

  private static buildDeleteRequestBody(form: ArchiveDeleteRequestForm): string {
    const payload: ArchiveDeleteRequestPayload = {
      type: 'DELETE',
      deviceId: form.device.id,
      reason: ArchiveRequestService.normalizeText(form.reason)
    };

    if (form.initiatedAt !== undefined && form.initiatedAt.trim().length > 0) {
      payload.initiatedAt = DateTimeFormatUtil.toApiIsoString(form.initiatedAt);
    }

    return JSON.stringify(payload);
  }

  private static normalizeText(value: string): string {
    return value.trim();
  }

  private static isLocalDateText(value: string): boolean {
    const parts = value.split('-');
    if (parts.length !== 3 || parts[0].length !== 4 || parts[1].length !== 2 || parts[2].length !== 2) {
      return false;
    }

    const year = Number(parts[0]);
    const month = Number(parts[1]);
    const day = Number(parts[2]);
    if (year !== year || month !== month || day !== day) {
      return false;
    }

    const date = new Date(year, month - 1, day);
    return date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day;
  }
}
