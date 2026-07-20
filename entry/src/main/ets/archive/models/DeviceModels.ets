export enum DeviceStatus {
  Normal = 'NORMAL',
  PendingVerification = 'PENDING_VERIFICATION',
  ArchiveRequestPendingReview = 'ARCHIVE_REQUEST_PENDING_REVIEW',
  Faulted = 'FAULTED',
  UnderRepair = 'UNDER_REPAIR',
  PendingReinspection = 'PENDING_REINSPECTION',
  Disabled = 'DISABLED',
  Retired = 'RETIRED'
}

export enum ArchiveQueryMode {
  Code = 'CODE',
  Qr = 'QR'
}

export interface DeviceLocation {
  address: string;
  longitude?: number;
  latitude?: number;
}

export interface DeviceLocationPayload {
  address?: string;
  longitude?: number;
  latitude?: number;
}

export interface ArchiveRequestState {
  locked: boolean;
  pendingRequestId?: string;
  freezeUntil?: string;
}

export interface ArchiveImageSummary {
  id: string;
  sortOrder: number;
  width: number;
  height: number;
  thumbnailDataUri: string;
}

export interface ArchiveImageSummaryPayload {
  id?: string;
  sortOrder?: number;
  width?: number;
  height?: number;
  thumbnailDataUri?: string;
}

export interface DeviceSummary {
  id: string;
  deviceCode: string;
  name: string;
  images: ArchiveImageSummary[];
  deviceType: string;
  model: string;
  manufacturer: string;
  commissionedAt: string;
  managementDepartment: string;
  location: DeviceLocation;
  status: DeviceStatus;
  lastVerificationTime?: string;
  archiveRequestState?: ArchiveRequestState;
}

export interface DeviceSummaryPayload {
  id?: string;
  deviceCode?: string;
  name?: string;
  images?: ArchiveImageSummaryPayload[];
  deviceType?: string;
  model?: string;
  manufacturer?: string;
  commissionedAt?: string;
  managementDepartment?: string;
  location?: DeviceLocationPayload;
  status?: DeviceStatus;
  lastVerificationTime?: string;
  archiveRequestState?: ArchiveRequestState;
}

export interface DeviceCodeQueryForm {
  deviceCode: string;
}

export interface DeviceCodeValidationResult {
  valid: boolean;
  message: string;
}

export interface DeviceQrQueryForm {
  qrContent: string;
}

export interface DeviceQrValidationResult {
  valid: boolean;
  message: string;
}
