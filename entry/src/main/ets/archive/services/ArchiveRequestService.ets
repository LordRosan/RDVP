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
    const model = ArchiveRequestService.normalizeText(form.model);
    const manufacturer = ArchiveRequestService.normalizeText(form.manufacturer);
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
      form.model, form.manufacturer, form.locationAddress, form.reason);
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
      form.device.model, form.device.manufacturer, form.device.location.address, form.reason);
  }

  static countCreateFields(form: ArchiveCreateRequestForm): number {
    let count = 0;
    if (ArchiveRequestService.normalizeText(form.deviceName).length > 0) {
      count += 1;
    }

    if (ArchiveRequestService.normalizeText(form.model).length > 0) {
      count += 1;
    }

    if (ArchiveRequestService.normalizeText(form.manufacturer).length > 0) {
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
    model: string,
    manufacturer: string,
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
      data: ArchiveRequestService.createRecord(response.data.id, deviceCode, deviceName, model, manufacturer,
        locationAddress, reason, response.data.createdAt),
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
    model: string,
    manufacturer: string,
    locationAddress: string,
    reason: string,
    submittedAt: string,
    status: ArchiveRequestStatus = ArchiveRequestStatus.PendingReview
  ): ArchiveRequestRecord {
    return {
      id: requestId,
      deviceCode,
      deviceName: ArchiveRequestService.normalizeText(deviceName),
      model: ArchiveRequestService.normalizeText(model),
      manufacturer: ArchiveRequestService.normalizeText(manufacturer),
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
      changes: {
        'name': {
          newValue: ArchiveRequestService.normalizeText(form.deviceName)
        },
        'model': {
          newValue: ArchiveRequestService.normalizeText(form.model)
        },
        'manufacturer': {
          newValue: ArchiveRequestService.normalizeText(form.manufacturer)
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
}
