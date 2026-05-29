export enum RoleCode {
  SystemAdmin = 'SYSTEM_ADMIN',
  DeviceAdmin = 'DEVICE_ADMIN',
  Verifier = 'VERIFIER',
  FaultReporter = 'FAULT_REPORTER',
  Maintainer = 'MAINTAINER',
  Reinspector = 'REINSPECTOR',
  SupervisorAuditor = 'SUPERVISOR_AUDITOR',
  ReadOnly = 'READ_ONLY'
}

export enum DeviceStatus {
  Normal = 'NORMAL',
  PendingVerification = 'PENDING_VERIFICATION',
  ChangePendingReview = 'CHANGE_PENDING_REVIEW',
  Faulted = 'FAULTED',
  UnderRepair = 'UNDER_REPAIR',
  PendingReinspection = 'PENDING_REINSPECTION',
  Disabled = 'DISABLED',
  Retired = 'RETIRED'
}

export enum ChangeRequestStatus {
  PendingReview = 'PENDING_REVIEW',
  Approved = 'APPROVED',
  Rejected = 'REJECTED',
  Withdrawn = 'WITHDRAWN'
}

export enum FaultStatus {
  Submitted = 'SUBMITTED',
  PendingAcceptance = 'PENDING_ACCEPTANCE',
  Accepted = 'ACCEPTED',
  UnderRepair = 'UNDER_REPAIR',
  RepairCompleted = 'REPAIR_COMPLETED',
  PendingReinspection = 'PENDING_REINSPECTION',
  Closed = 'CLOSED',
  Rejected = 'REJECTED'
}

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

export enum ReinspectionResult {
  Passed = 'PASSED',
  Failed = 'FAILED'
}

export enum OperationRecordStatus {
  Success = 'SUCCESS',
  Failed = 'FAILED'
}
