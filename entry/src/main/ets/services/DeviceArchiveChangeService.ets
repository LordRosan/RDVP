import { ApiResponse } from '../models/ApiModels';
import {
  DeviceArchiveChangeBaseline,
  DeviceArchiveChangeRequestForm,
  DeviceArchiveChangeRequestRecord,
  DeviceArchiveChangeRequestStatus,
  DeviceArchiveChangeRequestValidationResult
} from '../models/DeviceArchiveChangeModels';
import {
  DeviceArchiveOfflineChangeValuePayload,
  DeviceArchiveUpdateRequestOfflineSyncPayload,
  OfflineSyncOperationType
} from '../models/OfflineSyncModels';
import { OperationRecordType } from '../models/OperationRecordModels';
import { ApiClient } from './ApiClient';
import { DeviceService } from './DeviceService';
import { LocalDeviceArchiveRepository } from './LocalDeviceArchiveRepository';
import { LocalOperationRecordRepository } from './LocalOperationRecordRepository';
import { OfflineSyncService } from './OfflineSyncService';
import { SessionStore } from '../stores/SessionStore';

interface DeviceArchiveChangeApiResult {
  id: string;
  status: DeviceArchiveChangeRequestStatus;
  createdAt: string;
}

const OFFLINE_SYNC_DEVICE_ARCHIVE_UPDATE_REQUEST_ID = 'offline-sync-device-archive-update-request';

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

    if (ApiClient.isOfflineMode()) {
      return DeviceArchiveChangeService.createLocalQueuedChangeRequestResponse(form, validation.normalizedDeviceCode ?
        validation.normalizedDeviceCode : DeviceService.normalizeDeviceCode(form.deviceCode));
    }

    return ApiClient.createServiceUnavailableResponse<DeviceArchiveChangeRequestRecord>();
  }

  static async submitChangeRequestRemoteFirst(
    form: DeviceArchiveChangeRequestForm
  ): Promise<ApiResponse<DeviceArchiveChangeRequestRecord>> {
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

    if (ApiClient.isOfflineMode()) {
      return DeviceArchiveChangeService.createLocalQueuedChangeRequestResponse(form, validation.normalizedDeviceCode ?
        validation.normalizedDeviceCode : DeviceService.normalizeDeviceCode(form.deviceCode));
    }

    if (!ApiClient.isConfigured()) {
      return ApiClient.createServiceUnavailableResponse<DeviceArchiveChangeRequestRecord>();
    }

    if (form.deviceId === undefined || form.deviceId.trim().length === 0 || form.baseline === undefined) {
      return {
        success: false,
        error: {
          code: 'DEVICE_CHANGE_BASELINE_MISSING',
          message: '缺少设备档案基准信息，请重新查询后提交'
        }
      };
    }

    const response = await ApiClient.request<DeviceArchiveChangeApiResult>('/api/v1/device-change-requests', 'POST', true,
      DeviceArchiveChangeService.buildCreateRequestBody(form));

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
          code: 'DEVICE_CHANGE_RESPONSE_INVALID',
          message: '变更申请响应无效'
        },
        requestId: response.requestId,
        timestamp: response.timestamp
      };
    }

    return {
      success: true,
      data: DeviceArchiveChangeService.createRecordFromApiResult(form, response.data, validation.normalizedDeviceCode ?
        validation.normalizedDeviceCode : DeviceService.normalizeDeviceCode(form.deviceCode)),
      requestId: response.requestId,
      timestamp: response.timestamp
    };
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
      case DeviceArchiveChangeRequestStatus.PendingSync:
        return '待同步';
      case DeviceArchiveChangeRequestStatus.PendingReview:
        return '待审核';
      case DeviceArchiveChangeRequestStatus.Approved:
        return '已通过';
      case DeviceArchiveChangeRequestStatus.Rejected:
        return '已驳回';
      case DeviceArchiveChangeRequestStatus.Withdrawn:
        return '已撤回';
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

  private static createLocalQueuedChangeRequestResponse(form: DeviceArchiveChangeRequestForm,
    normalizedDeviceCode: string): ApiResponse<DeviceArchiveChangeRequestRecord> {
    if (form.deviceId === undefined || form.deviceId.trim().length === 0 || form.baseline === undefined) {
      return {
        success: false,
        error: {
          code: 'DEVICE_CHANGE_BASELINE_MISSING',
          message: '缺少设备档案基准信息，请重新查询后提交'
        }
      };
    }

    const conflictKey = DeviceArchiveChangeService.createOfflineConflictKey(normalizedDeviceCode);
    const currentDevice = LocalDeviceArchiveRepository.findByCode(normalizedDeviceCode);
    if ((currentDevice !== undefined && DeviceService.isArchiveChangeLocked(currentDevice)) ||
      OfflineSyncService.hasActiveConflictKey(conflictKey)) {
      return {
        success: false,
        error: {
          code: 'DEVICE_CHANGE_LOCKED',
          message: '该设备存在待处理档案申请，请处理完成后再提交'
        },
        requestId: 'offline-sync-device-archive-update-blocked',
        timestamp: new Date().toISOString()
      };
    }

    const submittedAt = new Date().toISOString();
    const requestId = `DCR-OFFLINE-${submittedAt.replace(/[-:.TZ]/g, '').substring(0, 14)}-${Math.floor(Math.random() * 1000000)}`;
    const operatorName = SessionStore.getCurrentOperatorName();
    const payload = DeviceArchiveChangeService.createOfflineSyncPayload(form, normalizedDeviceCode, requestId, submittedAt);
    LocalDeviceArchiveRepository.markChangePending(normalizedDeviceCode, requestId);
    LocalOperationRecordRepository.append(OperationRecordType.DeviceChangeRequest, '保存档案变更待同步', normalizedDeviceCode,
      '设备档案变更已保存至本地同步队列', operatorName);
    OfflineSyncService.enqueue(
      OfflineSyncOperationType.DeviceArchiveUpdateRequestCreate,
      `档案变更 ${normalizedDeviceCode}`,
      JSON.stringify(payload),
      conflictKey
    );

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
        status: DeviceArchiveChangeRequestStatus.PendingSync,
        submittedAt
      },
      requestId: OFFLINE_SYNC_DEVICE_ARCHIVE_UPDATE_REQUEST_ID,
      timestamp: submittedAt
    };
  }

  static isOfflineSyncQueuedResponse(response: ApiResponse<DeviceArchiveChangeRequestRecord>): boolean {
    return response.requestId === OFFLINE_SYNC_DEVICE_ARCHIVE_UPDATE_REQUEST_ID;
  }

  private static buildApiChangesPayload(form: DeviceArchiveChangeRequestForm): string {
    const baseline = form.baseline;
    if (baseline === undefined) {
      return '{}';
    }

    const changeItems: string[] = [];
    const deviceName = DeviceArchiveChangeService.normalizeText(form.deviceName);
    if (DeviceArchiveChangeService.hasFieldChanged(baseline, 'deviceName', deviceName)) {
      changeItems.push(DeviceArchiveChangeService.formatApiChangeItem('name', baseline.deviceName, deviceName));
    }

    const model = DeviceArchiveChangeService.normalizeText(form.model);
    if (DeviceArchiveChangeService.hasFieldChanged(baseline, 'model', model)) {
      changeItems.push(DeviceArchiveChangeService.formatApiChangeItem('model', baseline.model, model));
    }

    const manufacturer = DeviceArchiveChangeService.normalizeText(form.manufacturer);
    if (DeviceArchiveChangeService.hasFieldChanged(baseline, 'manufacturer', manufacturer)) {
      changeItems.push(DeviceArchiveChangeService.formatApiChangeItem('manufacturer', baseline.manufacturer, manufacturer));
    }

    const locationAddress = DeviceArchiveChangeService.normalizeText(form.locationAddress);
    if (DeviceArchiveChangeService.hasFieldChanged(baseline, 'locationAddress', locationAddress)) {
      changeItems.push(DeviceArchiveChangeService.formatApiChangeItem('location.address', baseline.locationAddress, locationAddress));
    }

    return `{${changeItems.join(',')}}`;
  }

  private static createOfflineSyncPayload(
    form: DeviceArchiveChangeRequestForm,
    normalizedDeviceCode: string,
    localRequestId: string,
    queuedAt: string
  ): DeviceArchiveUpdateRequestOfflineSyncPayload {
    return {
      deviceId: form.deviceId === undefined ? '' : form.deviceId.trim(),
      deviceCode: normalizedDeviceCode,
      reason: DeviceArchiveChangeService.normalizeText(form.reason),
      changes: DeviceArchiveChangeService.buildOfflineChangeItems(form),
      localRequestId,
      queuedAt
    };
  }

  private static buildOfflineChangeItems(form: DeviceArchiveChangeRequestForm): DeviceArchiveOfflineChangeValuePayload[] {
    const baseline = form.baseline;
    if (baseline === undefined) {
      return [];
    }

    const changeItems: DeviceArchiveOfflineChangeValuePayload[] = [];
    DeviceArchiveChangeService.appendOfflineChangeItem(changeItems, baseline, 'name', 'deviceName', form.deviceName);
    DeviceArchiveChangeService.appendOfflineChangeItem(changeItems, baseline, 'model', 'model', form.model);
    DeviceArchiveChangeService.appendOfflineChangeItem(changeItems, baseline, 'manufacturer', 'manufacturer', form.manufacturer);
    DeviceArchiveChangeService.appendOfflineChangeItem(changeItems, baseline, 'location.address', 'locationAddress',
      form.locationAddress);
    return changeItems;
  }

  private static appendOfflineChangeItem(
    changeItems: DeviceArchiveOfflineChangeValuePayload[],
    baseline: DeviceArchiveChangeBaseline,
    field: string,
    baselineField: string,
    newValue: string
  ): void {
    const normalizedNewValue = DeviceArchiveChangeService.normalizeText(newValue);
    const oldValue = DeviceArchiveChangeService.getBaselineValue(baseline, baselineField);
    if (normalizedNewValue === DeviceArchiveChangeService.normalizeText(oldValue)) {
      return;
    }

    changeItems.push({
      field,
      oldValue,
      newValue: normalizedNewValue
    });
  }

  private static getBaselineValue(baseline: DeviceArchiveChangeBaseline, field: string): string {
    if (field === 'deviceName') {
      return baseline.deviceName;
    }

    if (field === 'model') {
      return baseline.model;
    }

    if (field === 'manufacturer') {
      return baseline.manufacturer;
    }

    if (field === 'locationAddress') {
      return baseline.locationAddress;
    }

    return '';
  }

  private static createOfflineConflictKey(deviceCode: string): string {
    return `device-archive:${DeviceService.normalizeDeviceCode(deviceCode)}`;
  }

  private static buildCreateRequestBody(form: DeviceArchiveChangeRequestForm): string {
    return `{"type":"UPDATE","deviceId":${JSON.stringify(form.deviceId)},"reason":${JSON.stringify(DeviceArchiveChangeService.normalizeText(form.reason))},"changes":${DeviceArchiveChangeService.buildApiChangesPayload(form)}}`;
  }

  private static formatApiChangeItem(field: string, oldValue: string, newValue: string): string {
    return `${JSON.stringify(field)}:{"oldValue":${JSON.stringify(oldValue)},"newValue":${JSON.stringify(newValue)}}`;
  }

  private static createRecordFromApiResult(
    form: DeviceArchiveChangeRequestForm,
    result: DeviceArchiveChangeApiResult,
    normalizedDeviceCode: string
  ): DeviceArchiveChangeRequestRecord {
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
