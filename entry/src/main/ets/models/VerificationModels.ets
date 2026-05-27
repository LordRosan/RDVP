export enum VerificationResult {
  Normal = 'NORMAL',
  Abnormal = 'ABNORMAL',
  Unavailable = 'UNAVAILABLE'
}

export interface DeviceVerificationForm {
  deviceCode: string;
  result: VerificationResult;
  description: string;
  remark: string;
}

export interface DeviceVerificationValidationResult {
  valid: boolean;
  message: string;
}

export interface DeviceVerificationRecord {
  id: string;
  deviceCode: string;
  result: VerificationResult;
  description: string;
  remark?: string;
  submittedAt: string;
}
