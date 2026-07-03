import { ApiResponse } from '../../shared/models/ApiModels';
import {
  DeviceArchiveUpdateBaseline,
  DeviceArchiveUpdateRequestForm,
  DeviceArchiveRequestRecord,
  DeviceArchiveRequestStatus,
  DeviceArchiveRequestValidationResult
} from '../models/DeviceArchiveRequestModels';
import { ApiClient } from '../../shared/services/ApiClient';
import { DeviceService } from './DeviceService';
import { DateTimeFormatUtil } from '../../shared/utils/DateTimeFormatUtil';
import { UiFeedbackService } from '../../shared/services/UiFeedbackService';

interface DeviceArchiveUpdateApiResult {
  id: string;
  status: DeviceArchiveRequestStatus;
  createdAt: string;
}

interface DeviceArchiveUpdateChangePayload {
  oldValue: string;
  newValue: string;
}

interface DeviceArchiveUpdateRequestPayload {
  type: string;
  deviceId: string;
  reason: string;
  changes: Record<string, DeviceArchiveUpdateChangePayload>;
  initiatedAt?: string;
}

export class DeviceArchiveUpdateService {
  static validateUpdateRequestForm(form: DeviceArchiveUpdateRequestForm): DeviceArchiveRequestValidationResult {
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

    const deviceName = DeviceArchiveUpdateService.normalizeText(form.deviceName);
    const model = DeviceArchiveUpdateService.normalizeText(form.model);
    const manufacturer = DeviceArchiveUpdateService.normalizeText(form.manufacturer);
    const locationAddress = DeviceArchiveUpdateService.normalizeText(form.locationAddress);
    const reason = DeviceArchiveUpdateService.normalizeText(form.reason);
    const updatedFieldCount = DeviceArchiveUpdateService.countUpdatedFields(form);

    if (updatedFieldCount === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredAction('修改档案信息'),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (form.initiatedAt === undefined || form.initiatedAt.trim().length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredTime('修改'),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (DeviceArchiveUpdateService.hasUpdatedFromBaseline(form.baseline, 'deviceName', deviceName) && deviceName.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('设备名称'),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (deviceName.length > 80) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('设备名称', 80),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (DeviceArchiveUpdateService.hasUpdatedFromBaseline(form.baseline, 'model', model) && model.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('设备型号'),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (model.length > 80) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('设备型号', 80),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (DeviceArchiveUpdateService.hasUpdatedFromBaseline(form.baseline, 'manufacturer', manufacturer) && manufacturer.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('生产厂商'),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (manufacturer.length > 100) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('生产厂商', 100),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (DeviceArchiveUpdateService.hasUpdatedFromBaseline(form.baseline, 'locationAddress', locationAddress) &&
      locationAddress.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('设备位置'),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (locationAddress.length > 200) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('设备位置', 200),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (reason.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('修改原因'),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (reason.length > 500) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('修改原因', 500),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    return {
      valid: true,
      message: '',
      normalizedDeviceCode,
      fieldCount: updatedFieldCount
    };
  }

  static async submitUpdateRequestRemoteFirst(
    form: DeviceArchiveUpdateRequestForm
  ): Promise<ApiResponse<DeviceArchiveRequestRecord>> {
    const validation = DeviceArchiveUpdateService.validateUpdateRequestForm(form);

    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'DEVICE_ARCHIVE_REQUEST_INVALID',
          message: validation.message
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<DeviceArchiveRequestRecord>();
    }

    if (form.deviceId === undefined || form.deviceId.trim().length === 0 || form.baseline === undefined) {
      return {
        success: false,
        error: {
          code: 'DEVICE_ARCHIVE_UPDATE_BASELINE_MISSING',
          message: UiFeedbackService.operationUnavailable('提交')
        }
      };
    }

    const response = await ApiClient.request<DeviceArchiveUpdateApiResult>('/api/v1/device-archive-requests', 'POST', true,
      DeviceArchiveUpdateService.buildCreateRequestBody(form));

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
      data: DeviceArchiveUpdateService.createRecordFromApiResult(form, response.data, validation.normalizedDeviceCode ?
        validation.normalizedDeviceCode : DeviceService.normalizeDeviceCode(form.deviceCode)),
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static countUpdatedFields(form: DeviceArchiveUpdateRequestForm): number {
    let count = 0;

    if (DeviceArchiveUpdateService.hasFieldUpdated(form.baseline, 'deviceName', form.deviceName)) {
      count += 1;
    }

    if (DeviceArchiveUpdateService.hasFieldUpdated(form.baseline, 'model', form.model)) {
      count += 1;
    }

    if (DeviceArchiveUpdateService.hasFieldUpdated(form.baseline, 'manufacturer', form.manufacturer)) {
      count += 1;
    }

    if (DeviceArchiveUpdateService.hasFieldUpdated(form.baseline, 'locationAddress', form.locationAddress)) {
      count += 1;
    }

    return count;
  }

  static formatRequestStatus(status: DeviceArchiveRequestStatus): string {
    switch (status) {
      case DeviceArchiveRequestStatus.Draft:
        return '待提交';
      case DeviceArchiveRequestStatus.PendingReview:
        return '待审核';
      case DeviceArchiveRequestStatus.Approved:
        return '已通过';
      case DeviceArchiveRequestStatus.Rejected:
        return '已驳回';
      case DeviceArchiveRequestStatus.Withdrawn:
        return '已撤回';
      default:
        return '未知';
    }
  }

  private static hasFieldUpdated(baseline: DeviceArchiveUpdateBaseline | undefined, field: string, value: string): boolean {
    const normalizedValue = DeviceArchiveUpdateService.normalizeText(value);
    if (baseline === undefined) {
      return normalizedValue.length > 0;
    }

    if (field === 'deviceName') {
      return normalizedValue !== DeviceArchiveUpdateService.normalizeText(baseline.deviceName);
    }

    if (field === 'model') {
      return normalizedValue !== DeviceArchiveUpdateService.normalizeText(baseline.model);
    }

    if (field === 'manufacturer') {
      return normalizedValue !== DeviceArchiveUpdateService.normalizeText(baseline.manufacturer);
    }

    if (field === 'locationAddress') {
      return normalizedValue !== DeviceArchiveUpdateService.normalizeText(baseline.locationAddress);
    }

    return false;
  }

  private static hasUpdatedFromBaseline(baseline: DeviceArchiveUpdateBaseline | undefined, field: string, value: string): boolean {
    if (baseline === undefined) {
      return false;
    }

    return DeviceArchiveUpdateService.hasFieldUpdated(baseline, field, value);
  }

  private static buildApiChangesPayload(form: DeviceArchiveUpdateRequestForm): Record<string, DeviceArchiveUpdateChangePayload> {
    const baseline = form.baseline;
    if (baseline === undefined) {
      return {};
    }

    const changes: Record<string, DeviceArchiveUpdateChangePayload> = {};
    const deviceName = DeviceArchiveUpdateService.normalizeText(form.deviceName);
    if (DeviceArchiveUpdateService.hasFieldUpdated(baseline, 'deviceName', deviceName)) {
      changes['name'] = DeviceArchiveUpdateService.createApiChange(baseline.deviceName, deviceName);
    }

    const model = DeviceArchiveUpdateService.normalizeText(form.model);
    if (DeviceArchiveUpdateService.hasFieldUpdated(baseline, 'model', model)) {
      changes['model'] = DeviceArchiveUpdateService.createApiChange(baseline.model, model);
    }

    const manufacturer = DeviceArchiveUpdateService.normalizeText(form.manufacturer);
    if (DeviceArchiveUpdateService.hasFieldUpdated(baseline, 'manufacturer', manufacturer)) {
      changes['manufacturer'] = DeviceArchiveUpdateService.createApiChange(baseline.manufacturer, manufacturer);
    }

    const locationAddress = DeviceArchiveUpdateService.normalizeText(form.locationAddress);
    if (DeviceArchiveUpdateService.hasFieldUpdated(baseline, 'locationAddress', locationAddress)) {
      changes['location.address'] = DeviceArchiveUpdateService.createApiChange(baseline.locationAddress, locationAddress);
    }

    return changes;
  }

  private static buildCreateRequestBody(form: DeviceArchiveUpdateRequestForm): string {
    const payload: DeviceArchiveUpdateRequestPayload = {
      type: 'UPDATE',
      deviceId: form.deviceId === undefined ? '' : form.deviceId,
      reason: DeviceArchiveUpdateService.normalizeText(form.reason),
      changes: DeviceArchiveUpdateService.buildApiChangesPayload(form)
    };

    if (form.initiatedAt !== undefined && form.initiatedAt.trim().length > 0) {
      payload.initiatedAt = DateTimeFormatUtil.toApiIsoString(form.initiatedAt);
    }

    return JSON.stringify(payload);
  }

  private static createApiChange(oldValue: string, newValue: string): DeviceArchiveUpdateChangePayload {
    return {
      oldValue,
      newValue
    };
  }

  private static createRecordFromApiResult(
    form: DeviceArchiveUpdateRequestForm,
    result: DeviceArchiveUpdateApiResult,
    normalizedDeviceCode: string
  ): DeviceArchiveRequestRecord {
    return {
      id: result.id,
      deviceCode: normalizedDeviceCode,
      deviceName: form.deviceName.trim(),
      model: form.model.trim(),
      manufacturer: form.manufacturer.trim(),
      locationAddress: form.locationAddress.trim(),
      reason: form.reason.trim(),
      status: result.status,
      submittedAt: result.createdAt
    };
  }

  private static normalizeText(value: string): string {
    return value.trim();
  }
}
