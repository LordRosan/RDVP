import {
  DeviceArchiveChangeDraft,
  DeviceArchiveChangeRequestStatus
} from '../models/DeviceArchiveChangeModels';
import { DeviceSummary } from '../models/DeviceModels';

export class DeviceArchiveFlowStore {
  private static currentDevice?: DeviceSummary = undefined;
  private static draft?: DeviceArchiveChangeDraft = undefined;
  private static pendingDraft?: DeviceArchiveChangeDraft = undefined;
  private static pendingRequestStatus: DeviceArchiveChangeRequestStatus = DeviceArchiveChangeRequestStatus.PendingReview;

  static startFlow(device: DeviceSummary): void {
    DeviceArchiveFlowStore.currentDevice = device;
    DeviceArchiveFlowStore.draft = undefined;
    DeviceArchiveFlowStore.pendingDraft = undefined;
    DeviceArchiveFlowStore.pendingRequestStatus = DeviceArchiveChangeRequestStatus.PendingReview;
  }

  static getCurrentDevice(): DeviceSummary | undefined {
    return DeviceArchiveFlowStore.currentDevice;
  }

  static getDraft(): DeviceArchiveChangeDraft | undefined {
    return DeviceArchiveFlowStore.draft;
  }

  static saveDraft(draft: DeviceArchiveChangeDraft): void {
    DeviceArchiveFlowStore.draft = draft;
  }

  static clearDraft(): void {
    DeviceArchiveFlowStore.draft = undefined;
  }

  static getPendingDraft(): DeviceArchiveChangeDraft | undefined {
    return DeviceArchiveFlowStore.pendingDraft;
  }

  static getPendingRequestStatus(): DeviceArchiveChangeRequestStatus {
    return DeviceArchiveFlowStore.pendingRequestStatus;
  }

  static markChangePending(
    requestId: string,
    pendingDraft?: DeviceArchiveChangeDraft,
    status: DeviceArchiveChangeRequestStatus = DeviceArchiveChangeRequestStatus.PendingReview
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
      changeState: {
        locked: true,
        pendingRequestId: requestId
      }
    };
    DeviceArchiveFlowStore.pendingDraft = pendingDraft;
    DeviceArchiveFlowStore.pendingRequestStatus = status;
    DeviceArchiveFlowStore.clearDraft();
  }

  static markCurrentDeviceChangePendingByCode(
    deviceCode: string,
    requestId: string,
    status: DeviceArchiveChangeRequestStatus = DeviceArchiveChangeRequestStatus.PendingReview
  ): void {
    const device = DeviceArchiveFlowStore.currentDevice;
    if (device === undefined ||
      device.deviceCode.trim().toUpperCase() !== deviceCode.trim().toUpperCase()) {
      return;
    }

    DeviceArchiveFlowStore.markChangePending(requestId, DeviceArchiveFlowStore.pendingDraft, status);
  }

  static releaseCurrentDeviceChangeLockByCode(deviceCode: string): void {
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
      changeState: {
        locked: false
      }
    };
    DeviceArchiveFlowStore.pendingDraft = undefined;
    DeviceArchiveFlowStore.pendingRequestStatus = DeviceArchiveChangeRequestStatus.PendingReview;
  }

  static clearFlow(): void {
    DeviceArchiveFlowStore.currentDevice = undefined;
    DeviceArchiveFlowStore.draft = undefined;
    DeviceArchiveFlowStore.pendingDraft = undefined;
    DeviceArchiveFlowStore.pendingRequestStatus = DeviceArchiveChangeRequestStatus.PendingReview;
  }
}
