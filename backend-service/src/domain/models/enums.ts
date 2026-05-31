export enum RoleCode {
  SystemAdmin = 'SYSTEM_ADMIN',
  DeviceAdmin = 'DEVICE_ADMIN',
  FieldOperator = 'FIELD_OPERATOR',
  Maintainer = 'MAINTAINER',
  Reinspector = 'REINSPECTOR',
  SupervisorAuditor = 'SUPERVISOR_AUDITOR',
  ReadOnly = 'READ_ONLY'
}

export enum PermissionCode {
  ArchiveDeviceRead = 'ARCHIVE_DEVICE_READ',
  ArchiveChangeRequestCreate = 'ARCHIVE_CHANGE_REQUEST_CREATE',
  OpsDeviceVerify = 'OPS_DEVICE_VERIFY',
  OpsFaultReportCreate = 'OPS_FAULT_REPORT_CREATE',
  OpsRepairTaskAccept = 'OPS_REPAIR_TASK_ACCEPT',
  OpsRepairReportCreate = 'OPS_REPAIR_REPORT_CREATE',
  OpsReinspectionCreate = 'OPS_REINSPECTION_CREATE',
  MgmtArchiveChangeReview = 'MGMT_ARCHIVE_CHANGE_REVIEW',
  MgmtAuditLogRead = 'MGMT_AUDIT_LOG_READ'
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

export enum VerificationResult {
  Normal = 'NORMAL',
  Abnormal = 'ABNORMAL',
  Unavailable = 'UNAVAILABLE'
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
