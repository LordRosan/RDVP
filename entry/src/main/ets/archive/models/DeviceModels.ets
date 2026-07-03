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

export enum DeviceArchiveQueryMode {
  Code = 'CODE',
  Qr = 'QR'
}

export interface DeviceLocation {
  address: string;
  longitude?: number;
  latitude?: number;
}

export interface DeviceArchiveRequestState {
  locked: boolean;
  pendingRequestId?: string;
  freezeUntil?: string;
}

export interface DeviceSummary {
  id: string;
  deviceCode: string;
  name: string;
  model: string;
  manufacturer: string;
  location: DeviceLocation;
  status: DeviceStatus;
  lastVerificationTime?: string;
  archiveRequestState?: DeviceArchiveRequestState;
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
