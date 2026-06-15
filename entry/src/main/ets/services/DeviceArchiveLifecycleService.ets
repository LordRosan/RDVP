import { ApiResponse } from '../models/ApiModels';
import {
  DeviceArchiveChangeRequestRecord,
  DeviceArchiveChangeRequestStatus,
  DeviceArchiveChangeRequestValidationResult
} from '../models/DeviceArchiveChangeModels';
import { DeviceSummary } from '../models/DeviceModels';
import { ApiClient } from './ApiClient';
import { DeviceService } from './DeviceService';

interface DeviceArchiveLifecycleApiResult {
  id: string;
  status: DeviceArchiveChangeRequestStatus;
  createdAt: string;
}

export interface DeviceArchiveCreateRequestForm {
  deviceCode: string;
  deviceName: string;
  model: string;
  manufacturer: string;
  locationAddress: string;
  reason: string;
  initiatedAt?: string;
}

export interface DeviceArchiveDeleteRequestForm {
  device: DeviceSummary;
  reason: string;
  initiatedAt?: string;
}

export class DeviceArchiveLifecycleService {
  static validateCreateRequestForm(form: DeviceArchiveCreateRequestForm): DeviceArchiveChangeRequestValidationResult {
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

    const deviceName = DeviceArchiveLifecycleService.normalizeText(form.deviceName);
    const model = DeviceArchiveLifecycleService.normalizeText(form.model);
    const manufacturer = DeviceArchiveLifecycleService.normalizeText(form.manufacturer);
    const locationAddress = DeviceArchiveLifecycleService.normalizeText(form.locationAddress);
    const reason = DeviceArchiveLifecycleService.normalizeText(form.reason);

    if (deviceName.length === 0) {
      return {
        valid: false,
        message: '请输入设备名称',
        normalizedDeviceCode
      };
    }

    if (deviceName.length > 80) {
      return {
        valid: false,
        message: '设备名称不能超过80个字符',
        normalizedDeviceCode
      };
    }

    if (model.length > 80) {
      return {
        valid: false,
        message: '设备型号不能超过80个字符',
        normalizedDeviceCode
      };
    }

    if (manufacturer.length > 100) {
      return {
        valid: false,
        message: '生产厂商不能超过100个字符',
        normalizedDeviceCode
      };
    }

    if (locationAddress.length > 200) {
      return {
        valid: false,
        message: '设备位置不能超过200个字符',
        normalizedDeviceCode
      };
    }

    if (reason.length === 0) {
      return {
        valid: false,
        message: '请输入添加原因',
        normalizedDeviceCode
      };
    }

    if (reason.length > 500) {
      return {
        valid: false,
        message: '添加原因不能超过500个字符',
        normalizedDeviceCode
      };
    }

    return {
      valid: true,
      message: '',
      normalizedDeviceCode,
      changeCount: DeviceArchiveLifecycleService.countCreateFields(form)
    };
  }

  static validateDeleteRequestForm(form: DeviceArchiveDeleteRequestForm): DeviceArchiveChangeRequestValidationResult {
    const reason = DeviceArchiveLifecycleService.normalizeText(form.reason);
    if (reason.length === 0) {
      return {
        valid: false,
        message: '请输入删除原因',
        normalizedDeviceCode: form.device.deviceCode
      };
    }

    if (reason.length > 500) {
      return {
        valid: false,
        message: '删除原因不能超过500个字符',
        normalizedDeviceCode: form.device.deviceCode
      };
    }

    if (DeviceService.isArchiveChangeLocked(form.device)) {
      return {
        valid: false,
        message: DeviceService.formatArchiveChangeLockReason(form.device),
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
  ): Promise<ApiResponse<DeviceArchiveChangeRequestRecord>> {
    const validation = DeviceArchiveLifecycleService.validateCreateRequestForm(form);
    if (!validation.valid) {
      return DeviceArchiveLifecycleService.createInvalidResponse(validation.message);
    }

    const normalizedDeviceCode = validation.normalizedDeviceCode ?
      validation.normalizedDeviceCode : DeviceService.normalizeDeviceCode(form.deviceCode);

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<DeviceArchiveChangeRequestRecord>();
    }

    const response = await ApiClient.request<DeviceArchiveLifecycleApiResult>('/api/v1/device-archive-change-requests', 'POST',
      true, DeviceArchiveLifecycleService.buildCreateRequestBody(form, normalizedDeviceCode));

    return DeviceArchiveLifecycleService.mapLifecycleResponse(response, normalizedDeviceCode, form.deviceName,
      form.model, form.manufacturer, form.locationAddress, form.reason);
  }

  static async submitDeleteRequestRemoteFirst(
    form: DeviceArchiveDeleteRequestForm
  ): Promise<ApiResponse<DeviceArchiveChangeRequestRecord>> {
    const validation = DeviceArchiveLifecycleService.validateDeleteRequestForm(form);
    if (!validation.valid) {
      return DeviceArchiveLifecycleService.createInvalidResponse(validation.message);
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<DeviceArchiveChangeRequestRecord>();
    }

    const response = await ApiClient.request<DeviceArchiveLifecycleApiResult>('/api/v1/device-archive-change-requests', 'POST',
      true, DeviceArchiveLifecycleService.buildDeleteRequestBody(form));

    return DeviceArchiveLifecycleService.mapLifecycleResponse(response, form.device.deviceCode, form.device.name,
      form.device.model, form.device.manufacturer, form.device.location.address, form.reason);
  }

  static countCreateFields(form: DeviceArchiveCreateRequestForm): number {
    let count = 0;
    if (DeviceArchiveLifecycleService.normalizeText(form.deviceName).length > 0) {
      count += 1;
    }

    if (DeviceArchiveLifecycleService.normalizeText(form.model).length > 0) {
      count += 1;
    }

    if (DeviceArchiveLifecycleService.normalizeText(form.manufacturer).length > 0) {
      count += 1;
    }

    if (DeviceArchiveLifecycleService.normalizeText(form.locationAddress).length > 0) {
      count += 1;
    }

    return count;
  }

  private static mapLifecycleResponse(
    response: ApiResponse<DeviceArchiveLifecycleApiResult>,
    deviceCode: string,
    deviceName: string,
    model: string,
    manufacturer: string,
    locationAddress: string,
    reason: string
  ): ApiResponse<DeviceArchiveChangeRequestRecord> {
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
          code: 'DEVICE_ARCHIVE_CHANGE_RESPONSE_INVALID',
          message: '档案申请响应无效'
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: DeviceArchiveLifecycleService.createRecord(response.data.id, deviceCode, deviceName, model, manufacturer,
        locationAddress, reason, response.data.createdAt),
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  private static createInvalidResponse(message: string): ApiResponse<DeviceArchiveChangeRequestRecord> {
    return {
      success: false,
      error: {
        code: 'DEVICE_ARCHIVE_CHANGE_REQUEST_INVALID',
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
    status: DeviceArchiveChangeRequestStatus = DeviceArchiveChangeRequestStatus.PendingReview
  ): DeviceArchiveChangeRequestRecord {
    return {
      id: requestId,
      deviceCode,
      deviceName: DeviceArchiveLifecycleService.normalizeText(deviceName),
      model: DeviceArchiveLifecycleService.normalizeText(model),
      manufacturer: DeviceArchiveLifecycleService.normalizeText(manufacturer),
      locationAddress: DeviceArchiveLifecycleService.normalizeText(locationAddress),
      reason: DeviceArchiveLifecycleService.normalizeText(reason),
      status,
      submittedAt
    };
  }

  private static buildCreateRequestBody(form: DeviceArchiveCreateRequestForm, normalizedDeviceCode: string): string {
    const changeItems: string[] = [
      DeviceArchiveLifecycleService.formatCreateChangeItem('name',
        DeviceArchiveLifecycleService.normalizeText(form.deviceName)),
      DeviceArchiveLifecycleService.formatCreateChangeItem('model',
        DeviceArchiveLifecycleService.normalizeText(form.model)),
      DeviceArchiveLifecycleService.formatCreateChangeItem('manufacturer',
        DeviceArchiveLifecycleService.normalizeText(form.manufacturer)),
      DeviceArchiveLifecycleService.formatCreateChangeItem('location.address',
        DeviceArchiveLifecycleService.normalizeText(form.locationAddress))
    ];
    const baseFields: string[] = [
      `"type":"CREATE"`,
      `"deviceCode":${JSON.stringify(normalizedDeviceCode)}`,
      `"reason":${JSON.stringify(DeviceArchiveLifecycleService.normalizeText(form.reason))}`,
      `"changes":{${changeItems.join(',')}}`
    ];
    if (form.initiatedAt !== undefined && form.initiatedAt.trim().length > 0) {
      baseFields.push(`"initiatedAt":${JSON.stringify(form.initiatedAt.trim())}`);
    }

    return `{${baseFields.join(',')}}`;
  }

  private static buildDeleteRequestBody(form: DeviceArchiveDeleteRequestForm): string {
    const fields: string[] = [
      `"type":"DELETE"`,
      `"deviceId":${JSON.stringify(form.device.id)}`,
      `"reason":${JSON.stringify(DeviceArchiveLifecycleService.normalizeText(form.reason))}`
    ];
    if (form.initiatedAt !== undefined && form.initiatedAt.trim().length > 0) {
      fields.push(`"initiatedAt":${JSON.stringify(form.initiatedAt.trim())}`);
    }

    return `{${fields.join(',')}}`;
  }

  private static formatCreateChangeItem(field: string, newValue: string): string {
    return `${JSON.stringify(field)}:{"newValue":${JSON.stringify(newValue)}}`;
  }

  private static normalizeText(value: string): string {
    return value.trim();
  }
}
