import {
  ArchiveUpdateDraft,
  ArchiveRequestStatus
} from '../models/ArchiveRequestModels';
import { DeviceSummary } from '../models/DeviceModels';

export class ArchiveFlowStore {
  private static currentDevice?: DeviceSummary = undefined;
  private static draft?: ArchiveUpdateDraft = undefined;
  private static pendingDraft?: ArchiveUpdateDraft = undefined;
  private static pendingRequestStatus: ArchiveRequestStatus = ArchiveRequestStatus.PendingReview;

  private static readonly DEVICE_CODE_STORAGE_KEY = 'rdvp_archive_current_device_code';

  static startFlow(device: DeviceSummary): void {
    ArchiveFlowStore.currentDevice = device;
    ArchiveFlowStore.draft = undefined;
    ArchiveFlowStore.pendingDraft = undefined;
    ArchiveFlowStore.pendingRequestStatus = ArchiveRequestStatus.PendingReview;
    try {
      AppStorage.setOrCreate<string>(ArchiveFlowStore.DEVICE_CODE_STORAGE_KEY, device.deviceCode);
    } catch (err) {
    }
  }

  static getCurrentDevice(): DeviceSummary | undefined {
    return ArchiveFlowStore.currentDevice;
  }

  static getLastDeviceCode(): string {
    try {
      const code = AppStorage.get<string>(ArchiveFlowStore.DEVICE_CODE_STORAGE_KEY);
      if (code !== undefined && code.trim().length > 0) {
        return code.trim();
      }
    } catch (err) {
    }

    return '';
  }

  static getDraft(): ArchiveUpdateDraft | undefined {
    return ArchiveFlowStore.draft;
  }

  static saveDraft(draft: ArchiveUpdateDraft): void {
    ArchiveFlowStore.draft = draft;
  }

  static clearDraft(): void {
    ArchiveFlowStore.draft = undefined;
  }

  static getPendingDraft(): ArchiveUpdateDraft | undefined {
    return ArchiveFlowStore.pendingDraft;
  }

  static getPendingRequestStatus(): ArchiveRequestStatus {
    return ArchiveFlowStore.pendingRequestStatus;
  }

  static markArchiveRequestPending(
    requestId: string,
    pendingDraft?: ArchiveUpdateDraft,
    status: ArchiveRequestStatus = ArchiveRequestStatus.PendingReview
  ): void {
    if (ArchiveFlowStore.currentDevice === undefined) {
      return;
    }

    const device = ArchiveFlowStore.currentDevice;
    ArchiveFlowStore.currentDevice = {
      id: device.id,
      deviceCode: device.deviceCode,
      name: device.name,
      images: device.images,
      deviceType: device.deviceType,
      model: device.model,
      manufacturer: device.manufacturer,
      commissionedAt: device.commissionedAt,
      managementDepartment: device.managementDepartment,
      location: device.location,
      status: device.status,
      lastVerificationTime: device.lastVerificationTime,
      archiveRequestState: {
        locked: true,
        pendingRequestId: requestId
      }
    };
    ArchiveFlowStore.pendingDraft = pendingDraft;
    ArchiveFlowStore.pendingRequestStatus = status;
    ArchiveFlowStore.clearDraft();
  }

  static markCurrentArchiveRequestPendingByCode(
    deviceCode: string,
    requestId: string,
    status: ArchiveRequestStatus = ArchiveRequestStatus.PendingReview
  ): void {
    const device = ArchiveFlowStore.currentDevice;
    if (device === undefined ||
      device.deviceCode.trim().toUpperCase() !== deviceCode.trim().toUpperCase()) {
      return;
    }

    ArchiveFlowStore.markArchiveRequestPending(requestId, ArchiveFlowStore.pendingDraft, status);
  }

  static releaseCurrentArchiveRequestLockByCode(deviceCode: string): void {
    const device = ArchiveFlowStore.currentDevice;
    if (device === undefined ||
      device.deviceCode.trim().toUpperCase() !== deviceCode.trim().toUpperCase()) {
      return;
    }

    ArchiveFlowStore.currentDevice = {
      id: device.id,
      deviceCode: device.deviceCode,
      name: device.name,
      images: device.images,
      deviceType: device.deviceType,
      model: device.model,
      manufacturer: device.manufacturer,
      commissionedAt: device.commissionedAt,
      managementDepartment: device.managementDepartment,
      location: device.location,
      status: device.status,
      lastVerificationTime: device.lastVerificationTime,
      archiveRequestState: {
        locked: false
      }
    };
    ArchiveFlowStore.pendingDraft = undefined;
    ArchiveFlowStore.pendingRequestStatus = ArchiveRequestStatus.PendingReview;
  }

  static clearFlow(): void {
    ArchiveFlowStore.currentDevice = undefined;
    ArchiveFlowStore.draft = undefined;
    ArchiveFlowStore.pendingDraft = undefined;
    ArchiveFlowStore.pendingRequestStatus = ArchiveRequestStatus.PendingReview;
    try {
      AppStorage.setOrCreate<string>(ArchiveFlowStore.DEVICE_CODE_STORAGE_KEY, '');
    } catch (err) {
    }
  }
}
