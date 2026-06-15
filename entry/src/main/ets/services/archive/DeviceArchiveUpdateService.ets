import { ApiResponse } from '../../models/common/ApiModels';
import {
  DeviceArchiveUpdateBaseline,
  DeviceArchiveUpdateRequestForm,
  DeviceArchiveRequestRecord,
  DeviceArchiveRequestStatus,
  DeviceArchiveRequestValidationResult
} from '../../models/archive/DeviceArchiveRequestModels';
import { ApiClient } from '../common/ApiClient';
import { DeviceService } from './DeviceService';

interface DeviceArchiveUpdateApiResult {
  id: string;
  status: DeviceArchiveRequestStatus;
  createdAt: string;
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
        message: '请至少填写一项需要修改的信息',
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (DeviceArchiveUpdateService.hasUpdatedFromBaseline(form.baseline, 'deviceName', deviceName) && deviceName.length === 0) {
      return {
        valid: false,
        message: '修改后的设备名称不能为空',
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (deviceName.length > 80) {
      return {
        valid: false,
        message: '设备名称不能超过80个字符',
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (DeviceArchiveUpdateService.hasUpdatedFromBaseline(form.baseline, 'model', model) && model.length === 0) {
      return {
        valid: false,
        message: '修改后的设备型号不能为空',
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (model.length > 80) {
      return {
        valid: false,
        message: '设备型号不能超过80个字符',
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (DeviceArchiveUpdateService.hasUpdatedFromBaseline(form.baseline, 'manufacturer', manufacturer) && manufacturer.length === 0) {
      return {
        valid: false,
        message: '修改后的生产厂商不能为空',
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (manufacturer.length > 100) {
      return {
        valid: false,
        message: '生产厂商不能超过100个字符',
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (DeviceArchiveUpdateService.hasUpdatedFromBaseline(form.baseline, 'locationAddress', locationAddress) &&
      locationAddress.length === 0) {
      return {
        valid: false,
        message: '修改后的设备位置不能为空',
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (locationAddress.length > 200) {
      return {
        valid: false,
        message: '设备位置不能超过200个字符',
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (reason.length === 0) {
      return {
        valid: false,
        message: '请输入修改原因',
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (reason.length > 500) {
      return {
        valid: false,
        message: '修改原因不能超过500个字符',
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
          message: '缺少设备档案基准信息，请重新查询后提交'
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
          message: '档案申请响应无效'
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

  private static buildApiChangesPayload(form: DeviceArchiveUpdateRequestForm): string {
    const baseline = form.baseline;
    if (baseline === undefined) {
      return '{}';
    }

    const changeItems: string[] = [];
    const deviceName = DeviceArchiveUpdateService.normalizeText(form.deviceName);
    if (DeviceArchiveUpdateService.hasFieldUpdated(baseline, 'deviceName', deviceName)) {
      changeItems.push(DeviceArchiveUpdateService.formatApiChangeItem('name', baseline.deviceName, deviceName));
    }

    const model = DeviceArchiveUpdateService.normalizeText(form.model);
    if (DeviceArchiveUpdateService.hasFieldUpdated(baseline, 'model', model)) {
      changeItems.push(DeviceArchiveUpdateService.formatApiChangeItem('model', baseline.model, model));
    }

    const manufacturer = DeviceArchiveUpdateService.normalizeText(form.manufacturer);
    if (DeviceArchiveUpdateService.hasFieldUpdated(baseline, 'manufacturer', manufacturer)) {
      changeItems.push(DeviceArchiveUpdateService.formatApiChangeItem('manufacturer', baseline.manufacturer, manufacturer));
    }

    const locationAddress = DeviceArchiveUpdateService.normalizeText(form.locationAddress);
    if (DeviceArchiveUpdateService.hasFieldUpdated(baseline, 'locationAddress', locationAddress)) {
      changeItems.push(DeviceArchiveUpdateService.formatApiChangeItem('location.address', baseline.locationAddress, locationAddress));
    }

    return `{${changeItems.join(',')}}`;
  }

  private static buildCreateRequestBody(form: DeviceArchiveUpdateRequestForm): string {
    const fieldList: string[] = [
      `"type":"UPDATE"`,
      `"deviceId":${JSON.stringify(form.deviceId)}`,
      `"reason":${JSON.stringify(DeviceArchiveUpdateService.normalizeText(form.reason))}`,
      `"changes":${DeviceArchiveUpdateService.buildApiChangesPayload(form)}`
    ];
    if (form.initiatedAt !== undefined && form.initiatedAt.trim().length > 0) {
      fieldList.push(`"initiatedAt":${JSON.stringify(form.initiatedAt.trim())}`);
    }

    return `{${fieldList.join(',')}}`;
  }

  private static formatApiChangeItem(field: string, oldValue: string, newValue: string): string {
    return `${JSON.stringify(field)}:{"oldValue":${JSON.stringify(oldValue)},"newValue":${JSON.stringify(newValue)}}`;
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
