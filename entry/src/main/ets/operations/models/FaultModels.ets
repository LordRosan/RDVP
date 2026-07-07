export enum FaultType {
  OperationAbnormal = 'OPERATION_ABNORMAL',
  HardwareDamage = 'HARDWARE_DAMAGE',
  CommunicationFault = 'COMMUNICATION_FAULT',
  LogicFault = 'LOGIC_FAULT',
  EnergyFault = 'ENERGY_FAULT',
  ExternalFactor = 'EXTERNAL_FACTOR',
  Other = 'OTHER'
}

export enum FaultSubtype {
  NoResponse = 'NO_RESPONSE',
  PerformanceDegraded = 'PERFORMANCE_DEGRADED',
  IntermittentAbnormal = 'INTERMITTENT_ABNORMAL',
  ParameterAbnormal = 'PARAMETER_ABNORMAL',
  PartDamaged = 'PART_DAMAGED',
  LoosenedOrDeformed = 'LOOSENED_OR_DEFORMED',
  WearOrAging = 'WEAR_OR_AGING',
  MissingPart = 'MISSING_PART',
  ConnectionInterrupted = 'CONNECTION_INTERRUPTED',
  SignalAbnormal = 'SIGNAL_ABNORMAL',
  DataAbnormal = 'DATA_ABNORMAL',
  SyncFailed = 'SYNC_FAILED',
  LogicException = 'LOGIC_EXCEPTION',
  ConfigurationMismatch = 'CONFIGURATION_MISMATCH',
  ProcessBlocked = 'PROCESS_BLOCKED',
  StateConflict = 'STATE_CONFLICT',
  PowerSupplyAbnormal = 'POWER_SUPPLY_ABNORMAL',
  EnergyConsumptionAbnormal = 'ENERGY_CONSUMPTION_ABNORMAL',
  Overheated = 'OVERHEATED',
  ProtectionTriggered = 'PROTECTION_TRIGGERED',
  MoistureOrWater = 'MOISTURE_OR_WATER',
  DustPollution = 'DUST_POLLUTION',
  ExternalImpact = 'EXTERNAL_IMPACT',
  EnvironmentExceeded = 'ENVIRONMENT_EXCEEDED',
  ToBeConfirmed = 'TO_BE_CONFIRMED',
  OtherAbnormal = 'OTHER_ABNORMAL'
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
  faultSubtype: FaultSubtype;
  severity: FaultSeverity;
  occurredAt: string;
  description: string;
  sceneCondition: string;
  longitude?: number;
  latitude?: number;
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
  faultSubtype?: FaultSubtype;
  severity: FaultSeverity;
  status: FaultStatus;
  submittedAt: string;
}
