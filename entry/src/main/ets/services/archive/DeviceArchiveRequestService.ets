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

interface DeviceArchiveRequestApiResult {
  id: string;
  status: DeviceArchiveRequestStatus;
  createdAt: string;
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

    if (model.length === 0) {
      return {
        valid: false,
        message: '请输入设备型号',
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

    if (manufacturer.length === 0) {
      return {
        valid: false,
        message: '请输入生产厂商',
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

    if (locationAddress.length === 0) {
      return {
        valid: false,
        message: '请输入设备位置',
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

    if (form.initiatedAt === undefined || form.initiatedAt.trim().length === 0) {
      return {
        valid: false,
        message: '请选择添加时间',
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
      fieldCount: DeviceArchiveRequestService.countCreateFields(form)
    };
  }

  static validateDeleteRequestForm(form: DeviceArchiveDeleteRequestForm): DeviceArchiveRequestValidationResult {
    if (form.initiatedAt === undefined || form.initiatedAt.trim().length === 0) {
      return {
        valid: false,
        message: '请选择删除时间',
        normalizedDeviceCode: form.device.deviceCode
      };
    }

    const reason = DeviceArchiveRequestService.normalizeText(form.reason);
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
          message: '档案申请响应无效'
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
    const changeItems: string[] = [
      DeviceArchiveRequestService.formatCreateChangeItem('name',
        DeviceArchiveRequestService.normalizeText(form.deviceName)),
      DeviceArchiveRequestService.formatCreateChangeItem('model',
        DeviceArchiveRequestService.normalizeText(form.model)),
      DeviceArchiveRequestService.formatCreateChangeItem('manufacturer',
        DeviceArchiveRequestService.normalizeText(form.manufacturer)),
      DeviceArchiveRequestService.formatCreateChangeItem('location.address',
        DeviceArchiveRequestService.normalizeText(form.locationAddress))
    ];
    const baseFields: string[] = [
      `"type":"CREATE"`,
      `"deviceCode":${JSON.stringify(normalizedDeviceCode)}`,
      `"reason":${JSON.stringify(DeviceArchiveRequestService.normalizeText(form.reason))}`,
      `"changes":{${changeItems.join(',')}}`
    ];
    if (form.initiatedAt !== undefined && form.initiatedAt.trim().length > 0) {
      baseFields.push(`"initiatedAt":${JSON.stringify(DateTimeFormatUtil.toApiIsoString(form.initiatedAt))}`);
    }

    return `{${baseFields.join(',')}}`;
  }

  private static buildDeleteRequestBody(form: DeviceArchiveDeleteRequestForm): string {
    const fields: string[] = [
      `"type":"DELETE"`,
      `"deviceId":${JSON.stringify(form.device.id)}`,
      `"reason":${JSON.stringify(DeviceArchiveRequestService.normalizeText(form.reason))}`
    ];
    if (form.initiatedAt !== undefined && form.initiatedAt.trim().length > 0) {
      fields.push(`"initiatedAt":${JSON.stringify(DateTimeFormatUtil.toApiIsoString(form.initiatedAt))}`);
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
