import {
  ChangeRequestStatus,
  DeviceStatus,
  FaultSeverity,
  FaultStatus,
  FaultType,
  OperationRecordStatus,
  ReinspectionResult,
  RepairReportResult,
  RepairTaskStatus,
  RoleCode,
  VerificationResult
} from './enums.js';

export interface GeoPoint {
  longitude: number;
  latitude: number;
}

export interface DeviceLocation extends Partial<GeoPoint> {
  address: string;
}

export interface DeviceArchiveChangeState {
  locked: boolean;
  pendingRequestId?: string;
  freezeUntil?: string;
}

export interface Device {
  id: string;
  deviceCode: string;
  name: string;
  model: string;
  manufacturer: string;
  location: DeviceLocation;
  status: DeviceStatus;
  lastVerificationTime?: string;
  changeState: DeviceArchiveChangeState;
  createdAt: string;
  updatedAt: string;
}

export interface DeviceQrCode {
  id: string;
  deviceId: string;
  version: number;
  nonce: string;
  signatureHash: string;
  status: 'ACTIVE' | 'EXPIRED' | 'REVOKED';
  issuedAt: string;
  expiresAt?: string;
}

export interface DeviceVerificationRecord {
  id: string;
  deviceId: string;
  verifierId: string;
  result: VerificationResult;
  description: string;
  remark?: string;
  location?: GeoPoint;
  verifiedAt: string;
  createdAt: string;
}

export interface UserAccount {
  id: string;
  username: string;
  passwordHash: string;
  displayName: string;
  roles: RoleCode[];
  permissions: string[];
  status: 'ACTIVE' | 'DISABLED' | 'LOCKED';
}

export interface AuthSession {
  accessToken: string;
  userId: string;
  expiresAt: string;
}

export interface FaultReport {
  id: string;
  faultReportNo: string;
  deviceId: string;
  reporterId: string;
  faultType: FaultType;
  severity: FaultSeverity;
  description: string;
  sceneCondition?: string;
  status: FaultStatus;
  occurredAt: string;
  location?: GeoPoint;
  acceptedTaskId?: string;
  closedAt?: string;
  createdAt: string;
  updatedAt: string;
}

export interface DeviceChangeValue {
  oldValue: unknown;
  newValue: unknown;
}

export interface DeviceChangeRequest {
  id: string;
  deviceId: string;
  applicantId: string;
  status: ChangeRequestStatus;
  reason: string;
  changes: Record<string, DeviceChangeValue>;
  previousDeviceStatus: DeviceStatus;
  reviewerId?: string;
  reviewComment?: string;
  reviewedAt?: string;
  freezeUntil?: string;
  createdAt: string;
  updatedAt: string;
}

export interface RepairTask {
  id: string;
  repairTaskNo: string;
  faultReportId: string;
  maintainerId: string;
  status: RepairTaskStatus;
  acceptedLocation?: GeoPoint;
  acceptedAt: string;
  completedAt?: string;
  createdAt: string;
  updatedAt: string;
}

export interface RepairReport {
  id: string;
  repairReportNo: string;
  repairTaskId: string;
  faultReportId: string;
  maintainerId: string;
  result: RepairReportResult;
  repairedAt: string;
  processDescription: string;
  partsUsed?: string;
  requiresReinspection: boolean;
  createdAt: string;
}

export interface ReinspectionRecord {
  id: string;
  reinspectionRecordNo: string;
  faultReportId: string;
  repairReportId: string;
  reinspectorId: string;
  result: ReinspectionResult;
  description?: string;
  reinspectedAt: string;
  createdAt: string;
}

export interface AuditLog {
  id: string;
  action: string;
  targetType: string;
  targetId?: string;
  targetNo?: string;
  actorId?: string;
  actorName?: string;
  status: OperationRecordStatus;
  description: string;
  requestId?: string;
  occurredAt: string;
}
