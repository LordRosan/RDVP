import { FaultReportForm, FaultReportRecord } from './FaultModels';

export enum VerificationResult {
  Normal = 'NORMAL',
  Abnormal = 'ABNORMAL'
}

export enum VerificationType {
  Routine = 'ROUTINE',
  Temporary = 'TEMPORARY',
  Special = 'SPECIAL',
  Initial = 'INITIAL',
  Sampling = 'SAMPLING',
  Other = 'OTHER'
}

export enum VerificationDeviceStatus {
  Running = 'RUNNING',
  Standby = 'STANDBY',
  Stopped = 'STOPPED',
  Offline = 'OFFLINE',
  Unknown = 'UNKNOWN',
  Other = 'OTHER'
}

export enum VerificationMethod {
  OnsiteObservation = 'ONSITE_OBSERVATION',
  IdentificationCheck = 'IDENTIFICATION_CHECK',
  FunctionTest = 'FUNCTION_TEST',
  DataReading = 'DATA_READING',
  RemoteConfirmation = 'REMOTE_CONFIRMATION',
  Other = 'OTHER'
}

export enum VerificationItemResult {
  Passed = 'PASSED',
  Failed = 'FAILED',
  NotApplicable = 'NOT_APPLICABLE'
}

export interface VerificationReportItem {
  itemCode: string;
  itemName: string;
  result: VerificationItemResult;
}

export interface VerificationReportForm {
  deviceCode: string;
  verificationType: VerificationType;
  deviceStatus: VerificationDeviceStatus;
  verificationMethod: VerificationMethod;
  items: VerificationReportItem[];
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
  verificationType?: VerificationType;
  deviceStatus?: VerificationDeviceStatus;
  verificationMethod?: VerificationMethod;
  result: VerificationResult;
  items?: VerificationReportItem[];
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
