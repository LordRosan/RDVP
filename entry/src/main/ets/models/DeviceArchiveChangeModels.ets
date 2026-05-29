export enum DeviceArchiveChangeRequestStatus {
  Draft = 'DRAFT',
  PendingReview = 'PENDING_REVIEW',
  Approved = 'APPROVED',
  Rejected = 'REJECTED'
}

export interface DeviceArchiveChangeBaseline {
  deviceName: string;
  model: string;
  manufacturer: string;
  locationAddress: string;
}

export interface DeviceArchiveChangeRequestForm {
  deviceId?: string;
  deviceCode: string;
  deviceName: string;
  model: string;
  manufacturer: string;
  locationAddress: string;
  reason: string;
  baseline?: DeviceArchiveChangeBaseline;
}

export interface DeviceArchiveChangeRequestValidationResult {
  valid: boolean;
  message: string;
  normalizedDeviceCode?: string;
  changeCount?: number;
}

export interface DeviceArchiveChangeDraft {
  deviceCode: string;
  deviceName: string;
  model: string;
  manufacturer: string;
  locationAddress: string;
  reason: string;
}

export interface DeviceArchiveChangeRequestRecord {
  id: string;
  deviceCode: string;
  deviceName?: string;
  model?: string;
  manufacturer?: string;
  locationAddress?: string;
  reason: string;
  status: DeviceArchiveChangeRequestStatus;
  submittedAt: string;
}
