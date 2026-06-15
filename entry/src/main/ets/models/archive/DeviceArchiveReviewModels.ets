import { DeviceArchiveRequestStatus } from './DeviceArchiveRequestModels';

export enum DeviceArchiveReviewDecision {
  Approved = 'APPROVED',
  Rejected = 'REJECTED'
}

export enum DeviceArchiveReviewRequestType {
  Update = 'UPDATE',
  Create = 'CREATE',
  Delete = 'DELETE'
}

export interface DeviceArchiveRequestFieldDiff {
  field: string;
  label: string;
  oldValue: string;
  newValue: string;
}

export interface DeviceArchiveReviewItem {
  id: string;
  type: DeviceArchiveReviewRequestType;
  deviceId?: string;
  deviceCode: string;
  deviceName: string;
  applicantName?: string;
  reason: string;
  status: DeviceArchiveRequestStatus;
  initiatedAt: string;
  submittedAt: string;
  changes: DeviceArchiveRequestFieldDiff[];
}

export interface DeviceArchiveReviewListResult {
  items: DeviceArchiveReviewItem[];
  total: number;
}

export interface DeviceArchiveReviewForm {
  requestId: string;
  decision: DeviceArchiveReviewDecision;
  reviewedAt: string;
  reviewComment: string;
}

export interface DeviceArchiveReviewResult {
  id: string;
  status: DeviceArchiveRequestStatus;
  reviewedAt: string;
  freezeUntil?: string;
}
