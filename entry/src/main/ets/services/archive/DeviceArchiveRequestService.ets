import { ApiResponse } from '../../models/common/ApiModels';
import {
  DeviceArchiveCreateRequestForm,
  DeviceArchiveDeleteRequestForm,
  DeviceArchiveRequestRecord,
  DeviceArchiveRequestStatus,
  DeviceArchiveRequestValidationResult
} from '../../models/archive/DeviceArchiveRequestModels';
import { ApiClient } from '../common/ApiClient';
import { DeviceService } from './DeviceService';
import { DateTimeFormatUtil } from '../../utils/DateTimeFormatUtil';
import { UiFeedbackService } from '../common/UiFeedbackService';

interface DeviceArchiveRequestApiResult {
  id: string;
  status: DeviceArchiveRequestStatus;
  createdAt: string;
}

interface DeviceArchiveCreateChangePayload {
  newValue: string;
}

interface DeviceArchiveCreateRequestPayload {
  type: string;
  deviceCode: string;
  reason: string;
  changes: Record<string, DeviceArchiveCreateChangePayload>;
  initiatedAt?: string;
}

interface DeviceArchiveDeleteRequestPayload {
  type: string;
  deviceId: string;
  reason: string;
  initiatedAt?: string;
}

export class DeviceArchiveRequestService {
  static validateCreateRequestForm(form: DeviceArchiveCreateRequestForm): DeviceArchiveRequestValidationResult {
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

    const deviceName = DeviceArchiveRequestService.normalizeText(form.deviceName);
    const model = DeviceArchiveRequestService.normalizeText(form.model);
    const manufacturer = DeviceArchiveRequestService.normalizeText(form.manufacturer);
    const locationAddress = DeviceArchiveRequestService.normalizeText(form.locationAddress);
    const reason = DeviceArchiveRequestService.normalizeText(form.reason);

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
      fieldCount: DeviceArchiveRequestService.countCreateFields(form)
    };
  }

  static validateDeleteRequestForm(form: DeviceArchiveDeleteRequestForm): DeviceArchiveRequestValidationResult {
    if (form.initiatedAt === undefined || form.initiatedAt.trim().length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredTime('删除'),
        normalizedDeviceCode: form.device.deviceCode
      };
    }

    const reason = DeviceArchiveRequestService.normalizeText(form.reason);
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
    form: DeviceArchiveCreateRequestForm
  ): Promise<ApiResponse<DeviceArchiveRequestRecord>> {
    const validation = DeviceArchiveRequestService.validateCreateRequestForm(form);
    if (!validation.valid) {
      return DeviceArchiveRequestService.createInvalidResponse(validation.message);
    }

    const normalizedDeviceCode = validation.normalizedDeviceCode ?
      validation.normalizedDeviceCode : DeviceService.normalizeDeviceCode(form.deviceCode);

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<DeviceArchiveRequestRecord>();
    }

    const response = await ApiClient.request<DeviceArchiveRequestApiResult>('/api/v1/device-archive-requests', 'POST',
      true, DeviceArchiveRequestService.buildCreateRequestBody(form, normalizedDeviceCode));

    return DeviceArchiveRequestService.mapRequestResponse(response, normalizedDeviceCode, form.deviceName,
      form.model, form.manufacturer, form.locationAddress, form.reason);
  }

  static async submitDeleteRequestRemoteFirst(
    form: DeviceArchiveDeleteRequestForm
  ): Promise<ApiResponse<DeviceArchiveRequestRecord>> {
    const validation = DeviceArchiveRequestService.validateDeleteRequestForm(form);
    if (!validation.valid) {
      return DeviceArchiveRequestService.createInvalidResponse(validation.message);
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<DeviceArchiveRequestRecord>();
    }

    const response = await ApiClient.request<DeviceArchiveRequestApiResult>('/api/v1/device-archive-requests', 'POST',
      true, DeviceArchiveRequestService.buildDeleteRequestBody(form));

    return DeviceArchiveRequestService.mapRequestResponse(response, form.device.deviceCode, form.device.name,
      form.device.model, form.device.manufacturer, form.device.location.address, form.reason);
  }

  static countCreateFields(form: DeviceArchiveCreateRequestForm): number {
    let count = 0;
    if (DeviceArchiveRequestService.normalizeText(form.deviceName).length > 0) {
      count += 1;
    }

    if (DeviceArchiveRequestService.normalizeText(form.model).length > 0) {
      count += 1;
    }

    if (DeviceArchiveRequestService.normalizeText(form.manufacturer).length > 0) {
      count += 1;
    }

    if (DeviceArchiveRequestService.normalizeText(form.locationAddress).length > 0) {
      count += 1;
    }

    return count;
  }

  private static mapRequestResponse(
    response: ApiResponse<DeviceArchiveRequestApiResult>,
    deviceCode: string,
    deviceName: string,
    model: string,
    manufacturer: string,
    locationAddress: string,
    reason: string
  ): ApiResponse<DeviceArchiveRequestRecord> {
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
          code: 'DEVICE_ARCHIVE_REQUEST_RESPONSE_INVALID',
          message: UiFeedbackService.operationUnavailable('提交')
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: DeviceArchiveRequestService.createRecord(response.data.id, deviceCode, deviceName, model, manufacturer,
        locationAddress, reason, response.data.createdAt),
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  private static createInvalidResponse(message: string): ApiResponse<DeviceArchiveRequestRecord> {
    return {
      success: false,
      error: {
        code: 'DEVICE_ARCHIVE_REQUEST_INVALID',
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
    status: DeviceArchiveRequestStatus = DeviceArchiveRequestStatus.PendingReview
  ): DeviceArchiveRequestRecord {
    return {
      id: requestId,
      deviceCode,
      deviceName: DeviceArchiveRequestService.normalizeText(deviceName),
      model: DeviceArchiveRequestService.normalizeText(model),
      manufacturer: DeviceArchiveRequestService.normalizeText(manufacturer),
      locationAddress: DeviceArchiveRequestService.normalizeText(locationAddress),
      reason: DeviceArchiveRequestService.normalizeText(reason),
      status,
      submittedAt
    };
  }

  private static buildCreateRequestBody(form: DeviceArchiveCreateRequestForm, normalizedDeviceCode: string): string {
    const payload: DeviceArchiveCreateRequestPayload = {
      type: 'CREATE',
      deviceCode: normalizedDeviceCode,
      reason: DeviceArchiveRequestService.normalizeText(form.reason),
      changes: {
        'name': {
          newValue: DeviceArchiveRequestService.normalizeText(form.deviceName)
        },
        'model': {
          newValue: DeviceArchiveRequestService.normalizeText(form.model)
        },
        'manufacturer': {
          newValue: DeviceArchiveRequestService.normalizeText(form.manufacturer)
        },
        'location.address': {
          newValue: DeviceArchiveRequestService.normalizeText(form.locationAddress)
        }
      }
    };

    if (form.initiatedAt !== undefined && form.initiatedAt.trim().length > 0) {
      payload.initiatedAt = DateTimeFormatUtil.toApiIsoString(form.initiatedAt);
    }

    return JSON.stringify(payload);
  }

  private static buildDeleteRequestBody(form: DeviceArchiveDeleteRequestForm): string {
    const payload: DeviceArchiveDeleteRequestPayload = {
      type: 'DELETE',
      deviceId: form.device.id,
      reason: DeviceArchiveRequestService.normalizeText(form.reason)
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
