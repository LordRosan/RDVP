export enum FaultType {
  OperationAbnormal = 'OPERATION_ABNORMAL',
  NetworkAbnormal = 'NETWORK_ABNORMAL',
  HardwareDamage = 'HARDWARE_DAMAGE',
  SafetyRisk = 'SAFETY_RISK',
  Other = 'OTHER'
}

export enum FaultSeverity {
  General = 'GENERAL',
  Major = 'MAJOR',
  Critical = 'CRITICAL'
}

export interface FaultReportForm {
  deviceCode: string;
  faultType: FaultType;
  severity: FaultSeverity;
  occurredAt: string;
  description: string;
  sceneCondition: string;
}

export interface FaultReportValidationResult {
  valid: boolean;
  message: string;
}

export interface FaultReportRecord {
  id: string;
  reportNo: string;
  deviceCode: string;
  faultType: FaultType;
  severity: FaultSeverity;
  status: string;
  submittedAt: string;
}
