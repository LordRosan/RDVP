import { DeviceSummary } from './DeviceModels';
import { ArchiveImageDraft } from './ArchiveImageModels';

export enum ArchiveRequestStatus {
  Draft = 'DRAFT',
  PendingReview = 'PENDING_REVIEW',
  Approved = 'APPROVED',
  Rejected = 'REJECTED',
  Withdrawn = 'WITHDRAWN'
}

export interface ArchiveUpdateBaseline {
  deviceName: string;
  imageIds: string[];
  deviceType: string;
  model: string;
  manufacturer: string;
  commissionedAt: string;
  managementDepartment: string;
  locationAddress: string;
}

export interface ArchiveCreateRequestForm {
  deviceCode: string;
  deviceName: string;
  images: ArchiveImageDraft[];
  deviceType: string;
  model: string;
  manufacturer: string;
  commissionedAt: string;
  managementDepartment: string;
  locationAddress: string;
  reason: string;
  initiatedAt?: string;
}

export interface ArchiveUpdateRequestForm {
  deviceId?: string;
  deviceCode: string;
  deviceName: string;
  images: ArchiveImageDraft[];
  imagesChanged: boolean;
  deviceType: string;
  model: string;
  manufacturer: string;
  commissionedAt: string;
  managementDepartment: string;
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
  images: ArchiveImageDraft[];
  imagesChanged: boolean;
  deviceType: string;
  model: string;
  manufacturer: string;
  commissionedAt: string;
  managementDepartment: string;
  locationAddress: string;
  reason: string;
  initiatedAt?: string;
}

export interface ArchiveRequestRecord {
  id: string;
  deviceCode: string;
  deviceName?: string;
  imageCount?: number;
  deviceType?: string;
  model?: string;
  manufacturer?: string;
  commissionedAt?: string;
  managementDepartment?: string;
  locationAddress?: string;
  reason: string;
  status: ArchiveRequestStatus;
  submittedAt: string;
}
