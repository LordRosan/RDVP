export enum FaultType {
  OperationAbnormal = 'OPERATION_ABNORMAL',
  HardwareDamage = 'HARDWARE_DAMAGE',
  CommunicationFault = 'COMMUNICATION_FAULT',
  LogicFault = 'LOGIC_FAULT',
  EnergyFault = 'ENERGY_FAULT',
  ExternalFactor = 'EXTERNAL_FACTOR',
  Other = 'OTHER'
}

export enum FaultSeverity {
  Emergency = 'EMERGENCY',
  Severe = 'SEVERE',
  General = 'GENERAL',
  Minor = 'MINOR'
}

export enum FaultStatus {
  PendingAcceptance = 'PENDING_ACCEPTANCE',
  Accepted = 'ACCEPTED',
  UnderRepair = 'UNDER_REPAIR',
  PendingReinspection = 'PENDING_REINSPECTION',
  Closed = 'CLOSED'
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
  status: FaultStatus;
  submittedAt: string;
}
