import { FaultReportForm, FaultReportRecord } from './FaultModels';

export enum VerificationResult {
  Normal = 'NORMAL',
  Abnormal = 'ABNORMAL'
}

export interface DeviceVerificationForm {
  deviceCode: string;
  result: VerificationResult;
  description: string;
  verifiedAt: string;
  remark?: string;
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

export interface DeviceVerificationAndFaultReportForm {
  verification: DeviceVerificationForm;
  faultReport: FaultReportForm;
}

export interface DeviceVerificationAndFaultReportRecord {
  verificationRecord: DeviceVerificationRecord;
  faultReport: FaultReportRecord;
}
