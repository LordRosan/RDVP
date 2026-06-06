import { ApiResponse } from '../models/ApiModels';
import {
  DeviceArchiveChangeRequestRecord,
  DeviceArchiveChangeRequestStatus,
  DeviceArchiveChangeRequestValidationResult
} from '../models/DeviceArchiveChangeModels';
import { DeviceSummary } from '../models/DeviceModels';
import {
  DeviceArchiveCreateRequestOfflineSyncPayload,
  DeviceArchiveDeleteRequestOfflineSyncPayload,
  DeviceArchiveOfflineChangeValuePayload,
  OfflineSyncOperationType
} from '../models/OfflineSyncModels';
import { OperationRecordType } from '../models/OperationRecordModels';
import { ApiClient } from './ApiClient';
import { DeviceService } from './DeviceService';
import { LocalDeviceArchiveRepository } from './LocalDeviceArchiveRepository';
import { LocalDeviceChangeRequestRepository } from './LocalDeviceChangeRequestRepository';
import { LocalOperationRecordRepository } from './LocalOperationRecordRepository';
import { OfflineSyncService } from './OfflineSyncService';
import { SessionStore } from '../stores/SessionStore';

interface DeviceArchiveLifecycleApiResult {
  id: string;
  status: DeviceArchiveChangeRequestStatus;
  createdAt: string;
}

const OFFLINE_SYNC_DEVICE_ARCHIVE_CREATE_REQUEST_ID = 'offline-sync-device-archive-create-request';
const OFFLINE_SYNC_DEVICE_ARCHIVE_DELETE_REQUEST_ID = 'offline-sync-device-archive-delete-request';

export interface DeviceArchiveCreateRequestForm {
  deviceCode: string;
  deviceName: string;
  model: string;
  manufacturer: string;
  locationAddress: string;
  reason: string;
}

export interface DeviceArchiveDeleteRequestForm {
  device: DeviceSummary;
  reason: string;
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
        message: '请输入建档原因',
        normalizedDeviceCode
      };
    }

    if (reason.length > 500) {
      return {
        valid: false,
        message: '建档原因不能超过500个字符',
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
      const duplicate = LocalDeviceArchiveRepository.findByCode(normalizedDeviceCode);
      if (duplicate !== undefined || LocalDeviceChangeRequestRepository.hasPendingByDeviceCode(normalizedDeviceCode)) {
        return DeviceArchiveLifecycleService.createInvalidResponse('设备编号已存在');
      }

      return DeviceArchiveLifecycleService.createLocalQueuedCreateRequestResponse(form, normalizedDeviceCode);
    }

    const response = await ApiClient.request<DeviceArchiveLifecycleApiResult>('/api/v1/device-change-requests', 'POST',
      true, DeviceArchiveLifecycleService.buildCreateRequestBody(form, normalizedDeviceCode));
    if (!response.success && response.error !== undefined && response.error.code === 'SERVICE_UNAVAILABLE') {
      return DeviceArchiveLifecycleService.createLocalQueuedCreateRequestResponse(form, normalizedDeviceCode);
    }

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
      return DeviceArchiveLifecycleService.createLocalQueuedDeleteRequestResponse(form);
    }

    const response = await ApiClient.request<DeviceArchiveLifecycleApiResult>('/api/v1/device-change-requests', 'POST',
      true, DeviceArchiveLifecycleService.buildDeleteRequestBody(form));
    if (!response.success && response.error !== undefined && response.error.code === 'SERVICE_UNAVAILABLE') {
      return DeviceArchiveLifecycleService.createLocalQueuedDeleteRequestResponse(form);
    }

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

  private static createLocalCreateRequestResponse(form: DeviceArchiveCreateRequestForm,
    normalizedDeviceCode: string): ApiResponse<DeviceArchiveChangeRequestRecord> {
    const submittedAt = new Date().toISOString();
    const requestId = DeviceArchiveLifecycleService.newLocalRequestId(submittedAt);
    const operatorName = SessionStore.getCurrentOperatorName();
    LocalDeviceChangeRequestRepository.appendCreateSubmission(
      normalizedDeviceCode,
      DeviceArchiveLifecycleService.normalizeText(form.deviceName),
      DeviceArchiveLifecycleService.normalizeText(form.model),
      DeviceArchiveLifecycleService.normalizeText(form.manufacturer),
      DeviceArchiveLifecycleService.normalizeText(form.locationAddress),
      DeviceArchiveLifecycleService.normalizeText(form.reason),
      requestId,
      submittedAt,
      operatorName);
    LocalOperationRecordRepository.append(OperationRecordType.DeviceChangeRequest, '提交档案新增', normalizedDeviceCode,
      '设备新增档案进入待审核状态', operatorName);
    return {
      success: true,
      data: DeviceArchiveLifecycleService.createRecord(
        requestId,
        normalizedDeviceCode,
        form.deviceName,
        form.model,
        form.manufacturer,
        form.locationAddress,
        form.reason,
        submittedAt),
      requestId: 'local-device-archive-create-request',
      timestamp: submittedAt
    };
  }

  private static createLocalQueuedCreateRequestResponse(form: DeviceArchiveCreateRequestForm,
    normalizedDeviceCode: string): ApiResponse<DeviceArchiveChangeRequestRecord> {
    const conflictKey = DeviceArchiveLifecycleService.createOfflineConflictKey(normalizedDeviceCode);
    const duplicate = LocalDeviceArchiveRepository.findByCode(normalizedDeviceCode);
    if (duplicate !== undefined || LocalDeviceChangeRequestRepository.hasPendingByDeviceCode(normalizedDeviceCode)) {
      return DeviceArchiveLifecycleService.createInvalidResponse('设备编号已存在');
    }

    if (OfflineSyncService.hasActiveConflictKey(conflictKey)) {
      return DeviceArchiveLifecycleService.createInvalidResponse('该设备编号存在待同步档案申请，请同步或撤回后再提交');
    }

    const submittedAt = new Date().toISOString();
    const requestId = DeviceArchiveLifecycleService.newOfflineRequestId(submittedAt);
    const operatorName = SessionStore.getCurrentOperatorName();
    const payload = DeviceArchiveLifecycleService.createArchiveCreateOfflineSyncPayload(
      form,
      normalizedDeviceCode,
      requestId,
      submittedAt);
    LocalOperationRecordRepository.append(OperationRecordType.DeviceChangeRequest, '保存档案新增待同步', normalizedDeviceCode,
      '设备新增档案申请已保存至本地同步队列', operatorName);
    OfflineSyncService.enqueue(
      OfflineSyncOperationType.DeviceArchiveCreateRequestCreate,
      `档案新增 ${normalizedDeviceCode}`,
      JSON.stringify(payload),
      conflictKey
    );

    return {
      success: true,
      data: DeviceArchiveLifecycleService.createRecord(
        requestId,
        normalizedDeviceCode,
        form.deviceName,
        form.model,
        form.manufacturer,
        form.locationAddress,
        form.reason,
        submittedAt,
        DeviceArchiveChangeRequestStatus.PendingSync),
      requestId: OFFLINE_SYNC_DEVICE_ARCHIVE_CREATE_REQUEST_ID,
      timestamp: submittedAt
    };
  }

  private static createLocalDeleteRequestResponse(
    form: DeviceArchiveDeleteRequestForm
  ): ApiResponse<DeviceArchiveChangeRequestRecord> {
    const submittedAt = new Date().toISOString();
    const requestId = DeviceArchiveLifecycleService.newLocalRequestId(submittedAt);
    const operatorName = SessionStore.getCurrentOperatorName();
    LocalDeviceArchiveRepository.markChangePending(form.device.deviceCode, requestId);
    LocalDeviceChangeRequestRepository.appendDeleteSubmission(
      form.device,
      DeviceArchiveLifecycleService.normalizeText(form.reason),
      requestId,
      submittedAt,
      operatorName);
    LocalOperationRecordRepository.append(OperationRecordType.DeviceChangeRequest, '提交档案删除', form.device.deviceCode,
      '设备删除档案进入待审核状态', operatorName);
    return {
      success: true,
      data: DeviceArchiveLifecycleService.createRecord(
        requestId,
        form.device.deviceCode,
        form.device.name,
        form.device.model,
        form.device.manufacturer,
        form.device.location.address,
        form.reason,
        submittedAt),
      requestId: 'local-device-archive-delete-request',
      timestamp: submittedAt
    };
  }

  private static createLocalQueuedDeleteRequestResponse(
    form: DeviceArchiveDeleteRequestForm
  ): ApiResponse<DeviceArchiveChangeRequestRecord> {
    const conflictKey = DeviceArchiveLifecycleService.createOfflineConflictKey(form.device.deviceCode);
    if (OfflineSyncService.hasActiveConflictKey(conflictKey)) {
      return DeviceArchiveLifecycleService.createInvalidResponse('该设备存在待同步档案申请，请同步或撤回后再提交');
    }

    const submittedAt = new Date().toISOString();
    const requestId = DeviceArchiveLifecycleService.newOfflineRequestId(submittedAt);
    const operatorName = SessionStore.getCurrentOperatorName();
    const payload = DeviceArchiveLifecycleService.createArchiveDeleteOfflineSyncPayload(form, requestId, submittedAt);
    LocalDeviceArchiveRepository.markChangePending(form.device.deviceCode, requestId);
    LocalOperationRecordRepository.append(OperationRecordType.DeviceChangeRequest, '保存档案删除待同步', form.device.deviceCode,
      '设备删除档案申请已保存至本地同步队列', operatorName);
    OfflineSyncService.enqueue(
      OfflineSyncOperationType.DeviceArchiveDeleteRequestCreate,
      `档案删除 ${form.device.deviceCode}`,
      JSON.stringify(payload),
      conflictKey
    );

    return {
      success: true,
      data: DeviceArchiveLifecycleService.createRecord(
        requestId,
        form.device.deviceCode,
        form.device.name,
        form.device.model,
        form.device.manufacturer,
        form.device.location.address,
        form.reason,
        submittedAt,
        DeviceArchiveChangeRequestStatus.PendingSync),
      requestId: OFFLINE_SYNC_DEVICE_ARCHIVE_DELETE_REQUEST_ID,
      timestamp: submittedAt
    };
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
          code: 'DEVICE_LIFECYCLE_RESPONSE_INVALID',
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
        code: 'DEVICE_ARCHIVE_LIFECYCLE_INVALID',
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
    return `{"type":"CREATE","deviceCode":${JSON.stringify(normalizedDeviceCode)},"reason":${JSON.stringify(
      DeviceArchiveLifecycleService.normalizeText(form.reason))},"changes":{${changeItems.join(',')}}}`;
  }

  private static buildDeleteRequestBody(form: DeviceArchiveDeleteRequestForm): string {
    return `{"type":"DELETE","deviceId":${JSON.stringify(form.device.id)},"reason":${JSON.stringify(
      DeviceArchiveLifecycleService.normalizeText(form.reason))}}`;
  }

  private static formatCreateChangeItem(field: string, newValue: string): string {
    return `${JSON.stringify(field)}:{"newValue":${JSON.stringify(newValue)}}`;
  }

  private static createArchiveCreateOfflineSyncPayload(
    form: DeviceArchiveCreateRequestForm,
    normalizedDeviceCode: string,
    localRequestId: string,
    queuedAt: string
  ): DeviceArchiveCreateRequestOfflineSyncPayload {
    return {
      deviceCode: normalizedDeviceCode,
      reason: DeviceArchiveLifecycleService.normalizeText(form.reason),
      changes: DeviceArchiveLifecycleService.buildCreateOfflineChanges(form),
      localRequestId,
      queuedAt
    };
  }

  private static createArchiveDeleteOfflineSyncPayload(
    form: DeviceArchiveDeleteRequestForm,
    localRequestId: string,
    queuedAt: string
  ): DeviceArchiveDeleteRequestOfflineSyncPayload {
    return {
      deviceId: form.device.id,
      deviceCode: form.device.deviceCode,
      reason: DeviceArchiveLifecycleService.normalizeText(form.reason),
      localRequestId,
      queuedAt
    };
  }

  private static buildCreateOfflineChanges(form: DeviceArchiveCreateRequestForm): DeviceArchiveOfflineChangeValuePayload[] {
    const changes: DeviceArchiveOfflineChangeValuePayload[] = [];
    DeviceArchiveLifecycleService.appendCreateOfflineChange(changes, 'name', form.deviceName);
    DeviceArchiveLifecycleService.appendCreateOfflineChange(changes, 'model', form.model);
    DeviceArchiveLifecycleService.appendCreateOfflineChange(changes, 'manufacturer', form.manufacturer);
    DeviceArchiveLifecycleService.appendCreateOfflineChange(changes, 'location.address', form.locationAddress);
    return changes;
  }

  private static appendCreateOfflineChange(changes: DeviceArchiveOfflineChangeValuePayload[], field: string,
    value: string): void {
    const normalizedValue = DeviceArchiveLifecycleService.normalizeText(value);
    if (normalizedValue.length === 0) {
      return;
    }

    changes.push({
      field,
      newValue: normalizedValue
    });
  }

  private static newLocalRequestId(submittedAt: string): string {
    return `DCR-LOCAL-${submittedAt.replace(/[-:.TZ]/g, '').substring(0, 14)}`;
  }

  private static newOfflineRequestId(submittedAt: string): string {
    return `DCR-OFFLINE-${submittedAt.replace(/[-:.TZ]/g, '').substring(0, 14)}-${Math.floor(Math.random() * 1000000)}`;
  }

  static isOfflineSyncQueuedResponse(response: ApiResponse<DeviceArchiveChangeRequestRecord>): boolean {
    return response.requestId === OFFLINE_SYNC_DEVICE_ARCHIVE_CREATE_REQUEST_ID ||
      response.requestId === OFFLINE_SYNC_DEVICE_ARCHIVE_DELETE_REQUEST_ID;
  }

  private static createOfflineConflictKey(deviceCode: string): string {
    return `device-archive:${DeviceService.normalizeDeviceCode(deviceCode)}`;
  }

  private static normalizeText(value: string): string {
    return value.trim();
  }
}
