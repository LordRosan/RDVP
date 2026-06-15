import {
  DeviceArchiveUpdateDraft,
  DeviceArchiveRequestStatus
} from '../models/archive/DeviceArchiveRequestModels';
import { DeviceSummary } from '../models/archive/DeviceModels';

export class DeviceArchiveFlowStore {
  private static currentDevice?: DeviceSummary = undefined;
  private static draft?: DeviceArchiveUpdateDraft = undefined;
  private static pendingDraft?: DeviceArchiveUpdateDraft = undefined;
  private static pendingRequestStatus: DeviceArchiveRequestStatus = DeviceArchiveRequestStatus.PendingReview;

  private static readonly DEVICE_CODE_STORAGE_KEY = 'rdvp_archive_current_device_code';

  static startFlow(device: DeviceSummary): void {
    DeviceArchiveFlowStore.currentDevice = device;
    DeviceArchiveFlowStore.draft = undefined;
    DeviceArchiveFlowStore.pendingDraft = undefined;
    DeviceArchiveFlowStore.pendingRequestStatus = DeviceArchiveRequestStatus.PendingReview;
    try {
      AppStorage.setOrCreate<string>(DeviceArchiveFlowStore.DEVICE_CODE_STORAGE_KEY, device.deviceCode);
    } catch (err) {
    }
  }

  static getCurrentDevice(): DeviceSummary | undefined {
    return DeviceArchiveFlowStore.currentDevice;
  }

  static getLastDeviceCode(): string {
    try {
      const code = AppStorage.get<string>(DeviceArchiveFlowStore.DEVICE_CODE_STORAGE_KEY);
      if (code !== undefined && code.trim().length > 0) {
        return code.trim();
      }
    } catch (err) {
    }

    return '';
  }

  static getDraft(): DeviceArchiveUpdateDraft | undefined {
    return DeviceArchiveFlowStore.draft;
  }

  static saveDraft(draft: DeviceArchiveUpdateDraft): void {
    DeviceArchiveFlowStore.draft = draft;
  }

  static clearDraft(): void {
    DeviceArchiveFlowStore.draft = undefined;
  }

  static getPendingDraft(): DeviceArchiveUpdateDraft | undefined {
    return DeviceArchiveFlowStore.pendingDraft;
  }

  static getPendingRequestStatus(): DeviceArchiveRequestStatus {
    return DeviceArchiveFlowStore.pendingRequestStatus;
  }

  static markArchiveRequestPending(
    requestId: string,
    pendingDraft?: DeviceArchiveUpdateDraft,
    status: DeviceArchiveRequestStatus = DeviceArchiveRequestStatus.PendingReview
  ): void {
    if (DeviceArchiveFlowStore.currentDevice === undefined) {
      return;
    }

    const device = DeviceArchiveFlowStore.currentDevice;
    DeviceArchiveFlowStore.currentDevice = {
      id: device.id,
      deviceCode: device.deviceCode,
      name: device.name,
      model: device.model,
      manufacturer: device.manufacturer,
      location: device.location,
      status: device.status,
      lastVerificationTime: device.lastVerificationTime,
      archiveRequestState: {
        locked: true,
        pendingRequestId: requestId
      }
    };
    DeviceArchiveFlowStore.pendingDraft = pendingDraft;
    DeviceArchiveFlowStore.pendingRequestStatus = status;
    DeviceArchiveFlowStore.clearDraft();
  }

  static markCurrentArchiveRequestPendingByCode(
    deviceCode: string,
    requestId: string,
    status: DeviceArchiveRequestStatus = DeviceArchiveRequestStatus.PendingReview
  ): void {
    const device = DeviceArchiveFlowStore.currentDevice;
    if (device === undefined ||
      device.deviceCode.trim().toUpperCase() !== deviceCode.trim().toUpperCase()) {
      return;
    }

    DeviceArchiveFlowStore.markArchiveRequestPending(requestId, DeviceArchiveFlowStore.pendingDraft, status);
  }

  static releaseCurrentArchiveRequestLockByCode(deviceCode: string): void {
    const device = DeviceArchiveFlowStore.currentDevice;
    if (device === undefined ||
      device.deviceCode.trim().toUpperCase() !== deviceCode.trim().toUpperCase()) {
      return;
    }

    DeviceArchiveFlowStore.currentDevice = {
      id: device.id,
      deviceCode: device.deviceCode,
      name: device.name,
      model: device.model,
      manufacturer: device.manufacturer,
      location: device.location,
      status: device.status,
      lastVerificationTime: device.lastVerificationTime,
      archiveRequestState: {
        locked: false
      }
    };
    DeviceArchiveFlowStore.pendingDraft = undefined;
    DeviceArchiveFlowStore.pendingRequestStatus = DeviceArchiveRequestStatus.PendingReview;
  }

  static clearFlow(): void {
    DeviceArchiveFlowStore.currentDevice = undefined;
    DeviceArchiveFlowStore.draft = undefined;
    DeviceArchiveFlowStore.pendingDraft = undefined;
    DeviceArchiveFlowStore.pendingRequestStatus = DeviceArchiveRequestStatus.PendingReview;
    try {
      AppStorage.setOrCreate<string>(DeviceArchiveFlowStore.DEVICE_CODE_STORAGE_KEY, '');
    } catch (err) {
    }
  }
}
