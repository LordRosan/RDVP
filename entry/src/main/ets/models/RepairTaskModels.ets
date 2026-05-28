import { FaultSeverity, FaultType } from './FaultModels';

export enum RepairerAvailability {
  Idle = 'IDLE',
  Busy = 'BUSY',
  Offline = 'OFFLINE'
}

export enum RepairTaskStatus {
  Available = 'AVAILABLE',
  Accepted = 'ACCEPTED',
  Processing = 'PROCESSING',
  ReportSubmitted = 'REPORT_SUBMITTED'
}

export enum RepairReportResult {
  Repaired = 'REPAIRED',
  TemporaryRestored = 'TEMPORARY_RESTORED',
  Unresolved = 'UNRESOLVED'
}

export interface AvailableRepairTaskQuery {
  radiusKm: number;
  availability: RepairerAvailability;
}

export interface RepairTaskValidationResult {
  valid: boolean;
  message: string;
  normalizedRadiusKm?: number;
}

export interface AvailableRepairTaskSummary {
  id: string;
  faultNo: string;
  deviceCode: string;
  deviceName: string;
  faultType: FaultType;
  severity: FaultSeverity;
  distanceKm: number;
  location: string;
  submittedAt: string;
  status: RepairTaskStatus;
}

export interface AvailableRepairTaskListResult {
  radiusKm: number;
  items: AvailableRepairTaskSummary[];
  total: number;
}

export interface MyRepairTaskSummary {
  id: string;
  taskNo: string;
  faultNo: string;
  deviceCode: string;
  deviceName: string;
  faultType: FaultType;
  severity: FaultSeverity;
  acceptedAt: string;
  status: RepairTaskStatus;
}

export interface MyRepairTaskListResult {
  items: MyRepairTaskSummary[];
  total: number;
}

export interface RepairTaskAcceptResult {
  taskId: string;
  status: RepairTaskStatus;
  acceptedAt: string;
}

export interface RepairReportForm {
  taskId: string;
  result: RepairReportResult;
  repairedAt: string;
  processDescription: string;
  partsUsed: string;
}

export interface RepairReportRecord {
  id: string;
  reportNo: string;
  taskId: string;
  result: RepairReportResult;
  submittedAt: string;
}
