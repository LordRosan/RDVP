import { FaultSeverity } from './FaultModels';

export enum ReinspectionResult {
  Passed = 'PASSED',
  Failed = 'FAILED'
}

export enum ReinspectionTaskStatus {
  Pending = 'PENDING',
  Completed = 'COMPLETED'
}

export interface ReinspectionTaskSummary {
  id: string;
  taskNo: string;
  faultNo: string;
  deviceCode: string;
  deviceName: string;
  severity: FaultSeverity;
  location: string;
  repairedAt: string;
  status: ReinspectionTaskStatus;
}

export interface ReinspectionTaskListResult {
  items: ReinspectionTaskSummary[];
  total: number;
}

export interface ReinspectionRecordForm {
  taskId: string;
  result: ReinspectionResult;
  reinspectedAt: string;
  description: string;
}

export interface ReinspectionValidationResult {
  valid: boolean;
  message: string;
}

export interface ReinspectionRecord {
  id: string;
  recordNo: string;
  taskId: string;
  result: ReinspectionResult;
  submittedAt: string;
}
