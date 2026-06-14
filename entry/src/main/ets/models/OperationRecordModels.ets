export enum OperationRecordType {
  AuthLogin = 'AUTH_LOGIN',
  AuthenticationFailed = 'AUTHENTICATION_FAILED',
  AuthPasswordVerify = 'AUTH_PASSWORD_VERIFY',
  AuthorizationDenied = 'AUTHORIZATION_DENIED',
  DeviceVerification = 'DEVICE_VERIFICATION',
  DeviceQrCodeExport = 'DEVICE_QRCODE_EXPORT',
  DeviceChangeRequest = 'DEVICE_CHANGE_REQUEST',
  FaultReport = 'FAULT_REPORT',
  RepairTaskAccept = 'REPAIR_TASK_ACCEPT',
  RepairReport = 'REPAIR_REPORT',
  ReinspectionRecord = 'REINSPECTION_RECORD',
  Unknown = 'UNKNOWN'
}

export enum OperationRecordStatus {
  Success = 'SUCCESS',
  Failed = 'FAILED'
}

export interface OperationRecordSummary {
  id: string;
  type: OperationRecordType;
  title: string;
  targetNo: string;
  operatorName: string;
  occurredAt: string;
  status: OperationRecordStatus;
  description: string;
}

export interface OperationRecordListResult {
  items: OperationRecordSummary[];
  total: number;
}

export interface OperationRecordQueryFilter {
  action: string;
  keyword: string;
}
