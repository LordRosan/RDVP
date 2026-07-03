import { DeviceSummary } from './DeviceModels';

export enum ArchiveRequestStatus {
  Draft = 'DRAFT',
  PendingReview = 'PENDING_REVIEW',
  Approved = 'APPROVED',
  Rejected = 'REJECTED',
  Withdrawn = 'WITHDRAWN'
}

export interface ArchiveUpdateBaseline {
  deviceName: string;
  model: string;
  manufacturer: string;
  locationAddress: string;
}

export interface ArchiveCreateRequestForm {
  deviceCode: string;
  deviceName: string;
  model: string;
  manufacturer: string;
  locationAddress: string;
  reason: string;
  initiatedAt?: string;
}

export interface ArchiveUpdateRequestForm {
  deviceId?: string;
  deviceCode: string;
  deviceName: string;
  model: string;
  manufacturer: string;
  locationAddress: string;
  reason: string;
  initiatedAt?: string;
  baseline?: ArchiveUpdateBaseline;
}

export interface ArchiveDeleteRequestForm {
  device: DeviceSummary;
  reason: string;
  initiatedAt?: string;
}

export interface ArchiveRequestValidationResult {
  valid: boolean;
  message: string;
  normalizedDeviceCode?: string;
  fieldCount?: number;
}

export interface ArchiveUpdateDraft {
  deviceCode: string;
  deviceName: string;
  model: string;
  manufacturer: string;
  locationAddress: string;
  reason: string;
  initiatedAt?: string;
}

export interface ArchiveRequestRecord {
  id: string;
  deviceCode: string;
  deviceName?: string;
  model?: string;
  manufacturer?: string;
  locationAddress?: string;
  reason: string;
  status: ArchiveRequestStatus;
  submittedAt: string;
}
