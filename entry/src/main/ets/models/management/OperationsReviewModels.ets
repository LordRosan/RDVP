export enum OperationsReviewDecision {
  Approved = 'APPROVED',
  Rejected = 'REJECTED'
}

export enum OperationsReviewRequestType {
  DeviceVerificationReport = 'DEVICE_VERIFICATION_REPORT',
  FaultReport = 'FAULT_REPORT',
  RepairReport = 'REPAIR_REPORT',
  ReinspectionReport = 'REINSPECTION_REPORT'
}

export enum OperationsReviewRequestStatus {
  PendingReview = 'PENDING_REVIEW',
  Approved = 'APPROVED',
  Rejected = 'REJECTED'
}

export interface OperationsReviewItem {
  id: string;
  type: OperationsReviewRequestType;
  targetId: string;
  targetNo: string;
  faultReportId: string;
  deviceId: string;
  deviceCode: string;
  deviceName: string;
  operatorId: string;
  operatorName: string;
  summary: string;
  status: OperationsReviewRequestStatus;
  submittedAt: string;
  reviewOperatorId?: string;
  reviewComment?: string;
  reviewedAt?: string;
}

export interface OperationsReviewListResult {
  items: OperationsReviewItem[];
  total: number;
}

export interface OperationsReviewForm {
  requestId: string;
  decision: OperationsReviewDecision;
  reviewedAt: string;
  reviewComment: string;
}

export interface OperationsReviewResult {
  id: string;
  status: OperationsReviewRequestStatus;
  reviewedAt: string;
}
