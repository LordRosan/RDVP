import { DeviceArchiveChangeDraft } from '../models/DeviceArchiveChangeModels';
import { DeviceStatus, DeviceSummary } from '../models/DeviceModels';

export class DeviceArchiveFlowStore {
  private static currentDevice?: DeviceSummary = undefined;
  private static draft?: DeviceArchiveChangeDraft = undefined;

  static startFlow(device: DeviceSummary): void {
    DeviceArchiveFlowStore.currentDevice = device;
    DeviceArchiveFlowStore.draft = undefined;
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

  static markChangePending(requestId: string): void {
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
      status: DeviceStatus.ChangePendingReview,
      lastVerificationTime: device.lastVerificationTime,
      changeState: {
        locked: true,
        pendingRequestId: requestId
      }
    };
    DeviceArchiveFlowStore.clearDraft();
  }

  static clearFlow(): void {
    DeviceArchiveFlowStore.currentDevice = undefined;
    DeviceArchiveFlowStore.draft = undefined;
  }
}
