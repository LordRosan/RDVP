import { ApiResponse } from '../models/ApiModels';
import {
  DeviceArchiveChangeBaseline,
  DeviceArchiveChangeRequestForm,
  DeviceArchiveChangeRequestRecord,
  DeviceArchiveChangeRequestStatus,
  DeviceArchiveChangeRequestValidationResult
} from '../models/DeviceArchiveChangeModels';
import { OperationRecordType } from '../models/OperationRecordModels';
import { ApiClient } from './ApiClient';
import { DeviceService } from './DeviceService';
import { LocalOperationRecordRepository } from './LocalOperationRecordRepository';

export class DeviceArchiveChangeService {
  static validateChangeRequestForm(form: DeviceArchiveChangeRequestForm): DeviceArchiveChangeRequestValidationResult {
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

    const deviceName = DeviceArchiveChangeService.normalizeText(form.deviceName);
    const model = DeviceArchiveChangeService.normalizeText(form.model);
    const manufacturer = DeviceArchiveChangeService.normalizeText(form.manufacturer);
    const locationAddress = DeviceArchiveChangeService.normalizeText(form.locationAddress);
    const reason = DeviceArchiveChangeService.normalizeText(form.reason);
    const changeCount = DeviceArchiveChangeService.countChangedFields(form);

    if (changeCount === 0) {
      return {
        valid: false,
        message: '请至少填写一项需要变更的信息',
        normalizedDeviceCode,
        changeCount
      };
    }

    if (DeviceArchiveChangeService.hasChangedFromBaseline(form.baseline, 'deviceName', deviceName) && deviceName.length === 0) {
      return {
        valid: false,
        message: '变更后的设备名称不能为空',
        normalizedDeviceCode,
        changeCount
      };
    }

    if (deviceName.length > 80) {
      return {
        valid: false,
        message: '设备名称不能超过80个字符',
        normalizedDeviceCode,
        changeCount
      };
    }

    if (DeviceArchiveChangeService.hasChangedFromBaseline(form.baseline, 'model', model) && model.length === 0) {
      return {
        valid: false,
        message: '变更后的设备型号不能为空',
        normalizedDeviceCode,
        changeCount
      };
    }

    if (model.length > 80) {
      return {
        valid: false,
        message: '设备型号不能超过80个字符',
        normalizedDeviceCode,
        changeCount
      };
    }

    if (DeviceArchiveChangeService.hasChangedFromBaseline(form.baseline, 'manufacturer', manufacturer) && manufacturer.length === 0) {
      return {
        valid: false,
        message: '变更后的生产厂商不能为空',
        normalizedDeviceCode,
        changeCount
      };
    }

    if (manufacturer.length > 100) {
      return {
        valid: false,
        message: '生产厂商不能超过100个字符',
        normalizedDeviceCode,
        changeCount
      };
    }

    if (DeviceArchiveChangeService.hasChangedFromBaseline(form.baseline, 'locationAddress', locationAddress) &&
      locationAddress.length === 0) {
      return {
        valid: false,
        message: '变更后的设备位置不能为空',
        normalizedDeviceCode,
        changeCount
      };
    }

    if (locationAddress.length > 200) {
      return {
        valid: false,
        message: '设备位置不能超过200个字符',
        normalizedDeviceCode,
        changeCount
      };
    }

    if (reason.length === 0) {
      return {
        valid: false,
        message: '请输入变更原因',
        normalizedDeviceCode,
        changeCount
      };
    }

    if (reason.length > 500) {
      return {
        valid: false,
        message: '变更原因不能超过500个字符',
        normalizedDeviceCode,
        changeCount
      };
    }

    return {
      valid: true,
      message: '',
      normalizedDeviceCode,
      changeCount
    };
  }

  static submitChangeRequest(form: DeviceArchiveChangeRequestForm): ApiResponse<DeviceArchiveChangeRequestRecord> {
    const validation = DeviceArchiveChangeService.validateChangeRequestForm(form);

    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'DEVICE_CHANGE_REQUEST_INVALID',
          message: validation.message
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return DeviceArchiveChangeService.createLocalChangeRequestResponse(form, validation.normalizedDeviceCode ?
        validation.normalizedDeviceCode : DeviceService.normalizeDeviceCode(form.deviceCode));
    }

    return ApiClient.createServiceUnavailableResponse<DeviceArchiveChangeRequestRecord>();
  }

  static countChangedFields(form: DeviceArchiveChangeRequestForm): number {
    let count = 0;

    if (DeviceArchiveChangeService.hasFieldChanged(form.baseline, 'deviceName', form.deviceName)) {
      count += 1;
    }

    if (DeviceArchiveChangeService.hasFieldChanged(form.baseline, 'model', form.model)) {
      count += 1;
    }

    if (DeviceArchiveChangeService.hasFieldChanged(form.baseline, 'manufacturer', form.manufacturer)) {
      count += 1;
    }

    if (DeviceArchiveChangeService.hasFieldChanged(form.baseline, 'locationAddress', form.locationAddress)) {
      count += 1;
    }

    return count;
  }

  static formatRequestStatus(status: DeviceArchiveChangeRequestStatus): string {
    switch (status) {
      case DeviceArchiveChangeRequestStatus.Draft:
        return '待提交';
      case DeviceArchiveChangeRequestStatus.PendingReview:
        return '待审核';
      case DeviceArchiveChangeRequestStatus.Approved:
        return '已通过';
      case DeviceArchiveChangeRequestStatus.Rejected:
        return '已驳回';
      default:
        return '未知';
    }
  }

  private static hasFieldChanged(baseline: DeviceArchiveChangeBaseline | undefined, field: string, value: string): boolean {
    const normalizedValue = DeviceArchiveChangeService.normalizeText(value);
    if (baseline === undefined) {
      return normalizedValue.length > 0;
    }

    if (field === 'deviceName') {
      return normalizedValue !== DeviceArchiveChangeService.normalizeText(baseline.deviceName);
    }

    if (field === 'model') {
      return normalizedValue !== DeviceArchiveChangeService.normalizeText(baseline.model);
    }

    if (field === 'manufacturer') {
      return normalizedValue !== DeviceArchiveChangeService.normalizeText(baseline.manufacturer);
    }

    if (field === 'locationAddress') {
      return normalizedValue !== DeviceArchiveChangeService.normalizeText(baseline.locationAddress);
    }

    return false;
  }

  private static hasChangedFromBaseline(baseline: DeviceArchiveChangeBaseline | undefined, field: string, value: string): boolean {
    if (baseline === undefined) {
      return false;
    }

    return DeviceArchiveChangeService.hasFieldChanged(baseline, field, value);
  }

  private static createLocalChangeRequestResponse(form: DeviceArchiveChangeRequestForm,
    normalizedDeviceCode: string): ApiResponse<DeviceArchiveChangeRequestRecord> {
    const submittedAt = new Date().toISOString();
    const requestId = `DCR-LOCAL-${submittedAt.replace(/[-:.TZ]/g, '').substring(0, 14)}`;
    LocalOperationRecordRepository.append(OperationRecordType.DeviceChangeRequest, '提交档案变更', normalizedDeviceCode,
      '设备档案变更进入待审核状态');
    return {
      success: true,
      data: {
        id: requestId,
        deviceCode: normalizedDeviceCode,
        deviceName: form.deviceName.trim(),
        model: form.model.trim(),
        manufacturer: form.manufacturer.trim(),
        locationAddress: form.locationAddress.trim(),
        reason: form.reason.trim(),
        status: DeviceArchiveChangeRequestStatus.PendingReview,
        submittedAt
      },
      requestId: 'local-device-change-request',
      timestamp: submittedAt
    };
  }

  private static normalizeText(value: string): string {
    return value.trim();
  }
}
