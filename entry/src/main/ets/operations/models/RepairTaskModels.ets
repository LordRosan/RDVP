import { FaultSeverity, FaultType } from './FaultModels';

export enum RepairerWorkloadStatus {
  Idle = 'IDLE',
  LowLoad = 'LOW_LOAD',
  MediumLoad = 'MEDIUM_LOAD',
  Busy = 'BUSY',
  Unavailable = 'UNAVAILABLE'
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

export interface TaskAcceptanceQuery {
  radiusKm: number;
  longitude?: number;
  latitude?: number;
}

export interface RepairerWorkloadSnapshot {
  status: RepairerWorkloadStatus;
  activeTaskCount: number;
  maxActiveTaskCount: number;
  maxRadiusKm: number;
  recommendedRadiusKm: number;
  message: string;
  canAccept: boolean;
}

export interface RepairTaskValidationResult {
  valid: boolean;
  message: string;
  normalizedRadiusKm?: number;
}

export interface TaskAcceptanceItem {
  id: string;
  faultNo: string;
  deviceCode: string;
  deviceName: string;
  faultType: FaultType;
  severity: FaultSeverity;
  distanceKm?: number;
  location: string;
  submittedAt: string;
  status: RepairTaskStatus;
  taskType: string;
}

export interface TaskAcceptanceListResult {
  radiusKm: number;
  items: TaskAcceptanceItem[];
  total: number;
  workload?: RepairerWorkloadSnapshot;
}

export interface RepairTaskItem {
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

export interface RepairTaskListResult {
  items: RepairTaskItem[];
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
