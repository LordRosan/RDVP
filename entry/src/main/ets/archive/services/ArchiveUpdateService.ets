import { ApiResponse } from '../../shared/models/ApiModels';
import {
  ArchiveUpdateBaseline,
  ArchiveUpdateRequestForm,
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

interface ArchiveUpdateApiResult {
  id: string;
  status: ArchiveRequestStatus;
  createdAt: string;
}

interface ArchiveUpdateChangePayload {
  oldValue: string;
  newValue: string;
}

interface ArchiveUpdateRequestPayload {
  type: string;
  deviceId: string;
  reason: string;
  changes: Record<string, ArchiveUpdateChangePayload>;
  images?: ArchiveImageSubmissionPayload[];
  initiatedAt?: string;
}

export class ArchiveUpdateService {
  static validateUpdateRequestForm(form: ArchiveUpdateRequestForm): ArchiveRequestValidationResult {
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

    const deviceName = ArchiveUpdateService.normalizeText(form.deviceName);
    const deviceType = ArchiveUpdateService.normalizeText(form.deviceType);
    const model = ArchiveUpdateService.normalizeText(form.model);
    const manufacturer = ArchiveUpdateService.normalizeText(form.manufacturer);
    const commissionedAt = ArchiveUpdateService.normalizeText(form.commissionedAt);
    const managementDepartment = ArchiveUpdateService.normalizeText(form.managementDepartment);
    const locationAddress = ArchiveUpdateService.normalizeText(form.locationAddress);
    const reason = ArchiveUpdateService.normalizeText(form.reason);
    const updatedFieldCount = ArchiveUpdateService.countUpdatedFields(form);

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

    if (ArchiveUpdateService.hasUpdatedFromBaseline(form.baseline, 'deviceName', deviceName) && deviceName.length === 0) {
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

    if (form.images.length > ArchiveImageService.getMaximumImageCount()) {
      return {
        valid: false,
        message: '设备图片最多选择5张',
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (ArchiveUpdateService.hasUpdatedFromBaseline(form.baseline, 'deviceType', deviceType) && deviceType.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('设备类型'),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (deviceType.length > 80) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('设备类型', 80),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (ArchiveUpdateService.hasUpdatedFromBaseline(form.baseline, 'model', model) && model.length === 0) {
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

    if (ArchiveUpdateService.hasUpdatedFromBaseline(form.baseline, 'manufacturer', manufacturer) && manufacturer.length === 0) {
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

    if (ArchiveUpdateService.hasUpdatedFromBaseline(form.baseline, 'commissionedAt', commissionedAt) &&
      commissionedAt.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredSelection('启用日期'),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (commissionedAt.length > 0 && !ArchiveUpdateService.isLocalDateText(commissionedAt)) {
      return {
        valid: false,
        message: UiFeedbackService.incorrect('启用日期'),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (ArchiveUpdateService.hasUpdatedFromBaseline(form.baseline, 'managementDepartment', managementDepartment) &&
      managementDepartment.length === 0) {
      return {
        valid: false,
        message: UiFeedbackService.requiredInput('管理部门'),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (managementDepartment.length > 120) {
      return {
        valid: false,
        message: UiFeedbackService.fieldTooLong('管理部门', 120),
        normalizedDeviceCode,
        fieldCount: updatedFieldCount
      };
    }

    if (ArchiveUpdateService.hasUpdatedFromBaseline(form.baseline, 'locationAddress', locationAddress) &&
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
    form: ArchiveUpdateRequestForm
  ): Promise<ApiResponse<ArchiveRequestRecord>> {
    const validation = ArchiveUpdateService.validateUpdateRequestForm(form);

    if (!validation.valid) {
      return {
        success: false,
        error: {
          code: 'ARCHIVE_REQUEST_INVALID',
          message: validation.message
        }
      };
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<ArchiveRequestRecord>();
    }

    if (form.deviceId === undefined || form.deviceId.trim().length === 0 || form.baseline === undefined) {
      return {
        success: false,
        error: {
          code: 'ARCHIVE_UPDATE_BASELINE_MISSING',
          message: UiFeedbackService.operationUnavailable('提交')
        }
      };
    }

    const response = await ApiClient.request<ArchiveUpdateApiResult>('/api/v1/archive-requests', 'POST', true,
      ArchiveUpdateService.buildCreateRequestBody(form));

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
      data: ArchiveUpdateService.createRecordFromApiResult(form, response.data, validation.normalizedDeviceCode ?
        validation.normalizedDeviceCode : DeviceService.normalizeDeviceCode(form.deviceCode)),
      requestId: response.requestId,
      timestamp: response.timestamp
    };
  }

  static countUpdatedFields(form: ArchiveUpdateRequestForm): number {
    let count = 0;

    if (ArchiveUpdateService.hasFieldUpdated(form.baseline, 'deviceName', form.deviceName)) {
      count += 1;
    }

    if (form.imagesChanged) {
      count += 1;
    }

    if (ArchiveUpdateService.hasFieldUpdated(form.baseline, 'deviceType', form.deviceType)) {
      count += 1;
    }

    if (ArchiveUpdateService.hasFieldUpdated(form.baseline, 'model', form.model)) {
      count += 1;
    }

    if (ArchiveUpdateService.hasFieldUpdated(form.baseline, 'manufacturer', form.manufacturer)) {
      count += 1;
    }

    if (ArchiveUpdateService.hasFieldUpdated(form.baseline, 'commissionedAt', form.commissionedAt)) {
      count += 1;
    }

    if (ArchiveUpdateService.hasFieldUpdated(form.baseline, 'managementDepartment', form.managementDepartment)) {
      count += 1;
    }

    if (ArchiveUpdateService.hasFieldUpdated(form.baseline, 'locationAddress', form.locationAddress)) {
      count += 1;
    }

    return count;
  }

  static formatRequestStatus(status: ArchiveRequestStatus): string {
    switch (status) {
      case ArchiveRequestStatus.Draft:
        return '待提交';
      case ArchiveRequestStatus.PendingReview:
        return '待审核';
      case ArchiveRequestStatus.Approved:
        return '已通过';
      case ArchiveRequestStatus.Rejected:
        return '已驳回';
      case ArchiveRequestStatus.Withdrawn:
        return '已撤回';
      default:
        return '未知';
    }
  }

  private static hasFieldUpdated(baseline: ArchiveUpdateBaseline | undefined, field: string, value: string): boolean {
    const normalizedValue = ArchiveUpdateService.normalizeText(value);
    if (baseline === undefined) {
      return normalizedValue.length > 0;
    }

    if (field === 'deviceName') {
      return normalizedValue !== ArchiveUpdateService.normalizeText(baseline.deviceName);
    }

    if (field === 'deviceType') {
      return normalizedValue !== ArchiveUpdateService.normalizeText(baseline.deviceType);
    }

    if (field === 'model') {
      return normalizedValue !== ArchiveUpdateService.normalizeText(baseline.model);
    }

    if (field === 'manufacturer') {
      return normalizedValue !== ArchiveUpdateService.normalizeText(baseline.manufacturer);
    }

    if (field === 'commissionedAt') {
      return normalizedValue !== ArchiveUpdateService.normalizeText(baseline.commissionedAt);
    }

    if (field === 'managementDepartment') {
      return normalizedValue !== ArchiveUpdateService.normalizeText(baseline.managementDepartment);
    }

    if (field === 'locationAddress') {
      return normalizedValue !== ArchiveUpdateService.normalizeText(baseline.locationAddress);
    }

    return false;
  }

  private static hasUpdatedFromBaseline(baseline: ArchiveUpdateBaseline | undefined, field: string, value: string): boolean {
    if (baseline === undefined) {
      return false;
    }

    return ArchiveUpdateService.hasFieldUpdated(baseline, field, value);
  }

  private static buildApiChangesPayload(form: ArchiveUpdateRequestForm): Record<string, ArchiveUpdateChangePayload> {
    const baseline = form.baseline;
    if (baseline === undefined) {
      return {};
    }

    const changes: Record<string, ArchiveUpdateChangePayload> = {};
    const deviceName = ArchiveUpdateService.normalizeText(form.deviceName);
    if (ArchiveUpdateService.hasFieldUpdated(baseline, 'deviceName', deviceName)) {
      changes['name'] = ArchiveUpdateService.createApiChange(baseline.deviceName, deviceName);
    }

    const deviceType = ArchiveUpdateService.normalizeText(form.deviceType);
    if (ArchiveUpdateService.hasFieldUpdated(baseline, 'deviceType', deviceType)) {
      changes['deviceType'] = ArchiveUpdateService.createApiChange(baseline.deviceType, deviceType);
    }

    const model = ArchiveUpdateService.normalizeText(form.model);
    if (ArchiveUpdateService.hasFieldUpdated(baseline, 'model', model)) {
      changes['model'] = ArchiveUpdateService.createApiChange(baseline.model, model);
    }

    const manufacturer = ArchiveUpdateService.normalizeText(form.manufacturer);
    if (ArchiveUpdateService.hasFieldUpdated(baseline, 'manufacturer', manufacturer)) {
      changes['manufacturer'] = ArchiveUpdateService.createApiChange(baseline.manufacturer, manufacturer);
    }

    const commissionedAt = ArchiveUpdateService.normalizeText(form.commissionedAt);
    if (ArchiveUpdateService.hasFieldUpdated(baseline, 'commissionedAt', commissionedAt)) {
      changes['commissionedAt'] = ArchiveUpdateService.createApiChange(baseline.commissionedAt, commissionedAt);
    }

    const managementDepartment = ArchiveUpdateService.normalizeText(form.managementDepartment);
    if (ArchiveUpdateService.hasFieldUpdated(baseline, 'managementDepartment', managementDepartment)) {
      changes['managementDepartment'] =
        ArchiveUpdateService.createApiChange(baseline.managementDepartment, managementDepartment);
    }

    const locationAddress = ArchiveUpdateService.normalizeText(form.locationAddress);
    if (ArchiveUpdateService.hasFieldUpdated(baseline, 'locationAddress', locationAddress)) {
      changes['location.address'] = ArchiveUpdateService.createApiChange(baseline.locationAddress, locationAddress);
    }

    return changes;
  }

  private static buildCreateRequestBody(form: ArchiveUpdateRequestForm): string {
    const payload: ArchiveUpdateRequestPayload = {
      type: 'UPDATE',
      deviceId: form.deviceId === undefined ? '' : form.deviceId,
      reason: ArchiveUpdateService.normalizeText(form.reason),
      changes: ArchiveUpdateService.buildApiChangesPayload(form)
    };

    if (form.imagesChanged) {
      payload.images = ArchiveImageService.buildSubmissionPayloads(form.images);
    }

    if (form.initiatedAt !== undefined && form.initiatedAt.trim().length > 0) {
      payload.initiatedAt = DateTimeFormatUtil.toApiIsoString(form.initiatedAt);
    }

    return JSON.stringify(payload);
  }

  private static createApiChange(oldValue: string, newValue: string): ArchiveUpdateChangePayload {
    return {
      oldValue,
      newValue
    };
  }

  private static createRecordFromApiResult(
    form: ArchiveUpdateRequestForm,
    result: ArchiveUpdateApiResult,
    normalizedDeviceCode: string
  ): ArchiveRequestRecord {
    return {
      id: result.id,
      deviceCode: normalizedDeviceCode,
      deviceName: form.deviceName.trim(),
      imageCount: form.images.length,
      deviceType: form.deviceType.trim(),
      model: form.model.trim(),
      manufacturer: form.manufacturer.trim(),
      commissionedAt: form.commissionedAt.trim(),
      managementDepartment: form.managementDepartment.trim(),
      locationAddress: form.locationAddress.trim(),
      reason: form.reason.trim(),
      status: result.status,
      submittedAt: result.createdAt
    };
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
