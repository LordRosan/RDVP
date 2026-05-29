export enum OperationRecordType {
  AuthLogin = 'AUTH_LOGIN',
  DeviceVerification = 'DEVICE_VERIFICATION',
  DeviceChangeRequest = 'DEVICE_CHANGE_REQUEST',
  FaultReport = 'FAULT_REPORT',
  RepairTaskAccept = 'REPAIR_TASK_ACCEPT',
  RepairReport = 'REPAIR_REPORT',
  ReinspectionRecord = 'REINSPECTION_RECORD'
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
