import { FaultReportForm, FaultReportRecord } from './FaultModels';

export enum VerificationResult {
  Normal = 'NORMAL',
  Abnormal = 'ABNORMAL'
}

export interface VerificationReportForm {
  deviceCode: string;
  result: VerificationResult;
  description: string;
  verifiedAt: string;
  remark?: string;
}

export interface VerificationReportValidationResult {
  valid: boolean;
  message: string;
}

export interface VerificationReportRecord {
  id: string;
  deviceCode: string;
  result: VerificationResult;
  description: string;
  remark?: string;
  submittedAt: string;
}

export interface AbnormalVerificationSubmissionForm {
  verification: VerificationReportForm;
  faultReport: FaultReportForm;
}

export interface AbnormalVerificationSubmissionResult {
  verificationReport: VerificationReportRecord;
  faultReport: FaultReportRecord;
}
