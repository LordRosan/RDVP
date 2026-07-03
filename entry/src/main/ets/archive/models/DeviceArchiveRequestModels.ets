import { DeviceSummary } from './DeviceModels';

export enum DeviceArchiveRequestStatus {
  Draft = 'DRAFT',
  PendingReview = 'PENDING_REVIEW',
  Approved = 'APPROVED',
  Rejected = 'REJECTED',
  Withdrawn = 'WITHDRAWN'
}

export interface DeviceArchiveUpdateBaseline {
  deviceName: string;
  model: string;
  manufacturer: string;
  locationAddress: string;
}

export interface DeviceArchiveCreateRequestForm {
  deviceCode: string;
  deviceName: string;
  model: string;
  manufacturer: string;
  locationAddress: string;
  reason: string;
  initiatedAt?: string;
}

export interface DeviceArchiveUpdateRequestForm {
  deviceId?: string;
  deviceCode: string;
  deviceName: string;
  model: string;
  manufacturer: string;
  locationAddress: string;
  reason: string;
  initiatedAt?: string;
  baseline?: DeviceArchiveUpdateBaseline;
}

export interface DeviceArchiveDeleteRequestForm {
  device: DeviceSummary;
  reason: string;
  initiatedAt?: string;
}

export interface DeviceArchiveRequestValidationResult {
  valid: boolean;
  message: string;
  normalizedDeviceCode?: string;
  fieldCount?: number;
}

export interface DeviceArchiveUpdateDraft {
  deviceCode: string;
  deviceName: string;
  model: string;
  manufacturer: string;
  locationAddress: string;
  reason: string;
  initiatedAt?: string;
}

export interface DeviceArchiveRequestRecord {
  id: string;
  deviceCode: string;
  deviceName?: string;
  model?: string;
  manufacturer?: string;
  locationAddress?: string;
  reason: string;
  status: DeviceArchiveRequestStatus;
  submittedAt: string;
}
