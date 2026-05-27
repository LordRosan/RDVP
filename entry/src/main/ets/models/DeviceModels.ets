export enum DeviceStatus {
  Normal = 'NORMAL',
  PendingVerification = 'PENDING_VERIFICATION',
  ChangePendingReview = 'CHANGE_PENDING_REVIEW',
  Faulted = 'FAULTED',
  UnderRepair = 'UNDER_REPAIR',
  PendingReinspection = 'PENDING_REINSPECTION',
  Disabled = 'DISABLED',
  Retired = 'RETIRED'
}

export enum DeviceQueryMode {
  Code = 'CODE',
  Qr = 'QR'
}

export interface DeviceLocation {
  address: string;
  longitude?: number;
  latitude?: number;
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
