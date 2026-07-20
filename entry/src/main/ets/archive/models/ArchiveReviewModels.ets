import { ArchiveRequestStatus } from './ArchiveRequestModels';
import { ArchiveImageSummary } from './DeviceModels';

export enum ArchiveReviewDecision {
  Approved = 'APPROVED',
  Rejected = 'REJECTED'
}

export enum ArchiveReviewRequestType {
  Update = 'UPDATE',
  Create = 'CREATE',
  Delete = 'DELETE'
}

export interface ArchiveRequestFieldDiff {
  field: string;
  label: string;
  oldValue: string;
  newValue: string;
}

export interface ArchiveReviewItem {
  id: string;
  type: ArchiveReviewRequestType;
  deviceId?: string;
  deviceCode: string;
  deviceName: string;
  operatorName?: string;
  reason: string;
  status: ArchiveRequestStatus;
  initiatedAt: string;
  submittedAt: string;
  imagesChanged: boolean;
  images: ArchiveImageSummary[];
  changes: ArchiveRequestFieldDiff[];
}

export interface ArchiveReviewListResult {
  items: ArchiveReviewItem[];
  total: number;
}

export interface ArchiveReviewForm {
  requestId: string;
  decision: ArchiveReviewDecision;
  reviewedAt: string;
  reviewComment: string;
}

export interface ArchiveReviewResult {
  id: string;
  status: ArchiveRequestStatus;
  reviewedAt: string;
  freezeUntil?: string;
}
